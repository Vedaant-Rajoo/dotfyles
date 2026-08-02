status is-interactive
or return

# Pick a Claude model with Ctrl-p and launch it in the current terminal.
function _claude_model_picker_launch
	if not command -q fzf
		printf 'fzf not found on PATH\n' >&2
		commandline -f repaint
		return 127
	end

	if not command -q claude
		printf 'claude not found on PATH\n' >&2
		commandline -f repaint
		return 127
	end

	# Static model list used by the picker.
	set -l models \
		(string join \t 'Opus 5' 'claude-opus-5') \
		(string join \t 'Sonnet 5' 'claude-sonnet-5') \
		(string join \t 'Haiku 4.5' 'claude-haiku-4-5') \
		(string join \t 'GPT 5.6 Sol' 'gpt-5.6-sol') \
		(string join \t 'GPT 5.6 Terra' 'gpt-5.6-terra') \
		(string join \t 'GPT 5.6 Luna' 'gpt-5.6-luna') \
		(string join \t 'Composer 2.5' 'composer-2.5') \
		(string join \t 'GLM 5.2' 'z-ai/glm-5.2') \
		(string join \t 'Claude Opus 4.6 (Anthropic)' 'anthropic/claude-opus-4.6') \
		(string join \t 'Qwen 3.7 Max' 'qwen/qwen3.7-max') \
		(string join \t 'Grok 4.5' 'x-ai/grok-4.5') \
		(string join \t 'Claude Fable 5 (Anthropic)' 'anthropic/claude-fable-5') \
		(string join \t 'Qwen 3.6 Flash' 'qwen/qwen3.6-flash') \
		(string join \t 'MiniMax M3' 'minimax/minimax-m3') \
		(string join \t 'OpenRouter Free' 'openrouter/free') \
        (string join \t 'Kimi K3' 'moonshotai/kimi-k3')

	set -l selected (printf '%s\n' $models | fzf \
		--prompt=' Claude model> ' \
		--height=40% \
		--reverse \
		--border \
		--delimiter=\t \
		--with-nth=1)
	set -l picker_status $status

	if test $picker_status -ne 0 -o -z "$selected"
		commandline -f repaint
		return 0
	end

	set -l model (string split \t -- "$selected")[2]
	command claude --model "$model"
	set -l claude_status $status
	commandline -f repaint
	return $claude_status
end

bind \cp _claude_model_picker_launch
