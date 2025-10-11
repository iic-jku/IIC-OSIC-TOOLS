# shellcheck shell=bash

function _path_add_tool() {
    tool_name=$1
    for d in $TOOLS/$tool_name ; do
        if [ -d "${d}" ]; then
            export PATH=$PATH:${d%/}
        fi
    done
}

function _path_add_tool_custom() {
    custom_path=$1
    for d in $TOOLS/$custom_path/ ; do
        if [ -d "${d}" ]; then
            export PATH=$PATH:${d%/}
        fi
    done
}

function _path_add_tool_python() {
    tool_name=$1
    for d in "$TOOLS/$tool_name"/local/lib/python3*/dist-packages ; do
        if [ -d "${d}" ]; then
            export PYTHONPATH=$PYTHONPATH:${d}
        fi
    done
}

function _add_resolution () {
    # $1=X, $2=Y
    # do only in VNC mode
    if [ -v VNCDESKTOP ]; then
        # and only when resolution not yet available
        # shellcheck disable=SC2143 disable=SC2086
        if [ -z "$(xrandr 2> /dev/null | awk '{print $1}' | grep $1x$2)" ]; then
            #echo "[INFO] Set VNC mode $1x$2"
            MLINE=$(cvt $1 $2 60  | grep -oP '(?<=Modeline ).*')
            # shellcheck disable=SC2001
            MLINE_TRIM=$(echo "$MLINE" | sed 's/^[^"]*"[^"]*"//')
            xrandr --newmode $1x$2 $MLINE_TRIM
            xrandr --addmode VNC-0 $1x$2
        fi
    fi
}

if [ -z ${FOSS_INIT_DONE+x} ]; then
    _path_add_tool          "kactus2"
    _path_add_tool          "klayout"
    _path_add_tool_custom   "osic-multitool"
	
    export SAK=$TOOLS/sak
    export PATH=$TOOLS/bin:$SAK:/usr/local/sbin:$PATH

    # OpenROAD in Ubuntu 22.04 does not find the PIP modules, so use PYTHONPATH
    PYTHONPATH=$(python -c "import sys; print(':'.join(x for x in sys.path if x))") && export PYTHONPATH 
    _path_add_tool_python "ngspyce"
    _path_add_tool_python "openems"
    _path_add_tool_python "pyopus"
    export PYTHONPATH=$PYTHONPATH:$TOOLS/yosys/share/yosys/python3
    KLAYOUT_PYTHON=("$TOOLS"/klayout/pymod)
    export PYTHONPATH=$PYTHONPATH:${KLAYOUT_PYTHON[*]}
    
    [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Final PATH variable: $PATH"
    [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Final PYTHONPATH variable: $PYTHONPATH"

    export FOSS_INIT_DONE=1
fi

# add additional display resolutions (for VNC mode)
_add_resolution 2048 1152
_add_resolution 2560 1080
_add_resolution 2560 1440
_add_resolution 2560 1600
_add_resolution 3440 1440
_add_resolution 3840 2160

# shellcheck disable=SC2086
LD_LIBRARY_PATH="${TOOLS}/klayout:${TOOLS}/ngspice/lib:${TOOLS}/iverilog/lib:${TOOLS}/openems/lib:${TOOLS}/kactus2" && export LD_LIBRARY_PATH
export EDITOR="gedit"
export PYTHONPYCACHEPREFIX="/tmp/pycache"
export KLAYOUT_HOME="/headless/.klayout"

# Enable ngspice co-simulation with VHDL
export CPATH="${TOOLS}/ghdl/include:${TOOLS}/ghdl/include/ghdl:${CPATH}"
export LIBRARY_PATH="${TOOLS}/ghdl/lib:${LIBRARY_PATH}"

# Setting default PDK
export PDK=ihp-sg13g2
export PDKPATH=$PDK_ROOT/$PDK
export STD_CELL_LIBRARY=sg13g2_stdcell
export SPICE_USERINIT_DIR=$PDK_ROOT/$PDK/libs.tech/ngspice
export KLAYOUT_PATH="/headless/.klayout:$PDKPATH/libs.tech/klayout:$PDKPATH/libs.tech/klayout/tech"

# this gets rid of the DBUS warning
# https://unix.stackexchange.com/questions/230238/x-applications-warn-couldnt-connect-to-accessibility-bus-on-stderr/230442#230442
export NO_AT_BRIDGE=1

# first, check if XDG_RUNTIME_DIR is set, if not, set to default.
if [ -z ${XDG_RUNTIME_DIR+z} ]; then
    export XDG_RUNTIME_DIR=/tmp/runtime-default
fi
# second, verify if the actual directory exists, if not, create it.
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
fi

# this is needed for Veryl to store its data
if [ -z ${XDG_DATA_HOME+z} ]; then
    export XDG_DATA_HOME=/headless/.data-default
fi
if [ ! -d "$XDG_DATA_HOME" ]; then
    mkdir -p "$XDG_DATA_HOME"
fi

# add local directories in $HOME to the path so that the user can upgrade PIP packages
export PATH=$HOME/.local/bin:$PATH
export PYTHONPATH=$HOME/.local/lib/python3.10/site-packages:$PYTHONPATH

#----------------------------------------
# tool aliases
#----------------------------------------

alias mmagic='MAGTYPE=mag magic'
alias lmagic='MAGTYPE=maglef magic'

alias k='klayout'
alias ke='klayout -e'

alias librelane='librelane --manual-pdk'
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
# git
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
# user functions
#----------------------------------------

function mdview() {
    if [ $# -eq 0 ]; then
        echo "Usage: mdview <file.md>"
    else
        pandoc "$1" > "/tmp/$1.html"
        xdg-open "/tmp/$1.html"
  fi
}

#----------------------------------------
# adapt user prompt
#----------------------------------------

export PS1='\[\033[0;32m\]\w >\[\033[0;38m\] '

#----------------------------------------
# source user configs from $DESIGNS
#----------------------------------------

if [ -f "$DESIGNS/.designinit" ]; then
    # shellcheck source=/dev/null
    source "$DESIGNS/.designinit"
fi
