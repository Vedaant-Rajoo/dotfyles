export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
CASE_SENSITIVE="true"
zstyle ':omz:update' mode auto      # update automatically without asking
ENABLE_CORRECTION="true"

plugins=(git 
    zsh-autopair
    alias-tips
    colorize
    macos
    zsh_codex
    alias-maker
    zsh-autosuggestions 
    zsh-syntax-highlighting
)
bindkey '^X' create_completion

source $ZSH/oh-my-zsh.sh

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#939393,bold,underline"

alias bl="brew list"
alias src="source ~/.zshrc"
alias zshrc="code ~/.zshrc"
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'
alias cd='z'

eval "$(zoxide init zsh)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
