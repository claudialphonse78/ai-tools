# ai-tools

AI-powered agents and skills for Cursor IDE and Claude Code.

## Available Tools

| Tool | What it does | Platforms |
|------|-------------|-----------|
| [pre-commit-review](pre-commit-review/) | Reviews uncommitted code changes — missing tests, security, type safety, PF standards, Jira ACs, screenshots | Cursor, Claude Code |
| [copy-to-clipboard](copy-to-clipboard/) | Copies assistant output to clipboard as rich text for Slack, email, Confluence | Cursor, Claude Code |

## Quick Install

```bash
# Clone the repo
git clone <your-repo-url> ~/git/ai-tools
cd ~/git/ai-tools

# Install a tool into any project (creates symlinks for both Cursor + Claude)
./install.sh pre-commit-review --to ~/path/to/your/project
./install.sh copy-to-clipboard --to ~/path/to/your/project

# Or cd into your project first
cd ~/path/to/your/project
~/git/ai-tools/install.sh copy-to-clipboard
```

This creates symlinks in your project:
```
your-project/
├── .cursor/agents/pre-commit-review.md  ->  ai-tools/pre-commit-review/cursor-agent.md
├── .cursor/agents/copy-to-clipboard.md  ->  ai-tools/copy-to-clipboard/cursor-agent.md
├── .claude/skills/pre-commit-review/SKILL.md  ->  ai-tools/pre-commit-review/SKILL.md
├── .claude/skills/copy-to-clipboard/SKILL.md  ->  ai-tools/copy-to-clipboard/SKILL.md
```

Edit once in `ai-tools`, every linked project gets the update.

## Uninstall

```bash
./install.sh pre-commit-review --uninstall --to ~/path/to/your/project
./install.sh copy-to-clipboard --uninstall --to ~/path/to/your/project
```

## Manual Install (no symlinks)

If you prefer to copy files directly:

```bash
# Cursor
mkdir -p /path/to/project/.cursor/agents
cp pre-commit-review/.cursor/agents/pre-commit-reviewer.md /path/to/project/.cursor/agents/
cp copy-to-clipboard/.cursor/agents/copy-to-clipboard.md /path/to/project/.cursor/agents/

# Claude Code
mkdir -p /path/to/project/.claude/skills/pre-commit-review
cp pre-commit-review/.claude/skills/pre-commit-review/SKILL.md /path/to/project/.claude/skills/pre-commit-review/
mkdir -p /path/to/project/.claude/skills/copy-to-clipboard
cp copy-to-clipboard/.claude/skills/copy-to-clipboard/SKILL.md /path/to/project/.claude/skills/copy-to-clipboard/
```

## Repo Structure

```
ai-tools/
├── pre-commit-review/                              # Code review agent
│   ├── .cursor/agents/pre-commit-reviewer.md       # Cursor IDE agent
│   ├── .claude/skills/pre-commit-review/SKILL.md   # Claude Code skill
│   └── README.md                                   # Tool-specific documentation
├── copy-to-clipboard/                              # Rich text clipboard copy
│   ├── .cursor/agents/copy-to-clipboard.md         # Cursor IDE agent
│   ├── .claude/skills/copy-to-clipboard/SKILL.md   # Claude Code skill
│   └── README.md                                   # Tool-specific documentation
├── install.sh                                      # Symlink installer (both platforms)
└── README.md                                       # This file
```

Adding a new tool: create a folder with `.cursor/agents/` and/or `.claude/skills/` inside it. The install script auto-discovers it.
