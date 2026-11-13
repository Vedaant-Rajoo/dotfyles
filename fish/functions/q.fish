function q --description 'Ask Claude, or Codex with -x, for a terminal command'
    # The system prompt lives in fish/q-prompt.md so it can be edited without touching code.
    set -l sys (string collect <$__fish_config_dir/q-prompt.md); or return 1

    set -l use_codex
    if test "$argv[1]" = -x
        set use_codex 1
        set -e argv[1]
    end

    # With no words, prompt for the question so apostrophes, * and | need no quoting.
    set -l question "$argv"
    if test -z "$question"
        read -P 'q> ' question; or return 1
        test -n "$question"; or return 1
    end

    # The prompt asks for fish commands with # comments, so bat can color them.
    set -l render cat
    command -q bat; and set render bat --language=fish --style=plain --paging=never

    if set -q use_codex[1]
        # codex prints its progress on stderr; the answer arrives on stdout.
        codex exec --ephemeral --skip-git-repo-check -s read-only \
            -m gpt-5.6-luna -c model_reasoning_effort='"low"' \
            -c developer_instructions="$sys" "$question" 2>/dev/null | $render
        if test $pipestatus[1] -ne 0
            echo 'q: codex failed; run it without 2>/dev/null to see why' >&2
            return 1
        end
    else
        claude -p --model haiku --tools '' --no-session-persistence \
            --system-prompt "$sys" "$question" | $render
        return $pipestatus[1]
    end
end
