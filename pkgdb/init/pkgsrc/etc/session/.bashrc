# If not running interactively, don't do anything
if [ "$-" -ne "*i*" ]; then return; fi

clear

# Alias definitions.
alias ll='ls -la'

export EDITOR=vi
export PAGER=less
export PS1="\[\e[32;1m\][\[\e[m\]\[\e[31;1m\]\u\[\e[m\]\[\e[32;1m\]@\[\e[m\]\h\[\e[m\]: \[\e[m\]\[\e[36;1m\]\W\[\e[m\]\[\e[32;1m\]\[\e[m\]\[\e[31;1m \[\e[32;1m\]\A]\[\e[31;1m\]\]\\$\[\e[m\] "

# don't put duplicate lines in the historyi
HISTCONTROL=ignoredups:ignorespace

# append to the history file, don't overwrite it
shopt -s histappend

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

echo -e "$(cat /etc/motd.custom)"
