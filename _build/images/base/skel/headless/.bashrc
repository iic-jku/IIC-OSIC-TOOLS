# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
#
# Interactive-shell config. The environment setup (PATH, PYTHONPATH, PDK
# defaults, helper functions, ...) lives in /etc/profile.d/iic-osic-tools-setup.sh
# so that login shells and interactive shells share a single source of truth.

# Ensure the environment is initialised even for non-login interactive shells
# (e.g. `bash` started inside an existing shell). The script's internal
# FOSS_INIT_DONE guard prevents duplicate PATH/PYTHONPATH growth.
if [ -f /etc/profile.d/iic-osic-tools-setup.sh ]; then
    # shellcheck source=/dev/null
    source /etc/profile.d/iic-osic-tools-setup.sh
fi

# Add additional display resolutions (for VNC mode). The helper itself is
# a no-op outside of VNC sessions.
if type -t _add_resolution >/dev/null; then
    _add_resolution 2048 1152
    _add_resolution 2560 1080
    _add_resolution 2560 1440
    _add_resolution 2560 1600
    _add_resolution 3440 1440
    _add_resolution 3840 2160
fi

#----------------------------------------
# Tool aliases
#----------------------------------------

alias mmagic='MAGTYPE=mag magic'
alias lmagic='MAGTYPE=maglef magic'

alias k='klayout'
alias ke='klayout -e'

alias surfer='LIBGL_ALWAYS_INDIRECT=0 surfer'
# IHP-SG13G2 needs this plugin, using an alias seems to the the only proper solution for now
alias xyce='xyce -plugin $PDK_ROOT/ihp-sg13g2/libs.tech/xyce/plugins/Xyce_Plugin_PSP103_VA.so'
alias Xyce='Xyce -plugin $PDK_ROOT/ihp-sg13g2/libs.tech/xyce/plugins/Xyce_Plugin_PSP103_VA.so'

# Show hint that OpenLane has been removed
alias flow.tcl='printf "[INFO] OpenLane has been depreciated.\n[INFO] Please use LibreLane (start with <librelane>).\n"'
# Show hint that OpenLane2 has been removed
alias openlane='printf "[INFO] OpenLane2 has been depreciated.\n[INFO] Please use LibreLane (start with <librelane>).\n"'

alias iic-pdk='source iic-pdk-script.sh'
alias sak-pdk='source sak-pdk-script.sh'
alias tt='cd $TOOLS'
alias dd='cd $DESIGNS'
alias pp='cd $PDK_ROOT'
alias destroy='sudo \rm -rf'
alias cp='cp -i'
alias egrep='egrep '
alias fgrep='fgrep '
alias grep='grep '
alias ls='ls --color=auto'
alias l.='ls -d .* '
alias ll='ls -l'
alias la='ls -al '
alias llt='ls -lt'
alias llta='ls -alt'
alias du='du -skh'
alias mv='mv -i'
alias rm='rm -i'
alias vrc='vi ~/.bashrc'
alias dux='du -sh* | sort -h'
alias shs='md5sum'
alias h='history'
alias hh='history | grep'
alias rc='source ~/.bashrc'
alias m='less'
alias term='xfce4-terminal'

#----------------------------------------
# Git
#----------------------------------------

alias gcl='git clone'
alias gcll='git clone --single-branch --depth=1'
alias ga='git add'
alias gc='git commit -a'
alias gps='git push'
alias gpl='git pull'
alias gco='git checkout'
alias gss='git status'
alias gr='git remote -v'
alias gl='git log'
alias gln='git log --name-status'
alias gsss='git submodule status'

#----------------------------------------
# User functions
#----------------------------------------

function mdview() {
    if [ $# -eq 0 ]; then
        echo "Usage: mdview <file.md>"
        return 1
    fi
    if [ ! -f "$1" ]; then
        echo "[ERROR] File not found: $1"
        return 1
    fi
    local base
    base=$(basename -- "$1")
    pandoc "$1" > "/tmp/${base}.html" \
        && xdg-open "/tmp/${base}.html"
}

#----------------------------------------
# Adapt user prompt
#----------------------------------------

export PS1='\[\033[0;32m\]\w >\[\033[0;38m\] '
