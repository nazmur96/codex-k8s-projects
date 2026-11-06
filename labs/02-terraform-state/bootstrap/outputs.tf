output "state_bucket_name" {
  description = "S3 bucket used to store this lab's Terraform state."
  value       = aws_s3_bucket.state.id
}
