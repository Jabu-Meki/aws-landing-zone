locals {
  audit_bucket_name = "central-logs-${var.audit_account_id}"
}

# S3 Bucket
resource "aws_s3_bucket" "central_logs" {
  provider      = aws.audit
  bucket        = local.audit_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "central_logs" {
  provider = aws.audit
  bucket = aws_s3_bucket.central_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "central_logs" {
  provider = aws.audit
  bucket = aws_s3_bucket.central_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Policy
data "aws_iam_policy_document" "central_logs" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [var.service_principals.cloudtrail]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.central_logs.arn]
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [var.service_principals.cloudtrail]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.central_logs.arn}/AWSLogs/${var.current_account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [var.service_principals.cloudtrail]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.central_logs.arn}/AWSLogs/${var.organization_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [var.service_principals.config]
    }

    actions = [
      "s3:GetBucketAcl",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.central_logs.arn]
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [var.service_principals.config]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.central_logs.arn}/AWSLogs/*"]
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [var.service_principals.guardduty]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.central_logs.arn}/GuardDuty/*"]
  }
}

resource "aws_s3_bucket_policy" "central_logs" {
  provider = aws.audit
  bucket = aws_s3_bucket.central_logs.id
  policy = data.aws_iam_policy_document.central_logs.json
}

# Organization CloudTrail
resource "aws_cloudtrail" "organization" {
  name                          = "organization-trail"
  s3_bucket_name                = aws_s3_bucket.central_logs.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  is_organization_trail         = true

  depends_on = [aws_s3_bucket_policy.central_logs]
}
