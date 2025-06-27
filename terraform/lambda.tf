resource "aws_iam_role" "lambda_exec" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "ask_handler" {
  function_name = "ask_handler"
  handler       = "ask_handler.handler"
  runtime       = "python3.11"
  timeout       = 60
  filename      = "${path.module}/lambda/ask_handler.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/ask_handler.zip")
  role          = aws_iam_role.lambda_exec.arn
  layers = [
    "arn:aws:lambda:eu-central-1:226802345751:layer:openai-layer:3"
  ]
}

resource "aws_iam_policy" "lambda_openai_secret_policy" {
  name = "lambda-openai-secret-access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "secretsmanager:GetSecretValue"
      ],
      Resource = aws_secretsmanager_secret.openai.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_secret_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_openai_secret_policy.arn
}
