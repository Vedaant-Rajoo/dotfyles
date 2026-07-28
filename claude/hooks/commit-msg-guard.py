#!/usr/bin/env python3
# commit-msg-guard — Claude Code PreToolUse hook (matcher: Bash).
# Vets agent-authored `git commit` messages: lowercase, conventional commit
# format, subject <= 100 chars. On violation it denies the tool call and feeds
# the rules back so the agent rewrites the message. Everything else passes
# through untouched (exit 0, no output).
import json
import re
import sys

TYPES = "feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"
LIMIT = 100

STYLE = (
    "required style: <type>(<scope>)?: <description> — all lowercase, "
    f"subject line <= {LIMIT} chars. types: {TYPES}. keep it simple but "
    'informative, e.g. "feat(fish): add tmux sessionizer keybind". '
    "rewrite the commit message and retry."
)

CONVENTIONAL = re.compile(
    r"^(?:" + TYPES + r")(?:\([a-z0-9._/-]+\))?!?: \S"
)


def extract_subject(command):
    """Return the commit subject line from a git commit command, or None."""
    if not re.search(r"\bgit\b[^\n]*\bcommit\b", command):
        return None

    # heredoc form: git commit -m "$(cat <<'EOF' ... EOF)"
    m = re.search(r"<<-?\s*['\"]?(\w+)['\"]?[^\n]*\n(.*?)\n\1\b", command, re.DOTALL)
    if m:
        body = m.group(2)
    else:
        # inline form: -m "...", -am '...', --message=...
        for pattern in (
            r"(?:^|\s)(?:-[a-zA-Z]*m|--message)[= ]\s*\"((?:[^\"\\]|\\.)*)\"",
            r"(?:^|\s)(?:-[a-zA-Z]*m|--message)[= ]\s*'([^']*)'",
            r"(?:^|\s)(?:-[a-zA-Z]*m|--message)[= ]\s*(\S+)",
        ):
            m = re.search(pattern, command)
            if m:
                break
        if not m:
            return None  # no message on the command line (amend --no-edit etc.)
        body = m.group(1)

    for line in body.splitlines():
        if line.strip():
            return line.strip()
    return None


def validate(subject):
    problems = []
    if len(subject) > LIMIT:
        problems.append(f"subject is {len(subject)} chars (limit {LIMIT})")
    if re.search(r"[A-Z]", subject):
        problems.append("subject contains uppercase letters")
    if not CONVENTIONAL.match(subject):
        problems.append("subject is not conventional commit format")
    return problems


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return
    command = (payload.get("tool_input") or {}).get("command") or ""
    subject = extract_subject(command)
    if subject is None:
        return
    problems = validate(subject)
    if problems:
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    f'commit message blocked ("{subject}"): '
                    + "; ".join(problems) + ". " + STYLE
                ),
            }
        }))


if __name__ == "__main__":
    main()
