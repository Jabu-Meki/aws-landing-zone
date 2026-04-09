output "bucket_name" {
  value = aws_s3_bucket.central_logs.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.central_logs.arn
}