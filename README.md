# Support Agent AI — Serverless Assistant on AWS

This project implements an AI-powered support agent that responds to user questions via a simple web interface. The solution is built entirely on AWS using serverless technologies and managed through Terraform.

## 🚀 Features

- Web frontend hosted via Amazon S3 and optionally served through CloudFront  
- Backend API powered by AWS Lambda and API Gateway  
- User authentication via AWS Cognito (with role-based access: admin, editor)  
- Secrets stored securely in AWS Secrets Manager (e.g., OpenAI key)  
- Infrastructure managed with Terraform for easy and repeatable deployment  

## 🔧 Deployment Instructions

1. **Initialize Terraform**  
   Navigate to the terraform directory and run:  
   `terraform init`

2. **Package the Lambda function**  
   Go to the lambda directory and create the packaging script `ask_handler.zip` from the `/lambda` directory

3. **Apply the infrastructure**  
   Return to the terraform directory and run:  
   terraform apply  
   Type "yes" when prompted.

## 🔐 OpenAI API Key Setup

1. Open AWS Secrets Manager  
2. Find or create a secret named openai-api-key  
3. Store the key using this JSON format:  
   `{ "api_key": "sk-..." }`

## 🌍 Accessing the Application

After deployment, Terraform will output a public URL to access the frontend via S3 or CloudFront.  
Example:  
https://support-agent-frontend-xyz123.cloudfront.net

## 👥 Cognito Authentication

- The project uses AWS Cognito for user management  
- JWT tokens are used with API Gateway authorizers  
- Two predefined user groups: admin and editor  
- You can manage users through the AWS Console or extend the frontend to support sign-up/login  

## 🧪 Local Lambda Testing (Optional)

You can test the Lambda handler locally using:  
- pytest  
- sam local invoke  
- Or by directly calling the handler in Python with a test event  

## 📄 License

This project is licensed under the MIT License.
