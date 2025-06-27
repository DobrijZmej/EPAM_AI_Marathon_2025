resource "aws_secretsmanager_secret" "openai" {
  name        = "openai-api-key"
  description = "OpenAI API key for GPT-3.5"
}
