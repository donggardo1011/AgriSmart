from openai import OpenAI

client = OpenAI(api_key="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")

response = client.responses.create(
    model="gpt-5-mini",
    input="Say 'API key is working' if you can read this."
)

print(response.output_text)