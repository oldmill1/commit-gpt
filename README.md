# commit-gpt

🧠 AI-powered Git commit assistant using OpenAI.

This script helps you write clear, one-line commit messages from Git diffs using GPT-4.

## Features

- Understands real Git diffs (even untracked files)
- Auto-generates commit messages with OpenAI
- Confirms before committing and pushing
- Interactive repo selector

## Usage

Make it executable:

```bash
chmod +x commitmsg.sh
```

Run it:

```bash
./commitmsg.sh
```

Or add to your shell config:

```bash
alias aicomm="~/dev/commit-gpt/commitmsg.sh"
```
