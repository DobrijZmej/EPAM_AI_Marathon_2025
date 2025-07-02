
provider "aws" {
  region = "eu-central-1"
}

resource "random_id" "rand" {
  byte_length = 4
}

resource "aws_s3_bucket" "frontend" {
  bucket        = "support-agent-frontend-${random_id.rand.hex}"
  force_destroy = true

  tags = {
    Name = "support-agent-frontend"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_block" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "PublicReadForCloudFront",
      Effect    = "Allow",
      Principal = "*",
      Action    = ["s3:GetObject"],
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
    }]
  })
}

resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "support-agent-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend_distribution" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "frontendS3"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "frontendS3"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "support-agent-cdn"
  }
}

module "cognito" {
  source = "./modules/cognito"
}

module "api" {
  source = "./modules/api"

  user_pool_id         = module.cognito.user_pool_id
  user_pool_client_id  = module.cognito.user_pool_client_id
  lambda_function_name = aws_lambda_function.ask_handler.function_name
  lambda_invoke_arn    = aws_lambda_function.ask_handler.invoke_arn
}

module "storage" {
  source       = "./modules/storage"
  project_name = var.project_name
}

