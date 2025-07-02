resource "aws_iam_policy" "bedrock_retrieve_and_generate" {
  name        = "bedrock-retrieve-and-generate"
  description = "Allow Lambda to call Bedrock RetrieveAndGenerate on KB"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "bedrock:RetrieveAndGenerate"
        ],
        "Resource": [
          "arn:aws:bedrock:eu-central-1:${data.aws_caller_identity.current.account_id}:knowledge-base/BAYTVPOCZJ"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach_bedrock" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.bedrock_retrieve_and_generate.arn
}
