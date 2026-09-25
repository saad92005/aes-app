# AES AI Assistant - n8n workflow

This workflow is the backend for the "AI Assistant" chat feature in the app. It keeps your
Anthropic (Claude) API key out of the app entirely - the Flutter app only ever talks to your
n8n webhook, and n8n is the only thing that holds the real API key.

## Setup

1. In n8n, go to **Workflows -> Import from File** and select `aes_chatbot_workflow.json`.
2. Open the **Call Claude** node and set up its credential:
   - Click the credential field -> **Create New Credential**.
   - Credential type: **Header Auth**.
   - Name: `x-api-key`
   - Value: your Anthropic API key (starts with `sk-ant-`).
   - Save it, then select it on the node.
3. Click **Activate** (top right) to turn the workflow on.
4. Open the **Webhook** node and copy its **Production URL** (looks like
   `https://your-n8n-host/webhook/aes-chatbot`).
5. In the Flutter app, open `lib/main.dart`, find `_n8nChatWebhookUrl` near the top of the
   file, and paste that URL in. Rebuild the app.

That's it - no Firebase changes, no API key anywhere in the app's code or build output.

## What it does

- Receives `{ "message": "...", "history": [...] }` from the app.
- Calls Claude (`claude-opus-4-8`) with the web search tool enabled, so it can look up
  current market rates from the web when asked.
- Returns `{ "reply": "..." }` back to the app.

## Cost

Each chat message costs whatever Claude bills for that request (usage-based, billed to
your Anthropic account) - there is no separate n8n hosting cost if you're already running
n8n, and no Firebase plan change is required for this feature.
