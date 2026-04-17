#!/usr/bin/env bash
# =============================================================================
# Hyprland Dotfiles Installer
# Installs dependencies and applies config for a new system
# =============================================================================

set -e

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
section() { echo -e "\n${BOLD}${CYAN}══ $* ══${NC}"; }

# ── Distro detection ──────────────────────────────────────────────────────────
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$ID"
        DISTRO_LIKE="${ID_LIKE:-}"
    else
        error "Cannot detect distro. /etc/os-release not found."
        exit 1
    fi

    case "$DISTRO" in
        arch|endeavouros|manjaro)   PKG_MANAGER="pacman" ;;
        fedora|rhel|centos)         PKG_MANAGER="dnf"    ;;
        ubuntu|debian|pop|linuxmint)PKG_MANAGER="apt"    ;;
        opensuse*|suse*)            PKG_MANAGER="zypper"  ;;
        *)
            if echo "$DISTRO_LIKE" | grep -q "arch";   then PKG_MANAGER="pacman"
            elif echo "$DISTRO_LIKE" | grep -q "fedora\|rhel"; then PKG_MANAGER="dnf"
            elif echo "$DISTRO_LIKE" | grep -q "debian\|ubuntu"; then PKG_MANAGER="apt"
            else
                error "Unsupported distro: $DISTRO"
                info  "Please install packages manually. See PACKAGES section in this script."
                exit 1
            fi ;;
    esac

    success "Detected: $DISTRO (using $PKG_MANAGER)"
}

# ── Package lists per manager ─────────────────────────────────────────────────
# Core packages needed by the config
PACKAGES_PACMAN=(
    hyprland waybar kitty wofi rofi
    swww brightnessctl polkit-gnome
    pipewire wireplumber
    ttf-font-awesome noto-fonts
    dolphin
)

PACKAGES_PACMAN_AUR=(
    glava spotify
)

PACKAGES_DNF=(
    hyprland waybar kitty wofi rofi
    brightnessctl polkit-gnome
    pipewire wireplumber
    fontawesome-fonts google-noto-fonts-common
    dolphin
)

PACKAGES_APT=(
    hyprland waybar kitty wofi rofi
    brightnessctl policykit-1-gnome
    pipewire wireplumber
    fonts-font-awesome fonts-noto
    dolphin
)

# ── Helpers ───────────────────────────────────────────────────────────────────
pkg_installed() { command -v "$1" &>/dev/null; }

install_pacman() {
    info "Installing packages with pacman..."
    sudo pacman -Syu --needed --noconfirm "${PACKAGES_PACMAN[@]}"

    # AUR packages via yay or paru
    local aur_helper=""
    if pkg_installed yay;  then aur_helper="yay"
    elif pkg_installed paru; then aur_helper="paru"
    else
        warn "No AUR helper found (yay/paru). Skipping AUR packages: ${PACKAGES_PACMAN_AUR[*]}"
        warn "Install one of these manually, then run: yay -S ${PACKAGES_PACMAN_AUR[*]}"
        return
    fi

    info "Installing AUR packages with $aur_helper..."
    "$aur_helper" -S --needed --noconfirm "${PACKAGES_PACMAN_AUR[@]}"
}

install_dnf() {
    info "Installing packages with dnf..."
    sudo dnf install -y "${PACKAGES_DNF[@]}"
    warn "glava and spotify are not in standard Fedora repos."
    warn "  glava:   https://github.com/jarcode-foss/glava"
    warn "  spotify: https://docs.fedoraproject.org/en-US/quick-docs/installing-spotify/"
}

install_apt() {
    info "Updating apt package lists..."
    sudo apt update
    info "Installing packages with apt..."
    sudo apt install -y "${PACKAGES_APT[@]}" || warn "Some packages may not be in repos — see notes below."
    warn "glava and spotify may need manual install on Debian/Ubuntu:"
    warn "  glava:   https://github.com/jarcode-foss/glava"
    warn "  spotify: https://www.spotify.com/download/linux/"
}

# ── Install packages ──────────────────────────────────────────────────────────
install_packages() {
    section "Installing packages"

    case "$PKG_MANAGER" in
        pacman) install_pacman ;;
        dnf)    install_dnf    ;;
        apt)    install_apt    ;;
        zypper)
            warn "zypper support is best-effort. Installing common packages..."
            sudo zypper install -y hyprland waybar kitty wofi rofi brightnessctl dolphin
            ;;
    esac
}

# ── Hyprland config ───────────────────────────────────────────────────────────
write_hypr_config() {
    section "Writing Hyprland config"

    local config_dir="$HOME/.config/hypr"
    mkdir -p "$config_dir"

    local config_file="$config_dir/hyprland.conf"

    # Back up existing config if present
    if [ -f "$config_file" ]; then
        local backup="${config_file}.bak.$(date +%Y%m%d_%H%M%S)"
        warn "Existing config found — backing up to $backup"
        cp "$config_file" "$backup"
    fi

    info "Writing $config_file ..."

    cat > "$config_file" << 'HYPRCONF'
################
### MONITORS ###
################

# Mirror mode: change 'eDP-1' to your internal monitor name
# Run 'hyprctl monitors' to list monitors
monitor=,preferred,auto,1, mirror, eDP-1


###################
### MY PROGRAMS ###
###################

$terminal    = kitty
$fileManager = dolphin
$menu        = wofi --show drun


#################
### AUTOSTART ###
#################

exec-once = waybar
exec-once = swww-daemon
exec-once = sleep 1 && swww restore
exec-once = sleep 1 && glava --desktop
exec-once = [workspace 2 silent] spotify
exec-once = sleep 1 && kitty --title yazi yazi
exec-once = sleep 1 && kitty --title btop btop
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1


#############################
### ENVIRONMENT VARIABLES ###
#############################

env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24


#####################
### LOOK AND FEEL ###
#####################

general {
    gaps_in  = 5
    gaps_out = 20
    border_size = 2
    col.active_border   = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    resize_on_border = false
    allow_tearing    = false
    layout = dwindle
}

decoration {
    rounding        = 10
    active_opacity  = 0.93
    inactive_opacity = 0.8
    blur {
        enabled = false
        size    = 0
        passes  = 1
        vibrancy = 0.6
    }
}

animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows,     1, 7, myBezier
    animation = windowsOut,  1, 7, default, popin 80%
    animation = border,      1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade,        1, 7, default
    animation = workspaces,  1, 6, default
}

dwindle {
    pseudotile     = true
    preserve_split = true
}

master {
    new_status = master
}

misc {
    force_default_wallpaper = 0
    disable_hyprland_logo   = true
}


#############
### INPUT ###
#############

input {
    kb_layout = us
    follow_mouse = 1
    sensitivity  = 0
    touchpad {
        natural_scroll = false
    }
}

device {
    name = epic-mouse-v1
    sensitivity = -0.5
}


###################
### KEYBINDINGS ###
###################

$mainMod = ALT

bind = $mainMod, Q, exec, $terminal
bind = $mainMod, C, killactive,
bind = $mainMod, M, fullscreen,
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, V, togglefloating,
bind = $mainMod, R, exec, $menu
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,

# Focus
bind = $mainMod, left,  movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up,    movefocus, u
bind = $mainMod, down,  movefocus, d

# Workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move to workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Scratchpad
bind = $mainMod,       S, togglespecialworkspace, magic
bind = $mainMod SHIFT, S, movetoworkspace, special:magic

# Mouse workspace scroll
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up,   workspace, e-1

# Mouse window management
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Audio
bind = , XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +5%
bind = , XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -5%

# Brightness
bind = , XF86MonBrightnessUp,   exec, brightnessctl set +10%
bind = , XF86MonBrightnessDown, exec, brightnessctl set 10%-

# Rofi
bind = $mainMod, tab, exec, rofi -show drun

# GLava toggle (update path if your scripts folder is elsewhere)
bind = $mainMod, g, exec, $HOME/Documents/scripts/toggle_glava.sh


##############################
### WINDOWS AND WORKSPACES ###
##############################

# btop
windowrulev2 = float,       class:^(kitty)$, title:^(btop)
windowrulev2 = size 858 776, class:^(kitty)$, title:^(btop)
windowrulev2 = move 1059 39, class:^(kitty)$, title:^(btop)

# yazi
windowrulev2 = float,        class:^(kitty)$, title:^(yazi)
windowrulev2 = size 600 900, class:^(kitty)$, title:^(yazi)
windowrulev2 = move 20 20,   class:^(kitty)$, title:^(yazi)

# GLava desktop layer
windowrulev2 = workspace 1,      class:^(GLava)$
windowrulev2 = float,            class:^(GLava)$
windowrulev2 = noblur,           class:^(GLava)$
windowrulev2 = nofocus,          class:^(GLava)$
windowrulev2 = noshadow,         class:^(GLava)$
windowrulev2 = noborder,         class:^(GLava)$
windowrulev2 = move 0 0,         class:^(GLava)$
windowrulev2 = size 100% 100%,   class:^(GLava)$
windowrulev2 = opacity 0.9,      class:^(GLava)$

# Generic kitty float
windowrulev2 = float,        class:^(kitty)$
windowrulev2 = size 600 400, class:^(kitty)$
HYPRCONF

    success "Hyprland config written to $config_file"
}

# ── GLava toggle script ───────────────────────────────────────────────────────
write_glava_script() {
    section "Setting up GLava toggle script"

    local scripts_dir="$HOME/Documents/scripts"
    mkdir -p "$scripts_dir"

    local script="$scripts_dir/toggle_glava.sh"

    if [ -f "$script" ]; then
        warn "GLava toggle script already exists, skipping."
        return
    fi

    cat > "$script" << 'GLAVA_SCRIPT'
#!/usr/bin/env bash
if pidof glava &>/dev/null; then
    killall glava
else
    glava --desktop &
fi
GLAVA_SCRIPT

    chmod +x "$script"
    success "GLava toggle script written to $script"
}

# ── Waybar placeholder ────────────────────────────────────────────────────────
check_waybar_config() {
    section "Checking Waybar config"
    local wb_dir="$HOME/.config/waybar"
    if [ -f "$wb_dir/config" ] || [ -f "$wb_dir/config.jsonc" ]; then
        success "Waybar config already present — leaving it alone."
    else
        warn "No Waybar config found at $wb_dir."
        warn "Waybar will use its defaults. Copy your waybar config there, or"
        warn "grab a starter from: https://github.com/Alexays/Waybar/wiki/Configuration"
    fi
}

# ── Summary ───────────────────────────────────────────────────────────────────
print_summary() {
    section "Post-install notes"

    echo -e "${BOLD}Things to check before launching Hyprland:${NC}"
    echo ""
    echo "  1. Monitor name: your config uses 'eDP-1' as the mirror source."
    echo "     Run: hyprctl monitors    (or wlr-randr)"
    echo "     Then update the 'monitor=' line in ~/.config/hypr/hyprland.conf"
    echo ""
    echo "  2. btop window rule uses 'move 1059 39' — this assumes a wide screen."
    echo "     Adjust the move/size windowrules if your resolution differs."
    echo ""
    echo "  3. GLava: make sure it's installed and 'glava --desktop' works before"
    echo "     relying on the toggle keybind (ALT+G)."
    echo ""
    echo "  4. Spotify: opened silently on workspace 2 at login."
    echo "     Make sure the 'spotify' command is in your PATH."
    echo ""
    echo "  5. polkit-gnome path: set to /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
    echo "     Verify this path exists on your system:"
    echo "     ls /usr/lib/polkit-gnome/"
    echo ""
    echo -e "${GREEN}Done! Log into Hyprland and enjoy. ${NC}"
}

# ── Entry point ───────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}${CYAN}"
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║   Hyprland Dotfiles Installer        ║"
    echo "  ╚══════════════════════════════════════╝"
    echo -e "${NC}"

    detect_distro

    read -rp "$(echo -e "${YELLOW}Install packages? (y/N): ${NC}")" ans_pkg
    [[ "$ans_pkg" =~ ^[Yy]$ ]] && install_packages || warn "Skipping package install."

    read -rp "$(echo -e "${YELLOW}Write Hyprland config? (y/N): ${NC}")" ans_cfg
    [[ "$ans_cfg" =~ ^[Yy]$ ]] && write_hypr_config || warn "Skipping Hyprland config."

    write_glava_script
    check_waybar_config
    print_summary
}

main "$@"
