#!/bin/bash

# Timestamp logging
log() {
  echo "[$(date +'%H:%M:%S')] $1"
}

log "🚀 Starting AI Commit Message Generator..."

# Load .env file from common locations
load_env() {
  local env_file="$1"
  if [ -f "$env_file" ]; then
    log "📄 Loading environment from: $env_file"
    export $(grep -v '^#' "$env_file" | grep -v '^$' | xargs)
    return 0
  fi
  return 1
}

# Try to load .env from prioritized locations
ENV_LOADED=false
load_env ".env" && ENV_LOADED=true
load_env "../.env" && ENV_LOADED=true
load_env "$HOME/.env" && ENV_LOADED=true
if [ "$ENV_LOADED" = false ]; then
  log "⚠️ No .env file found in current dir, parent dir, or home dir"
fi

API_KEY="${OPENAI_API_KEY}"
MODEL="${OPENAI_MODEL:-gpt-4}"
DEFAULT_DIR="${GIT_DEFAULT_DIR:-$HOME/dev}"
MAX_LENGTH="${OPENAI_MAX_TOKENS:-24000}"

# Log last 3 letters of API key for security
log "🔑 API Key loaded (${#API_KEY} characters): ${API_KEY: -3}"


if [ -z "$API_KEY" ]; then
  log "❌ OPENAI_API_KEY not found!"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  log "❌ jq is required but not installed."
  exit 1
fi

log "🔑 API Key loaded (${#API_KEY} characters)"
log "🧠 Using model: $MODEL"
log "📁 Default search root: $DEFAULT_DIR"

# Ask which Git repo to use
while true; do
  read -r -p "📂 Git directory to use? (relative to $DEFAULT_DIR): " INPUT_DIR
  TARGET_DIR="$DEFAULT_DIR/$INPUT_DIR"

  if [ ! -d "$TARGET_DIR" ]; then
    log "❌ Directory does not exist: $TARGET_DIR"
    continue
  fi

  if git -C "$TARGET_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    log "✅ Found Git repo at: $TARGET_DIR"
    cd "$TARGET_DIR" || { log "❌ Failed to enter $TARGET_DIR"; exit 1; }
    break
  else
    log "⚠️ Not a Git repository: $TARGET_DIR"
  fi
done

log "📥 Collecting working tree changes..."
git add -N .
DIFF_CONTENT=$(git diff HEAD)

SAFE_CHAR_LENGTH=9000

if (( ${#DIFF_CONTENT} > SAFE_CHAR_LENGTH )); then
  log "⚠️ Diff is too large (${#DIFF_CONTENT} chars). Truncating to ${SAFE_CHAR_LENGTH}..."
  DIFF_CONTENT="${DIFF_CONTENT:0:$SAFE_CHAR_LENGTH}"
else
  log "📏 Diff size is within safe range: ${#DIFF_CONTENT} characters"
fi

if [ -z "$DIFF_CONTENT" ]; then
  log "✅ No changes detected. Nothing to describe."
  exit 0
fi

# Short prompt version: keep title + one short paragraph
REQUEST_JSON=$(jq -n \
  --arg model "$MODEL" \
  --arg system "You are a playful Git commit assistant. Generate:
1. A short, whimsical title (blog-post style).
2. A brief paragraph (2–4 sentences) summarizing what changed and why, in a casual tone.
Format:
Title: <title>
Messages: <brief paragraph>" \
  --arg prompt "Here is the git diff:\n\n$DIFF_CONTENT" \
  '{
    model: $model,
    messages: [
      { role: "system", content: $system },
      { role: "user", content: $prompt }
    ]
  }')

log "🤖 Sending request to OpenAI..."
T0=$(date +%s)

RESPONSE=$(curl -s https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_JSON")

T1=$(date +%s)
DURATION=$((T1 - T0))
log "⏱️ OpenAI response received in ${DURATION}s"

echo -e "\n🧪 Raw OpenAI response:"
echo "$RESPONSE" | jq || echo "$RESPONSE"

RAW_OUTPUT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // ""')

# Extract title
TITLE=$(echo "$RAW_OUTPUT" | awk '/^Title:/ {sub(/^Title:[[:space:]]*/, "", $0); gsub(/^"/, "", $0); gsub(/"$/, "", $0); print; exit}')

# Extract everything after "Messages:" (including if it's on the same line)
BODY=$(echo "$RAW_OUTPUT" | awk '
  /^Messages:/ {
    # Inline message
    sub(/^Messages:[[:space:]]*/, "", $0);
    found = 1;
    if (length($0) > 0) print $0;
    next
  }
  found { print }
')

# Trim title and body
TITLE=$(echo "$TITLE" | xargs)
BODY=$(echo "$BODY" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^/    /')

if [[ -z "$TITLE" || -z "$BODY" ]]; then
  log "❌ Failed to parse OpenAI output"
  echo -e "\n🔍 Raw output:\n$RAW_OUTPUT"
  exit 1
fi

# Show preview
echo -e "\n💬 Commit Preview:\n"
echo -e "🔖 $TITLE\n"
echo -e "📜 Messages:\n$BODY\n"

read -r -p "🟢 Commit with this message? (y/N) " CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
  git add .
  git commit -m "$TITLE" -m "$BODY"
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  log "✅ Committed to $BRANCH"

  read -r -p "📤 Push to '$BRANCH'? (y/N) " PUSH_CONFIRM
  if [[ "$PUSH_CONFIRM" =~ ^[Yy]$ ]]; then
    git push origin "$BRANCH"
    log "✅ Changes pushed to origin/$BRANCH"
  else
    log "🚫 Push skipped."
  fi
else
  log "🚫 Commit skipped."
fi
