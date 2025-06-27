resource "aws_cognito_user_pool" "this" {
  name = "support-user-pool"
  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "frontend-client"
  user_pool_id = aws_cognito_user_pool.this.id
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
	"ALLOW_USER_SRP_AUTH",
  ]
  refresh_token_validity = 30
  access_token_validity  = 1
  id_token_validity      = 1

}

resource "aws_cognito_user_group" "editor" {
  user_pool_id = aws_cognito_user_pool.this.id
  name         = "editor"
  description  = "Може редагувати базу знань"
}

resource "aws_cognito_user_group" "admin" {
  user_pool_id = aws_cognito_user_pool.this.id
  name         = "admin"
  description  = "Може редагувати базу знань і керувати користувачами"
}


output "user_pool_id" {
  value = aws_cognito_user_pool.this.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.client.id
}
