#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# install.sh - Interactive installer for IIC-OSIC-TOOLS prerequisites
#
# Supports:
#   - Linux  (Debian / Ubuntu family, using APT)
#   - Linux  (RHEL / Fedora / Rocky / AlmaLinux / CentOS family, using DNF/YUM)
#   - macOS  (using Homebrew)
#
# The script installs:
#   * git
#   * Docker (Docker Engine on Linux / Docker Desktop on macOS)
#   * XQuartz (macOS only, required for X11 mode)
#   * Clones the iic-osic-tools repository to a user-chosen directory
#
# Before every step the user is asked for explicit permission. The script
# is designed to be safe (strict mode, no piping curl-to-shell, integrity
# checks where possible) and idempotent (re-running skips already-done
# steps).
# ---------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

# --------------------------- pretty printing -------------------------------
if [[ -t 1 ]]; then
    C_RED=$'\033[1;31m'; C_GRN=$'\033[1;32m'; C_YEL=$'\033[1;33m'
    C_BLU=$'\033[1;34m'; C_RST=$'\033[0m'
else
    C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_RST=""
fi
log()  { printf "%s[INFO]%s  %s\n" "$C_BLU" "$C_RST" "$*"; }
ok()   { printf "%s[ OK ]%s  %s\n" "$C_GRN" "$C_RST" "$*"; }
warn() { printf "%s[WARN]%s  %s\n" "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf "%s[FAIL]%s  %s\n" "$C_RED" "$C_RST" "$*" >&2; exit 1; }

trap 'die "Script aborted on line $LINENO (exit $?)."' ERR

# ----------------------- safety: refuse root ------------------------------
if [[ ${EUID} -eq 0 ]]; then
    die "Do NOT run this script as root. It will request sudo only when required."
fi

# ----------------------- user confirmation --------------------------------
ask() {
    # ask "Prompt message"  -> returns 0 on yes, 1 on no
    local prompt="$1" reply
    while true; do
        read -r -p "$(printf "%s[?]%s %s [y/N]: " "$C_YEL" "$C_RST" "$prompt")" reply || return 1
        case "${reply:-N}" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]|"")  return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

step() {
    # step "Title" "command-to-run-if-confirmed"
    local title="$1"; shift
    echo
    log "Step: $title"
    if ask "Proceed with this step?"; then
        "$@"
    else
        warn "Skipped: $title"
    fi
}

# ----------------------- OS detection -------------------------------------
detect_os() {
    case "$(uname -s)" in
        Linux)
            if [[ ! -r /etc/os-release ]]; then
                die "Cannot read /etc/os-release; unsupported Linux distribution."
            fi
            # shellcheck disable=SC1091
            . /etc/os-release
            case "${ID:-}${ID_LIKE:-}" in
                *debian*|*ubuntu*) OS="linux-apt" ;;
                *rhel*|*fedora*|*centos*|*rocky*|*almalinux*) OS="linux-dnf" ;;
                *) die "Unsupported Linux distribution: ${PRETTY_NAME:-unknown}. Only Debian/Ubuntu (APT) and RHEL/Fedora family (DNF/YUM) are supported." ;;
            esac
            ;;
        Darwin) OS="macos" ;;
        *) die "Unsupported operating system: $(uname -s)" ;;
    esac
    ok "Detected platform: $OS"
}

# ----------------------- helpers ------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

sudo_run() {
    # Run a command with sudo, prompting only if needed.
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo -p "[sudo] password for %u (needed to run: $*): " "$@"
    fi
}

# Select dnf if available, otherwise yum.
pick_dnf() {
    if have dnf; then echo dnf
    elif have yum; then echo yum
    else die "Neither 'dnf' nor 'yum' found."
    fi
}

# ----------------------- Linux (APT) steps --------------------------------
linux_apt_update() {
    sudo_run apt-get update
    ok "APT package lists updated."
}

linux_install_git() {
    if have git; then ok "git already installed ($(git --version))."; return; fi
    sudo_run apt-get install -y --no-install-recommends git ca-certificates curl gnupg
    ok "git installed."
}

linux_install_docker() {
    if have docker; then
        ok "Docker already installed ($(docker --version))."
    else
        log "Installing Docker Engine from the official Docker APT repository..."
        sudo_run install -m 0755 -d /etc/apt/keyrings
        local key_url key_tmp arch codename
        key_url="https://download.docker.com/linux/${ID}/gpg"
        key_tmp="$(mktemp)"
        curl -fsSL --proto '=https' --tlsv1.2 "$key_url" -o "$key_tmp" \
            || die "Failed to download Docker GPG key."
        sudo_run install -m 0644 "$key_tmp" /etc/apt/keyrings/docker.asc
        rm -f "$key_tmp"

        arch="$(dpkg --print-architecture)"
        codename="${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || true)}"
        [[ -n "$codename" ]] || die "Could not determine distribution codename."

        echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${codename} stable" \
            | sudo_run tee /etc/apt/sources.list.d/docker.list >/dev/null

        sudo_run apt-get update
        sudo_run apt-get install -y docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin
        ok "Docker Engine installed."
    fi

    # Post-install: add user to docker group (rootless docker usage)
    if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
        if ask "Add user '$USER' to the 'docker' group (recommended)? You must log out and back in afterwards."; then
            sudo_run groupadd -f docker
            sudo_run usermod -aG docker "$USER"
            warn "You need to log out and back in (or reboot) for the group change to take effect."
        fi
    else
        ok "User '$USER' is already in the 'docker' group."
    fi

    # Enable & start service
    if have systemctl; then
        sudo_run systemctl enable --now docker.service containerd.service || true
        ok "Docker service enabled & started."
    fi
}

# ----------------------- Linux (DNF/YUM) steps ----------------------------
linux_dnf_update() {
    local pm; pm="$(pick_dnf)"
    sudo_run "$pm" -y makecache
    ok "$pm metadata refreshed."
}

linux_dnf_install_git() {
    if have git; then ok "git already installed ($(git --version))."; return; fi
    local pm; pm="$(pick_dnf)"
    sudo_run "$pm" install -y git ca-certificates curl gnupg2
    ok "git installed."
}

linux_dnf_install_docker() {
    local pm; pm="$(pick_dnf)"
    if have docker; then
        ok "Docker already installed ($(docker --version))."
    else
        log "Installing Docker Engine from the official Docker repository..."
        # Map distro: Fedora uses /linux/fedora, RHEL-likes use /linux/centos
        local repo_distro repo_url
        case "${ID:-}" in
            fedora) repo_distro="fedora" ;;
            rhel|centos|rocky|almalinux|ol) repo_distro="centos" ;;
            *)
                case "${ID_LIKE:-}" in
                    *fedora*) repo_distro="fedora" ;;
                    *) repo_distro="centos" ;;
                esac
                ;;
        esac
        repo_url="https://download.docker.com/linux/${repo_distro}/docker-ce.repo"

        # Ensure config-manager plugin is available
        if [[ "$pm" == "dnf" ]]; then
            sudo_run dnf -y install dnf-plugins-core
            sudo_run dnf config-manager --add-repo "$repo_url" \
                || sudo_run dnf config-manager addrepo --from-repofile="$repo_url"
        else
            sudo_run yum -y install yum-utils
            sudo_run yum-config-manager --add-repo "$repo_url"
        fi

        sudo_run "$pm" install -y docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin
        ok "Docker Engine installed."
    fi

    # Post-install: add user to docker group
    if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
        if ask "Add user '$USER' to the 'docker' group (recommended)? You must log out and back in afterwards."; then
            sudo_run groupadd -f docker
            sudo_run usermod -aG docker "$USER"
            warn "You need to log out and back in (or reboot) for the group change to take effect."
        fi
    else
        ok "User '$USER' is already in the 'docker' group."
    fi

    if have systemctl; then
        sudo_run systemctl enable --now docker.service containerd.service || true
        ok "Docker service enabled & started."
    fi
}

# ----------------------- macOS (Homebrew) steps ---------------------------
macos_install_brew() {
    if have brew; then
        ok "Homebrew already installed ($(brew --version | head -n1))."
        return
    fi
    warn "Homebrew is not installed."
    cat <<'EOF'

Homebrew installation runs an official script from https://brew.sh.
For security, please review it yourself before continuing:

    https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh

EOF
    if ask "Download and execute the official Homebrew installer now?"; then
        /bin/bash -c "$(curl -fsSL --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Make brew available in current shell (Apple Silicon vs Intel paths)
        if [[ -x /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        have brew || die "Homebrew installation appears to have failed."
        ok "Homebrew installed."
    else
        die "Homebrew is required on macOS. Aborting."
    fi
}

macos_install_git() {
    if have git && [[ "$(command -v git)" != "/usr/bin/git" ]]; then
        ok "git already installed via Homebrew ($(git --version))."
        return
    fi
    # /usr/bin/git on macOS triggers the Command Line Tools installer; brew is preferred.
    brew install git
    ok "git installed via Homebrew."
}

macos_install_docker() {
    if [[ -d "/Applications/Docker.app" ]] || have docker; then
        ok "Docker Desktop already installed."
        return
    fi
    brew install --cask docker
    ok "Docker Desktop installed. Please launch it once from /Applications to finish setup."
}

macos_install_xquartz() {
    if [[ -d "/Applications/Utilities/XQuartz.app" ]] || brew list --cask xquartz >/dev/null 2>&1; then
        ok "XQuartz already installed."
        return
    fi
    brew install --cask xquartz
    ok "XQuartz installed. Remember to enable 'Allow connections from network clients' in its Preferences > Security."
}

# ----------------------- clone repository ---------------------------------
clone_repo() {
    local default_dir="$HOME/iic-osic-tools" target_dir parent_dir parent_abs
    read -r -p "$(printf "%s[?]%s Directory to clone iic-osic-tools into [%s]: " "$C_YEL" "$C_RST" "$default_dir")" target_dir
    target_dir="${target_dir:-$default_dir}"

    # Expand a leading tilde manually (we won't run with `set -f` off-shell quirks).
    target_dir="${target_dir/#\~/$HOME}"

    if [[ -z "$target_dir" ]]; then
        die "Empty target directory."
    fi

    # Canonicalize to an absolute path *before* validation, to prevent
    # traversal tricks like '..' from bypassing the dangerous-paths blocklist.
    parent_dir="$(dirname "$target_dir")"
    if [[ ! -d "$parent_dir" ]]; then
        die "Parent directory '$parent_dir' does not exist. Create it first or pick another path."
    fi
    parent_abs="$(cd "$parent_dir" && pwd -P)" \
        || die "Cannot resolve parent directory '$parent_dir'."
    target_dir="$parent_abs/$(basename "$target_dir")"

    # Refuse obviously dangerous targets (after canonicalization).
    case "$target_dir" in
        "/"|"$HOME"|\
        "/bin"|"/sbin"|"/boot"|"/dev"|"/proc"|"/sys"|\
        "/etc"|"/etc/"*|\
        "/usr"|"/usr/"*|\
        "/var"|"/var/"*|\
        "/lib"|"/lib/"*|"/lib64"|"/lib64/"*|\
        "/opt"|"/root"|\
        "/Library"|"/Library/"*|\
        "/System"|"/System/"*|\
        "/Applications"|"/Applications/"*)
            die "Refusing to clone into '$target_dir'." ;;
    esac

    # Parent must be writable by the current user (we refused root above).
    if [[ ! -w "$parent_abs" ]]; then
        die "No write permission for '$parent_abs'. Choose a path under your home directory."
    fi

    if [[ -e "$target_dir" ]]; then
        if [[ -d "$target_dir/.git" ]]; then
            ok "Repository already present at '$target_dir'."
            if ask "Run 'git pull' to update it?"; then
                git -C "$target_dir" pull --ff-only
            fi
            TARGET_DIR="$target_dir"
            return
        fi
        die "'$target_dir' exists and is not a git repository. Refusing to overwrite."
    fi

    git clone --depth=1 https://github.com/iic-jku/iic-osic-tools.git "$target_dir"
    ok "Cloned iic-osic-tools to '$target_dir'."
    TARGET_DIR="$target_dir"
}

# Try to find an existing iic-osic-tools checkout if the clone step was skipped.
find_existing_repo() {
    local candidates=(
        "$PWD"
        "$(dirname "${BASH_SOURCE[0]}")"
        "$HOME/iic-osic-tools"
        "$HOME/eda/iic-osic-tools"
    )
    local c abs
    for c in "${candidates[@]}"; do
        [[ -d "$c/.git" ]] || continue
        abs="$(cd "$c" && pwd)"
        if git -C "$abs" remote get-url origin 2>/dev/null | grep -qi 'iic-osic-tools'; then
            TARGET_DIR="$abs"
            return 0
        fi
    done
    return 1
}

# ----------------------- usage hints --------------------------------------
show_usage_hints() {
    if [[ -z "${TARGET_DIR:-}" ]]; then
        find_existing_repo || true
    fi
    local repo_dir="${TARGET_DIR:-<path-to-iic-osic-tools>}"
    echo
    echo "============================================================"
    echo " How to start IIC-OSIC-TOOLS"
    echo "============================================================"
    echo
    echo " 1) Change into the repository directory:"
    echo "      cd \"${repo_dir}\""
    echo
    echo " 2) Pick one of the launch modes (see README section 4):"
    echo
    echo "      ./start_vnc.sh      # Full XFCE desktop via browser"
    echo "                          #   open http://localhost  (password: abc123)"
    echo
    echo "      ./start_x.sh        # Local X11 forwarding (fast, integrated)"
    echo
    echo "      ./start_jupyter.sh  # Jupyter notebook server in the browser"
    echo
    echo "      ./start_shell.sh    # Shell-only access (advanced)"
    echo
    echo " 3) Your design files live under \$DESIGNS (default: \$HOME/eda/designs)"
    echo "    and are mounted into the container at /foss/designs."
    echo
    echo " The first launch will pull the ~4 GB image from Docker Hub."
    echo " Reserve at least 20 GB of free disk space."
    echo "============================================================"
    echo
}

# ----------------------- macOS reboot -------------------------------------
macos_reboot() {
    echo
    warn "macOS: a reboot is recommended to finalize Docker Desktop and XQuartz installation."
    if ask "Reboot now? (The system will restart in ~1 minute; press Ctrl-C in that window to abort.)"; then
        # Schedule reboot 1 minute out so the user can recover from an accidental 'y'.
        sudo_run shutdown -r +1 "Rebooting to finalize IIC-OSIC-TOOLS prerequisites." \
            || die "Failed to schedule reboot."
        warn "Reboot scheduled in 1 minute. Run 'sudo killall shutdown' to cancel."
    else
        warn "Please reboot manually before using iic-osic-tools."
    fi
}

# ============================== main =====================================
main() {
    echo "============================================================"
    echo " IIC-OSIC-TOOLS interactive prerequisites installer"
    echo "============================================================"
    detect_os

    if ! ask "This script will install required components interactively. Continue?"; then
        die "Aborted by user."
    fi

    case "$OS" in
        linux-apt)
            step "Update APT package lists"               linux_apt_update
            step "Install git and base utilities"         linux_install_git
            step "Install Docker Engine (official repo)"  linux_install_docker
            step "Clone iic-osic-tools repository"        clone_repo
            echo
            ok "All selected Linux steps completed."
            warn "If you were just added to the 'docker' group, log out and back in (or reboot) before using Docker."
            show_usage_hints
            ;;
        linux-dnf)
            step "Refresh DNF/YUM metadata"               linux_dnf_update
            step "Install git and base utilities"         linux_dnf_install_git
            step "Install Docker Engine (official repo)"  linux_dnf_install_docker
            step "Clone iic-osic-tools repository"        clone_repo
            echo
            ok "All selected Linux steps completed."
            warn "If you were just added to the 'docker' group, log out and back in (or reboot) before using Docker."
            show_usage_hints
            ;;
        macos)
            step "Install Homebrew"                       macos_install_brew
            step "Install git via Homebrew"               macos_install_git
            step "Install Docker Desktop via Homebrew"    macos_install_docker
            step "Install XQuartz via Homebrew"           macos_install_xquartz
            step "Clone iic-osic-tools repository"        clone_repo
            show_usage_hints
            step "Reboot macOS (recommended final step)"  macos_reboot
            ok "macOS installation steps completed."
            ;;
    esac
}

main "$@"
