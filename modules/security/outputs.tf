output "guardduty_audit_detector_id" {
  value = aws_guardduty_detector.audit.id
}

output "guardduty_workload_detector_id" {
  value = aws_guardduty_detector.workload.id
}