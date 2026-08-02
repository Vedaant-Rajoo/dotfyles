#!/usr/bin/env python3
# commit-msg-guard — Claude Code PreToolUse hook (matcher: Bash).
# Vets agent-authored `git commit` messages: one lowercase conventional-commit
# subject line of <= 100 chars, and no prose body. A commit should be readable
# at a glance in `git log --oneline`; anything that needs a paragraph belongs in
# SYSTEM.md or README.md, where it is actually discoverable later.
# On violation it denies the tool call and feeds the rules back so the agent
# rewrites the message. Everything else passes through untouched (exit 0).
import json
import re
import sys

TYPES = "feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert"
LIMIT = 100

# Machine-meaningful trailers are not prose and stay allowed after a blank line:
# git and forges parse these for attribution and sign-off.
TRAILERS = (
    "co-authored-by",
    "signed-off-by",
    "reviewed-by",
    "acked-by",
    "tested-by",
    "reported-by",
    "suggested-by",
    "cc",
)

STYLE = (
    "required style: a single line, <type>(<scope>)?: <description> — all "
    f"lowercase, <= {LIMIT} chars, no body. types: {TYPES}. keep it simple but "
    'informative, e.g. "feat(fish): add tmux sessionizer keybind". put rationale '
    "and findings in SYSTEM.md or README.md, not in the commit. only trailers "
    f"({', '.join(TRAILERS)}) may follow, after a blank line. "
    "rewrite the commit message and retry."
)

CONVENTIONAL = re.compile(r"^(?:" + TYPES + r")(?:\([a-z0-9._/-]+\))?!?: \S")

TRAILER_LINE = re.compile(
    r"^(?:" + "|".join(TRAILERS) + r"):\s+\S",
    re.IGNORECASE,
)


def extract_message(command):
    """Return the full commit message from a git commit command, or None."""
    if not re.search(r"\bgit\b[^\n]*\bcommit\b", command):
        return None

    # heredoc form: git commit -F - <<'EOF' ... EOF
    m = re.search(r"<<-?\s*['\"]?(\w+)['\"]?[^\n]*\n(.*?)\n\1\b", command, re.DOTALL)
    if m:
        return m.group(2)

    # inline form: -m "...", -am '...', --message=...
    # git joins repeated -m into paragraphs, so every occurrence is collected:
    # `-m subject -m body` is a body just as much as a heredoc is. One pattern
    # covers all three quoting styles — per-style passes let a command mixing
    # them (`-m "subject" -m 'body'`) return only the first style's matches
    # and smuggle the body past the check.
    pattern = (
        r"(?:^|\s)(?:-[a-zA-Z]*m|--message)[= ]\s*"
        r"(?:\"((?:[^\"\\]|\\.)*)\"|'([^']*)'|(\S+))"
    )
    parts = [
        next(g for g in m.groups() if g is not None)
        for m in re.finditer(pattern, command)
    ]
    if parts:
        return "\n\n".join(parts)
    return None  # no message on the command line (amend --no-edit, -F file, …)


def split_message(message):
    """Return (subject, prose_body_lines). Blank lines and trailers are dropped."""
    lines = message.splitlines()
    subject = None
    body = []
    for line in lines:
        stripped = line.strip()
        if subject is None:
            if stripped:
                subject = stripped
            continue
        if not stripped or TRAILER_LINE.match(stripped):
            continue
        body.append(stripped)
    return subject, body


def validate(subject, body):
    problems = []
    if len(subject) > LIMIT:
        problems.append(f"subject is {len(subject)} chars (limit {LIMIT})")
    if re.search(r"[A-Z]", subject):
        problems.append("subject contains uppercase letters")
    if not CONVENTIONAL.match(subject):
        problems.append("subject is not conventional commit format")
    if body:
        preview = body[0][:60] + ("…" if len(body[0]) > 60 else "")
        problems.append(
            f"message has a {len(body)}-line body, which is not allowed "
            f'(first line: "{preview}")'
        )
    return problems


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return
    command = (payload.get("tool_input") or {}).get("command") or ""
    message = extract_message(command)
    if message is None:
        return
    subject, body = split_message(message)
    if subject is None:
        return
    problems = validate(subject, body)
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
