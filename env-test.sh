#!/bin/bash

echo "🧪 Environment Variable Test Script"
echo "=================================="

# Function to load .env file (same as in commitmsg.sh)
load_env() {
    local env_file="$1"
    if [ -f "$env_file" ]; then
        echo "📄 Loading environment from: $env_file"
        # Export variables from .env file, ignoring comments and empty lines
        export $(grep -v '^#' "$env_file" | grep -v '^$' | xargs)
        return 0
    fi
    return 1
}

# Test .env file loading
echo -e "\n🔍 Testing .env file loading..."

ENV_LOADED=false
ENV_FILE_FOUND=""

# Check current directory first
if load_env ".env"; then
    ENV_LOADED=true
    ENV_FILE_FOUND="$(pwd)/.env"
# Check parent directory
elif load_env "../.env"; then
    ENV_LOADED=true
    ENV_FILE_FOUND="$(dirname $(pwd))/.env"
# Check home directory
elif load_env "$HOME/.env"; then
    ENV_LOADED=true
    ENV_FILE_FOUND="$HOME/.env"
else
    echo "❌ No .env file found in current dir, parent dir, or home dir"
fi

echo -e "\n📊 Environment Loading Results:"
echo "================================"
echo "ENV_LOADED: $ENV_LOADED"
echo "ENV_FILE_FOUND: ${ENV_FILE_FOUND:-'None'}"

# Test specific variables
echo -e "\n🔑 Testing OpenAI Variables:"
echo "============================"

# Required variables
echo "OPENAI_API_KEY: ${OPENAI_API_KEY:+[SET - ${#OPENAI_API_KEY} chars]} ${OPENAI_API_KEY:+✅} ${OPENAI_API_KEY:-❌ NOT SET}"

# Optional variables with defaults
echo "OPENAI_MODEL: ${OPENAI_MODEL:-gpt-4 (default)} ${OPENAI_MODEL:+✅} ${OPENAI_MODEL:-⚠️  using default}"
echo "OPENAI_MAX_TOKENS: ${OPENAI_MAX_TOKENS:-24000 (default)} ${OPENAI_MAX_TOKENS:+✅} ${OPENAI_MAX_TOKENS:-⚠️  using default}"

echo -e "\n🏠 Testing Git Variables:"
echo "========================"
echo "GIT_DEFAULT_DIR: ${GIT_DEFAULT_DIR:-$HOME/dev (default)} ${GIT_DEFAULT_DIR:+✅} ${GIT_DEFAULT_DIR:-⚠️  using default}"

echo -e "\n🐛 Testing Debug Variables:"
echo "=========================="
echo "DEBUG_OPENAI: ${DEBUG_OPENAI:-false (default)} ${DEBUG_OPENAI:+✅} ${DEBUG_OPENAI:-⚠️  using default}"

# Validate critical requirements
echo -e "\n✅ Validation Results:"
echo "====================="

VALIDATION_PASSED=true

if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ OPENAI_API_KEY is required but not set"
    VALIDATION_PASSED=false
else
    echo "✅ OPENAI_API_KEY is set"

    # Check if it looks like a valid OpenAI key (both old and new formats)
    if [[ "$OPENAI_API_KEY" =~ ^sk-[a-zA-Z0-9_-]{20,}$ ]]; then
        echo "✅ OPENAI_API_KEY format appears valid"

        # Identify format type
        if [[ "$OPENAI_API_KEY" =~ ^sk-proj- ]]; then
            echo "✅ Using new project-based API key format"
        elif [[ "$OPENAI_API_KEY" =~ ^sk-[a-zA-Z0-9]{48}$ ]]; then
            echo "✅ Using legacy API key format"
        else
            echo "✅ Using valid OpenAI API key format"
        fi
    else
        echo "⚠️  OPENAI_API_KEY format may be invalid (should start with 'sk-')"
    fi
fi

# Test if jq is available (required by main script)
if command -v jq &> /dev/null; then
    echo "✅ jq is installed and available"
else
    echo "❌ jq is required but not installed"
    VALIDATION_PASSED=false
fi

# Test if curl is available
if command -v curl &> /dev/null; then
    echo "✅ curl is available"
else
    echo "❌ curl is required but not available"
    VALIDATION_PASSED=false
fi

# Show .env file contents (safely)
if [ "$ENV_LOADED" = true ] && [ -f "$ENV_FILE_FOUND" ]; then
    echo -e "\n📄 .env File Contents (API key masked):"
    echo "======================================="
    sed 's/OPENAI_API_KEY=.*/OPENAI_API_KEY=***MASKED***/' "$ENV_FILE_FOUND"
fi

# Final result
echo -e "\n🎯 Final Result:"
echo "==============="
if [ "$VALIDATION_PASSED" = true ]; then
    echo "🎉 All tests passed! Your environment is ready for commitmsg.sh"
    exit 0
else
    echo "💥 Some tests failed. Please fix the issues above before using commitmsg.sh"
    exit 1
fi