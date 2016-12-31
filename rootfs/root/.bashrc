# If not running interactively, don't do anything
#[ -z "$PS1" ] && return

export PS1="\[\e[32;1m\][\[\e[m\]\[\e[31;1m\]\u\[\e[m\]\[\e[32;1m\]@\[\e[m\]\h\[\e[m\]: \[\e[m\]\[\e[36;1m\]\W\[\e[m\]\[\e[32;1m\]\[\e[m\]\[\e[31;1m \[\e[32;1m\]\A]\[\e[31;1m\]\]\\$\[\e[m\] "

# don't put duplicate lines in the historyi
HISTCONTROL=ignoredups:ignorespace

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=9999999
HISTFILESIZE=9999999

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Alias definitions.
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

eval "$(tmuxifier init -)"

if [ -z "$TMUX" ]; then
    tmuxifier load-session tmux
fi
