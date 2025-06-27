
output "cloudfront_https_url" {
  value       = "https://${aws_cloudfront_distribution.frontend_distribution.domain_name}"
  description = "HTTPS URL для вашого агента"
}

output "api_url" {
  value       = module.api.api_url
  description = "HTTP API URL"
}
