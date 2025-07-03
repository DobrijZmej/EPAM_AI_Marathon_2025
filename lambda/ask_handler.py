import base64
import json
import boto3
import botocore
from openai import OpenAI
import os
from langdetect import detect

print("boto3:", boto3.__version__)
print("botocore:", botocore.__version__)

def synthesize_speech(text, lang='uk'):
    region = 'us-east-1' if lang == 'uk' else 'eu-central-1'
    polly = boto3.client('polly', region_name=region)
    voice_id = 'Oksana' if lang == 'uk' else 'Joanna'
    response = polly.synthesize_speech(
        Text=text,
        OutputFormat='mp3',
        VoiceId=voice_id
    )
    audio_bytes = response['AudioStream'].read()
    audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
    return audio_base64

def detect_lang(text):
    try:
        lang = detect(text)
        # langdetect повертає "en", "uk" тощо
        if lang == 'uk':
            return 'uk'
        else:
            return 'en'
    except Exception as e:
        print(f"Langdetect error: {e}")
        return 'en'  # дефолтна англійська
    
kb_id = os.environ.get('BEDROCK_KB_ID')

def get_bedrock_kb_context(question, kb_id):
    client = boto3.client("bedrock-agent-runtime", region_name="eu-central-1")
    try:
        print(f"kb_id: {kb_id}")
        print(f"question: {question}")
        response = client.retrieve(
            knowledgeBaseId=kb_id,
            retrievalQuery={"text": question}
        )
        # результат — релевантні chunks у response["retrievalResults"]
        docs = []
        for item in response.get("retrievalResults", []):
            doc_text = item.get("content", {}).get("text", "")
            docs.append(doc_text)
        return docs  # список релевантних фрагментів
    except Exception as e:
        print(f"❌ KB Retrieve exception: {e}")
        return []

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

    # 1. Витягуємо релевантний контекст через AWS RAG (Bedrock Knowledge Base)
    try:
        print(f"question: {question}")
        rag_context = get_bedrock_kb_context(question, kb_id)
        print(f"🔗 RAG context: {rag_context}")
    except Exception as e:
        print(f"❌ Не вдалося отримати RAG context: {e}")
        rag_context = ""  # Якщо RAG не доступний — ідемо далі тільки з питанням

    # 2. Формуємо prompt з цим контекстом (RAG + питання)
    prompt = f"Knowledge base: {rag_context}\n\nUser: {question}\nAssistant:"

    client = OpenAI(api_key=secret.get("api_key"))

    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
        )
        print(response)
        gpt_answer = response.choices[0].message.content
    except Exception as e:
        print(f"❌ GPT помилка: {e}")
        gpt_answer = "Виникла помилка при зверненні до GPT."

    # 3. Синтезуємо аудіо через Polly
    try:
        lang = detect_lang(gpt_answer)
        print(f"lang: {lang}")
        lang = 'en'
        audio_base64 = synthesize_speech(gpt_answer, lang=lang)
    except Exception as e:
        print(f"❌ Polly помилка: {e}")
        audio_base64 = None

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
            "user_role": groups,
            "audio_base64": audio_base64
        })
    }