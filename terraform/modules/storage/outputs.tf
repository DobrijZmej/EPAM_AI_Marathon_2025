output "bucket_name" {
  value = aws_s3_bucket.kb_docs.id
}
output "bucket_arn" {
  value = aws_s3_bucket.kb_docs.arn
}
