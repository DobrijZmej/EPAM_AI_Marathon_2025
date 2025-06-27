resource "aws_apigatewayv2_api" "support_api" {
  name          = "support-agent-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["*"]
    expose_headers = []
    max_age = 3600
}
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  name            = "CognitoJWT"
  api_id          = aws_apigatewayv2_api.support_api.id
  authorizer_type = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [var.user_pool_client_id]
    issuer   = "https://cognito-idp.eu-central-1.amazonaws.com/${var.user_pool_id}"
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.support_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "ask_route" {
  api_id            = aws_apigatewayv2_api.support_api.id
  route_key         = "POST /ask"
  target            = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.support_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
    format          = jsonencode({
      requestId     = "$context.requestId"
      ip            = "$context.identity.sourceIp"
      caller        = "$context.identity.caller"
      user          = "$context.identity.user"
      requestTime   = "$context.requestTime"
      httpMethod    = "$context.httpMethod"
      resourcePath  = "$context.resourcePath"
      status        = "$context.status"
      protocol      = "$context.protocol"
      responseLength = "$context.responseLength"
      errorMessage  = "$context.error.message"
    })
  }
}

resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "/aws/apigateway/support-agent-api-logs"
  retention_in_days = 7
}

resource "aws_lambda_permission" "allow_apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn   = "${aws_apigatewayv2_api.support_api.execution_arn}/*/*"
}
