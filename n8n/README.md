# AES AI Assistant: n8n proxy

The app's AI Assistant sends its chat request (OpenAI-compatible: `{ model, messages }`) to
this n8n webhook instead of straight to Groq. n8n checks the request, adds the Groq API key
from its own credential store, forwards it, and returns Groq's response unchanged.

The result is that **no API key is compiled into the app**. Anything inside an APK or a web
bundle can be extracted, but the webhook URL alone does not reveal the key.

```
Flutter app ──POST {model, messages}──▶ n8n webhook ──▶ validate ──▶ Groq API
                                               ◀──────── response ◀──┘
```

## Setup

1. In n8n: **Workflows → Import from File** → `aes_ai_proxy_workflow.json`.
2. Open **Call Groq** → credential → **Create New** → type **Header Auth**:
   - Name: `Authorization`
   - Value: `Bearer <your GroqCloud key>`
3. **Activate** the workflow and copy the Webhook node's **Production URL**
   (for example `https://your-n8n-host/webhook/aes-ai`).
4. Build the app with that URL:

   ```bash
   flutter build apk --dart-define=AI_PROXY_URL=https://your-n8n-host/webhook/aes-ai
   flutter build web --dart-define=AI_PROXY_URL=https://your-n8n-host/webhook/aes-ai
   ```

## Safeguards

- **Model allow-list.** Only the two models the app uses (`llama-3.3-70b-versatile` and the
  Llama 4 Scout vision model) are forwarded, and only for a bounded message list. Anything
  else gets a 400, so the webhook can't be used as a general-purpose free Groq relay.
- **Caller identity (optional hardening).** The app sends the signed-in user's Firebase ID
  token in `X-Firebase-Id-Token`. The workflow does not verify it yet. Adding a verification
  step (Google's public keys, or a small Cloud Function) would restrict the proxy to real
  AES users.
- Keep a usage limit on the Groq key in the Groq console as well.

## Local development

For quick local testing without n8n you can pass a key directly:
`flutter run --dart-define=GROQ_API_KEY=gsk_...`. Never ship a build made this way.
