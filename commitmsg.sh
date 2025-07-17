#!/bin/bash
# OpenAI API configuration
API_KEY="${OPENAI_API_KEY}"
MODEL="gpt-4"
echo "$API_KEY" | wc -c

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
  echo "❌ jq is required but not installed. Install it first."
  exit 1
fi

# Ask user which Git directory to use
DEFAULT_DIR="$HOME/dev"
echo "📁 Default search root: $DEFAULT_DIR"

while true; do
  read -r -p "📂 Which Git directory do you want to use? (relative to $DEFAULT_DIR): " INPUT_DIR
  TARGET_DIR="$DEFAULT_DIR/$INPUT_DIR"

  if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ Directory does not exist: $TARGET_DIR"
    continue
  fi

  if git -C "$TARGET_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    echo "✅ Using Git repo at: $TARGET_DIR"
    cd "$TARGET_DIR" || { echo "❌ Failed to enter $TARGET_DIR"; exit 1; }
    break
  else
    echo "⚠️ '$TARGET_DIR' is not a Git repository."
  fi
done

# Generate full diff (new + tracked changes)
echo "📥 Collecting working tree changes..."
git add -N .  # Include untracked files
DIFF_CONTENT=$(git diff HEAD)

# Check for empty diff
if [ -z "$DIFF_CONTENT" ]; then
  echo "✅ No changes detected. Nothing to describe."
  exit 0
fi

# Prepare JSON payload
REQUEST_JSON=$(jq -n \
  --arg model "$MODEL" \
  --arg system "You are a commit message generator. Your job is to write concise, clear, one-line git commit messages." \
  --arg prompt "Generate a one-line git commit message describing the following diff:\n\n$DIFF_CONTENT" \
  '{
    model: $model,
    messages: [
      { role: "system", content: $system },
      { role: "user", content: $prompt }
    ]
  }')

# Call OpenAI API
RESPONSE=$(curl -s https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer ${API_KEY:-$OPENAI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_JSON")

# Extract commit message
COMMIT_MSG=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // "❌ Failed to get a commit message."')
CLEAN_MSG=$(echo "$COMMIT_MSG" | sed 's/^"\(.*\)"$/\1/')

echo -e "\n💬 Commit message:"
echo "$CLEAN_MSG"

# Ask to commit
read -r -p "🟢 Do you want me to commit these changes with this message? (y/N) " CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
  git add .
  git commit -m "$CLEAN_MSG"
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  echo "✅ Committed to $BRANCH"

  # Ask to push
  read -r -p "📤 Do you want me to push the changes to '$BRANCH'? (y/N) " PUSH_CONFIRM
  if [[ "$PUSH_CONFIRM" =~ ^[Yy]$ ]]; then
    git push origin "$BRANCH"
    echo "✅ Changes pushed to origin/$BRANCH"
  else
    echo "❌ Skipping push."
  fi
else
  echo "❌ Skipping commit."
fi