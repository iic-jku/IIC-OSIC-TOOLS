# shellcheck shell=bash

function _path_add_tool_bin() {
        tool_name=$1
        for d in $TOOLS/$tool_name ; do
                if [ -d "${d}bin" ]; then
                        export PATH=$PATH:${d}bin
                fi
        done
}

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

if [ -z ${FOSS_PATH_SET+x} ]; then
        _path_add_tool_bin      "covered"
        _path_add_tool_bin      "cvc_rv"
        _path_add_tool          "fault"
        _path_add_tool_bin      "gaw3-xschem"
        _path_add_tool_bin      "gds3d"
        _path_add_tool_bin      "ghdl"
        _path_add_tool_bin      "gtkwave"
        _path_add_tool_bin      "irsim"
        _path_add_tool_bin      "iverilog"
        _path_add_tool          "klayout"
        _path_add_tool_custom   "libman"
        _path_add_tool_bin      "magic"
        _path_add_tool_bin      "netgen"
        _path_add_tool_bin      "ngspice"
        _path_add_tool_bin      "nvc"
        _path_add_tool_bin      "openroad"
        _path_add_tool_bin      "opensta"
	_path_add_tool_bin	"openvaf"
        _path_add_tool_custom   "osic-multitool"
        _path_add_tool_bin      "padring"
        _path_add_tool_bin      "pyopus"
        _path_add_tool_bin      "qflow"
        _path_add_tool_bin      "qucs-s"
        _path_add_tool_custom   "rftoolkit/bin"
        _path_add_tool_bin      "slang"
        _path_add_tool_bin      "verilator"
        _path_add_tool_bin      "xschem"
        _path_add_tool_bin      "xyce"
        _path_add_tool_bin      "yosys"
        _path_add_tool_custom   "yosys/bin"
	
        export SAK=$TOOLS/sak/
        export PATH=$TOOLS/bin:$SAK:/usr/local/sbin:$PATH

        # FIXME: OpenROAD in Ubuntu 22.04 does not find the PIP modules, so use PYTHONPATH
        PYTHONPATH=$(python -c "import sys; print(':'.join(x for x in sys.path if x))") && export PYTHONPATH 
        _path_add_tool_python "ngspyce"
        _path_add_tool_python "pyopus"
        export PYTHONPATH=$PYTHONPATH:$TOOLS/yosys/share/yosys/python3
        KLAYOUT_PYTHON=("$TOOLS"/klayout/pymod)
        export PYTHONPATH=$PYTHONPATH:${KLAYOUT_PYTHON[*]}
        
        echo "[INFO] Final PATH variable: $PATH"
        echo "[INFO] Final PYTHONPATH variable: $PYTHONPATH"
        export FOSS_PATH_SET=1
fi

# shellcheck disable=SC2086
LD_LIBRARY_PATH="$(realpath ${TOOLS}/klayout ):${TOOLS}/ngspice/lib" && export LD_LIBRARY_PATH
export XDG_RUNTIME_DIR=/tmp/runtime-default
export EDITOR='gedit'
export PYTHONPYCACHEPREFIX="/tmp/pycache"

# Setting default PDK
export PDK=sky130A
export PDKPATH=$PDK_ROOT/$PDK
export STD_CELL_LIBRARY=sky130_fd_sc_hd


# FIXME: this gets rid of a few libGL errors
# https://unix.stackexchange.com/questions/589236/libgl-error-no-matching-fbconfigs-or-visuals-found-glxgears-error-docker-cu
export LIBGL_ALWAYS_INDIRECT=1

# FIXME: this gets rid of the DBUS warning
# https://unix.stackexchange.com/questions/230238/x-applications-warn-couldnt-connect-to-accessibility-bus-on-stderr/230442#230442
export NO_AT_BRIDGE=1

if [ ! -d $XDG_RUNTIME_DIR ]; then
        mkdir -p $XDG_RUNTIME_DIR
        chmod 700 $XDG_RUNTIME_DIR
fi

# Add local directories in /headless to the path so that the user can upgrade PIP packages
export PATH=/headless/.local/bin:$PATH
export PYTHONPATH=/headless/.local/lib/python3.10/site-packages:$PYTHONPATH

#----------------------------------------
# Tool Aliases
#----------------------------------------

alias magic='magic -d X11 -rcfile $PDKPATH/libs.tech/magic/$PDK.magicrc'
alias mmagic='MAGTYPE=mag magic'
alias lmagic='MAGTYPE=maglef magic'

alias k='klayout -nn $PDKPATH/libs.tech/klayout/tech/$PDK.lyt'
alias ke='klayout -e -nn $PDKPATH/libs.tech/klayout/tech/$PDK.lyt'

alias xschem='xschem -b --rcfile $PDKPATH/libs.tech/xschem/xschemrc'
alias xschemtcl='\xschem --rcfile $PDKPATH/libs.tech/xschem/xschemrc'

#alias openlane='openlane --manual-pdk'
#FIXME WA for OpenLane2 until the ticket is merged into OpenROAD, see https://github.com/efabless/openlane2/issues/440
alias openlane='openlane --manual-pdk --skip Odb.CheckDesignAntennaProperties --skip Odb.CheckMacroAntennaProperties'

#FIXME Show hint that OpenLane(1) has been removed
alias flow.tcl='printf "[INFO] OpenLane(1) has been depreciated.\n[INFO] Please use OpenLane2 (start with <openlane>).\n"'

alias iic-pdk='source iic-pdk-script.sh'
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
# Adapt user prompt
#----------------------------------------

export PS1='\[\033[0;32m\]\w >\[\033[0;38m\] '

#----------------------------------------
# Source user configs from $DESIGNS
#----------------------------------------

if [ -f "$DESIGNS/.designinit" ]; then
        # shellcheck source=/dev/null
        source "$DESIGNS/.designinit"
fi
