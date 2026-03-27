#!/bin/bash
set -euo pipefail

AI_TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  echo "Usage: install.sh <skill-name> [--to <project-dir>] [--uninstall]"
  echo ""
  echo "Installs a skill into a project by creating symlinks."
  echo "Both Cursor agent and Claude skill are linked."
  echo ""
  echo "Examples:"
  echo "  # Install into current directory"
  echo "  $AI_TOOLS_DIR/install.sh pre-commit-review"
  echo ""
  echo "  # Install into a specific project"
  echo "  $AI_TOOLS_DIR/install.sh pre-commit-review --to ~/projects/my-app"
  echo ""
  echo "  # Uninstall (remove symlinks)"
  echo "  $AI_TOOLS_DIR/install.sh pre-commit-review --uninstall"
  echo ""
  echo "Available skills:"
  for dir in "$AI_TOOLS_DIR"/*/; do
    name=$(basename "$dir")
    if [ -d "$dir/.cursor/agents" ] || [ -d "$dir/.claude/skills" ]; then
      echo "  - $name"
    fi
  done
  exit 0
}

if [ $# -lt 1 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  usage
fi

SKILL_NAME="$1"
shift

PROJECT_DIR="$(pwd)"
UNINSTALL=false

while [ $# -gt 0 ]; do
  case "$1" in
    --to)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

SKILL_DIR="$AI_TOOLS_DIR/$SKILL_NAME"

if [ ! -d "$SKILL_DIR" ]; then
  echo "Error: skill '$SKILL_NAME' not found at $SKILL_DIR"
  echo ""
  echo "Available skills:"
  for dir in "$AI_TOOLS_DIR"/*/; do
    name=$(basename "$dir")
    if [ -d "$dir/.cursor/agents" ] || [ -d "$dir/.claude/skills" ]; then
      echo "  - $name"
    fi
  done
  exit 1
fi

if [ "$UNINSTALL" = true ]; then
  echo "Uninstalling $SKILL_NAME from $PROJECT_DIR..."

  # Remove Cursor agent symlinks
  if [ -d "$SKILL_DIR/.cursor/agents" ]; then
    for file in "$SKILL_DIR/.cursor/agents"/*.md; do
      [ -f "$file" ] || continue
      fname=$(basename "$file")
      target="$PROJECT_DIR/.cursor/agents/$fname"
      if [ -L "$target" ]; then
        rm "$target"
        echo "  Removed .cursor/agents/$fname"
      fi
    done
  fi

  # Remove Claude skill symlinks
  if [ -d "$SKILL_DIR/.claude/skills" ]; then
    for skilldir in "$SKILL_DIR/.claude/skills"/*/; do
      [ -d "$skilldir" ] || continue
      sname=$(basename "$skilldir")
      target="$PROJECT_DIR/.claude/skills/$sname/SKILL.md"
      if [ -L "$target" ]; then
        rm "$target"
        echo "  Removed .claude/skills/$sname/SKILL.md"
      fi
      rmdir "$PROJECT_DIR/.claude/skills/$sname" 2>/dev/null || true
    done
  fi

  echo "Done."
  exit 0
fi

echo "Installing $SKILL_NAME into $PROJECT_DIR..."

# Link Cursor agents
if [ -d "$SKILL_DIR/.cursor/agents" ]; then
  mkdir -p "$PROJECT_DIR/.cursor/agents"
  for file in "$SKILL_DIR/.cursor/agents"/*.md; do
    [ -f "$file" ] || continue
    fname=$(basename "$file")
    ln -sf "$file" "$PROJECT_DIR/.cursor/agents/$fname"
    echo "  Cursor: .cursor/agents/$fname -> $file"
  done
fi

# Link Claude skills
if [ -d "$SKILL_DIR/.claude/skills" ]; then
  for skilldir in "$SKILL_DIR/.claude/skills"/*/; do
    [ -d "$skilldir" ] || continue
    sname=$(basename "$skilldir")
    mkdir -p "$PROJECT_DIR/.claude/skills/$sname"
    if [ -f "$skilldir/SKILL.md" ]; then
      ln -sf "$skilldir/SKILL.md" "$PROJECT_DIR/.claude/skills/$sname/SKILL.md"
      echo "  Claude: .claude/skills/$sname/SKILL.md -> $skilldir/SKILL.md"
    fi
  done
fi

echo ""
echo "Done. Both platforms are now linked."
echo "Edit the source in $SKILL_DIR — all linked projects get the update."
