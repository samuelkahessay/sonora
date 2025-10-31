#!/bin/bash
# Test if OpenAI Responses API supports streaming

if [ -z "$OPENAI_API_KEY" ]; then
  echo "Error: OPENAI_API_KEY environment variable not set"
  exit 1
fi

echo "Testing Responses API with stream=true..."

curl -N --no-buffer -X POST \
  https://api.openai.com/v1/responses \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5-nano",
    "input": [
      {
        "role": "user",
        "content": [{"type": "input_text", "text": "Say hello in JSON format with a single key called greeting"}]
      }
    ],
    "text": {
      "format": {"type": "json_object"},
      "verbosity": "low"
    },
    "reasoning": {"effort": "low"},
    "stream": true
  }' 2>&1 | head -50
