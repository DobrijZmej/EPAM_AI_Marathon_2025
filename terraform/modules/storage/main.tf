resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "kb_docs" {
  bucket = "kb-knowledge-base-${random_id.suffix.hex}"
  force_destroy = true
  tags = {
    Name = "Knowledge Base Docs"
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.kb_docs.id
  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}
