import base64
import json
import boto3
from openai import OpenAI

def extract_jwt_claims_from_header(headers):
    auth = headers.get("authorization") or headers.get("Authorization")
    if not auth or not auth.startswith("Bearer "):
        return {}

    token = auth.split(" ")[1]
    parts = token.split(".")

    if len(parts) != 3:
        return {}

    payload_b64 = parts[1]
    # Додати паддінг, якщо потрібно
    rem = len(payload_b64) % 4
    if rem > 0:
        payload_b64 += "=" * (4 - rem)

    try:
        decoded_bytes = base64.urlsafe_b64decode(payload_b64)
        decoded = json.loads(decoded_bytes)
        return decoded
    except Exception as e:
        print(f"❌ Failed to decode JWT payload: {e}")
        return {}
        
def get_openai_secret():
    secret_name = "openai-api-key"
    region_name = "eu-central-1"

    client = boto3.client("secretsmanager", region_name=region_name)

    try:
        response = client.get_secret_value(SecretId=secret_name)
        secret_string = response.get("SecretString")

        if not secret_string:
            print("❌ Secret exists but has no value.")
            return None

        secret = json.loads(secret_string)
        print(f"✅ Secret loaded: {list(secret.keys())}")
        return secret

    except Exception as e:
        print(f"❌ Failed to load secret: {e}")
        return None

def handler(event, context):
    print("EVENT:", json.dumps(event))  # Для дебагу

    method = (
        event.get("requestContext", {}).get("http", {}).get("method")
        or event.get("httpMethod")
        or "GET"
    )

    # 👇 Визначення ролі за JWT
    claims = extract_jwt_claims_from_header(event.get("headers", {}))
    groups = claims.get("cognito:groups", []) if claims else []

    if isinstance(groups, str):  # Cognito може передати як string
        groups = [groups]

    is_editor = "editor" in groups or "admin" in groups
    is_admin = "admin" in groups

    print(f"Групи користувача: {groups}")
    print(f"Редактор: {is_editor}, Адмін: {is_admin}")

    if method == "OPTIONS":
        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, Authorization"
            },
            "body": ""
        }

    # 👇 Обробка POST-даних
    body_data = {}
    if event.get("body"):
        try:
            body_data = json.loads(event["body"])
        except Exception as e:
            print("Failed to parse body:", str(e))

    question = body_data.get("question", "немає питання")

    # 👇 Читання OpenAI API ключа
    secret = get_openai_secret()
    if not secret:
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": "Не вдалося завантажити OpenAI API ключ"})
        }

    client = OpenAI(api_key=secret.get("api_key"))

    try:
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[{"role": "user", "content": question}],
        )
        print(response)
        gpt_answer = response.choices[0].message.content
    except Exception as e:
        print(f"❌ GPT помилка: {e}")
        gpt_answer = "Виникла помилка при зверненні до GPT."

    return {
        "statusCode": 200,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Authorization",
            "Content-Type": "application/json"
        },
        "body": json.dumps({
            "question": question,
            "answer": gpt_answer,
            "user_role": groups
        })
    }