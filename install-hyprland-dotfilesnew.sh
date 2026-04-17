#!/usr/bin/env bash
# =============================================================================
# Hyprland Dotfiles Installer — Full Setup
# Configs included: hyprland, kitty, rofi, glava (rc + bars), btop
# Target resolution: 2560x1440
# =============================================================================

set -e

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
        error "Cannot detect distro (/etc/os-release missing)."
        exit 1
    fi

    case "$DISTRO" in
        arch|endeavouros|manjaro)        PKG_MANAGER="pacman" ;;
        fedora|rhel|centos)              PKG_MANAGER="dnf"    ;;
        ubuntu|debian|pop|linuxmint)     PKG_MANAGER="apt"    ;;
        opensuse*|suse*)                 PKG_MANAGER="zypper" ;;
        *)
            if echo "$DISTRO_LIKE" | grep -q "arch";             then PKG_MANAGER="pacman"
            elif echo "$DISTRO_LIKE" | grep -q "fedora\|rhel";   then PKG_MANAGER="dnf"
            elif echo "$DISTRO_LIKE" | grep -q "debian\|ubuntu"; then PKG_MANAGER="apt"
            else error "Unsupported distro: $DISTRO"; exit 1; fi ;;
    esac
    success "Detected: $DISTRO (package manager: $PKG_MANAGER)"
}

# ── Package install ───────────────────────────────────────────────────────────
install_packages() {
    section "Installing packages"

    case "$PKG_MANAGER" in
        pacman)
            info "Syncing repos and installing core packages..."
            sudo pacman -Syu --needed --noconfirm \
                hyprland waybar kitty wofi rofi \
                swww brightnessctl polkit-gnome \
                pipewire wireplumber \
                btop yazi \
                ttf-font-awesome noto-fonts \
                dolphin

            local aur_helper=""
            if   command -v yay  &>/dev/null; then aur_helper="yay"
            elif command -v paru &>/dev/null; then aur_helper="paru"
            else
                warn "No AUR helper (yay/paru) found. Skipping AUR packages: glava spotify"
                warn "Install one, then run: yay -S glava spotify ttf-figtree"
                return
            fi
            info "Installing AUR packages with $aur_helper..."
            "$aur_helper" -S --needed --noconfirm glava spotify ttf-figtree
            ;;

        dnf)
            sudo dnf install -y \
                hyprland waybar kitty wofi rofi \
                brightnessctl polkit-gnome \
                pipewire wireplumber \
                btop \
                fontawesome-fonts google-noto-fonts-common \
                dolphin
            warn "Manual installs needed:"
            warn "  glava:   https://github.com/jarcode-foss/glava"
            warn "  spotify: https://docs.fedoraproject.org/en-US/quick-docs/installing-spotify/"
            warn "  yazi:    https://yazi-rs.github.io/docs/installation"
            warn "  Figtree font (for rofi): https://fonts.google.com/specimen/Figtree"
            ;;

        apt)
            sudo apt update
            sudo apt install -y \
                hyprland waybar kitty wofi rofi \
                brightnessctl policykit-1-gnome \
                pipewire wireplumber \
                btop \
                fonts-font-awesome fonts-noto \
                dolphin || warn "Some packages may not exist in your repos — check output above."
            warn "Manual installs needed:"
            warn "  glava:   https://github.com/jarcode-foss/glava"
            warn "  spotify: https://www.spotify.com/download/linux/"
            warn "  yazi:    https://yazi-rs.github.io/docs/installation"
            warn "  Figtree font (for rofi): https://fonts.google.com/specimen/Figtree"
            ;;

        zypper)
            warn "zypper: best-effort, some packages may be missing."
            sudo zypper install -y hyprland waybar kitty wofi rofi brightnessctl btop dolphin
            ;;
    esac
}

# ── Helper ────────────────────────────────────────────────────────────────────
backup_if_exists() {
    local f="$1"
    if [ -f "$f" ]; then
        local bak="${f}.bak.$(date +%Y%m%d_%H%M%S)"
        warn "Backing up $(basename "$f") → $bak"
        cp "$f" "$bak"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# CONFIG WRITERS
# ══════════════════════════════════════════════════════════════════════════════

write_hyprland_config() {
    section "Hyprland config"
    local dir="$HOME/.config/hypr"
    mkdir -p "$dir"
    backup_if_exists "$dir/hyprland.conf"

    cat > "$dir/hyprland.conf" << 'HYPREOF'
################
### MONITORS ###
################

# 2560x1440 primary monitor.
# Run 'hyprctl monitors' to find your monitor name and adjust.
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
    rounding         = 10
    active_opacity   = 0.93
    inactive_opacity = 0.8
    blur {
        enabled  = false
        size     = 0
        passes   = 1
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
    kb_layout    = us
    follow_mouse = 1
    sensitivity  = 0
    touchpad {
        natural_scroll = false
    }
}

device {
    name        = epic-mouse-v1
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

bind = $mainMod, left,  movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up,    movefocus, u
bind = $mainMod, down,  movefocus, d

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

bind = $mainMod,       S, togglespecialworkspace, magic
bind = $mainMod SHIFT, S, movetoworkspace, special:magic

bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up,   workspace, e-1

bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

bind = , XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +5%
bind = , XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -5%

bind = , XF86MonBrightnessUp,   exec, brightnessctl set +10%
bind = , XF86MonBrightnessDown, exec, brightnessctl set 10%-

bind = $mainMod, tab, exec, rofi -show drun

bind = $mainMod, g, exec, $HOME/Documents/scripts/toggle_glava.sh


##############################
### WINDOWS AND WORKSPACES ###
##############################

# btop — right side of 2560x1440
windowrulev2 = float,        class:^(kitty)$, title:^(btop)
windowrulev2 = size 858 776, class:^(kitty)$, title:^(btop)
windowrulev2 = move 1659 39, class:^(kitty)$, title:^(btop)

# yazi — tall, top-left
windowrulev2 = float,        class:^(kitty)$, title:^(yazi)
windowrulev2 = size 600 900, class:^(kitty)$, title:^(yazi)
windowrulev2 = move 20 20,   class:^(kitty)$, title:^(yazi)

# GLava — fullscreen desktop layer, workspace 1
windowrulev2 = workspace 1,    class:^(GLava)$
windowrulev2 = float,          class:^(GLava)$
windowrulev2 = noblur,         class:^(GLava)$
windowrulev2 = nofocus,        class:^(GLava)$
windowrulev2 = noshadow,       class:^(GLava)$
windowrulev2 = noborder,       class:^(GLava)$
windowrulev2 = move 0 0,       class:^(GLava)$
windowrulev2 = size 100% 100%, class:^(GLava)$
windowrulev2 = opacity 0.9,    class:^(GLava)$

# Generic kitty float fallback
windowrulev2 = float,        class:^(kitty)$
windowrulev2 = size 600 400, class:^(kitty)$
HYPREOF

    success "Hyprland config → $dir/hyprland.conf"
}

write_kitty_config() {
    section "Kitty config"
    local dir="$HOME/.config/kitty"
    mkdir -p "$dir"
    backup_if_exists "$dir/kitty.conf"

    cat > "$dir/kitty.conf" << 'KITTYEOF'
# ── Kitty config ──────────────────────────────────────────────────────────────
# Only active settings from original config; everything else uses kitty defaults.

# Background logo image.
# Copy your image to ~/Pictures/kittybkg.png after install.
window_logo_path    ~/Pictures/kittybkg.png
window_logo_alpha   0.05
window_logo_scale   100

# Window transparency (Hyprland adds its own layer via inactive_opacity)
background_opacity  0.8

# Uncomment to set a specific font (Nerd Font recommended for yazi/btop icons):
# font_family      JetBrainsMono Nerd Font
# font_size        12.0

shell_integration  enabled
KITTYEOF

    success "Kitty config → $dir/kitty.conf"
    warn "  Action needed: copy your image to ~/Pictures/kittybkg.png"
}

write_rofi_config() {
    section "Rofi config"
    local dir="$HOME/.config/rofi"
    mkdir -p "$dir"
    backup_if_exists "$dir/config.rasi"

    cat > "$dir/config.rasi" << 'ROFIEOF'
/* Rofi config — uses Figtree font (install from Google Fonts if missing) */

* {
    font: "Figtree 13";
    g-spacing: 10px;
    g-margin: 0;
    b-color: #000000FF;
    fg-color: #FFFFFFFF;
    fgp-color: #888888FF;
    b-radius: 8px;
    g-padding: 8px;
    hl-color: #FFFFFFFF;
    hlt-color: #000000FF;
    alt-color: #111111FF;
    wbg-color: #000000CC;
    w-border: 2px solid;
    w-border-color: #FFFFFFFF;
    w-padding: 12px;
}

configuration {
    modi: "drun";
    show-icons: true;
    display-drun: "";
}

listview {
    columns: 1;
    lines: 7;
    fixed-height: true;
    fixed-columns: true;
    cycle: false;
    scrollbar: false;
    border: 0px solid;
}

window {
    transparency: "real";
    width: 450px;
    border-radius: @b-radius;
    background-color: @wbg-color;
    padding: @w-padding;
}

prompt      { text-color: @fg-color; }

inputbar {
    children: ["prompt", "entry"];
    spacing: @g-spacing;
}

entry {
    placeholder: "Search Apps";
    text-color: @fg-color;
    placeholder-color: @fgp-color;
}

mainbox {
    spacing: @g-spacing;
    margin: @g-margin;
    padding: @g-padding;
    children: ["inputbar", "listview", "message"];
}

element {
    spacing: @g-spacing;
    margin: @g-margin;
    padding: @g-padding;
    border: 0px solid;
    border-radius: @b-radius;
    border-color: @b-color;
    background-color: transparent;
    text-color: @fg-color;
}

element normal.normal    { background-color: transparent; text-color: @fg-color; }
element alternate.normal { background-color: @alt-color;  text-color: @fg-color; }
element selected.active  { background-color: @hl-color;   text-color: @hlt-color; }
element selected.normal  { background-color: @hl-color;   text-color: @hlt-color; }

message { background-color: red; border: 0px solid; }
ROFIEOF

    success "Rofi config → $dir/config.rasi"
    warn "  Rofi uses Figtree font — install from https://fonts.google.com/specimen/Figtree"
    warn "  Then: cp Figtree*.ttf ~/.local/share/fonts/ && fc-cache -f"
}

write_glava_config() {
    section "GLava config"
    local dir="$HOME/.config/glava"
    mkdir -p "$dir"

    backup_if_exists "$dir/rc.glsl"
    cat > "$dir/rc.glsl" << 'RCEOF'
/* GLava main config — geometry set for 2560x1440 */

#request mod bars

#request setfloating  true
#request setdecorated true
#request setfocused   false
#request setmaximized true

/* Native compositor transparency */
#request setopacity "native"

#request setmirror false

#request setversion 3 3
#request setshaderversion 330

#request settitle "GLava"

/* Full width for 2560x1440 — adjust height to taste */
#request setgeometry 0 0 2560 600

#request setbg 00000000

#request setxwintype "normal"

#request setclickthrough true

#request setsource "auto"

#request setswap 1

#request setinterpolate true

/* Set to desired FPS cap, or 0 to uncap */
#request setframerate 0

#request setfullscreencheck false

#request setprintframes false

/* 1024 = good balance for 60Hz+ monitors with interpolation */
#request setsamplesize 1024

#request setbufsize 4096

#request setsamplerate 22050

#request setforcegeometry false
#request setforceraised false
#request setbufscale 1
RCEOF

    backup_if_exists "$dir/bars.glsl"
    cat > "$dir/bars.glsl" << 'BARSEOF'
/* GLava bars module */

#define C_LINE 1
#define BAR_WIDTH 4
#define BAR_GAP 2
#define BAR_OUTLINE #262626
#define BAR_OUTLINE_WIDTH 0
#define AMPLIFY 300
#define USE_ALPHA 0
#define GRADIENT_POWER 60
#define GRADIENT (d / GRADIENT_POWER + 1)
/* Orange-red gradient bar color */
#define COLOR (#e63f1e * GRADIENT)
#define DIRECTION 0
#define INVERT 0
#define FLIP 0
#define MIRROR_YX 0
BARSEOF

    success "GLava config → $dir/rc.glsl + bars.glsl"
}

write_btop_config() {
    section "btop config"
    local dir="$HOME/.config/btop"
    mkdir -p "$dir"
    backup_if_exists "$dir/btop.conf"

    cat > "$dir/btop.conf" << 'BTOPEOF'
#? Config file for btop v. 1.4.5

color_theme = "Default"
theme_background = True
truecolor = True
force_tty = False
presets = "cpu:1:default,proc:0:default cpu:0:default,mem:0:default,net:0:default cpu:0:block,net:0:tty"
vim_keys = False
rounded_corners = True
graph_symbol = "braille"
graph_symbol_cpu = "default"
graph_symbol_gpu = "default"
graph_symbol_mem = "default"
graph_symbol_net = "default"
graph_symbol_proc = "default"
shown_boxes = "cpu mem net proc"
update_ms = 2000
proc_sorting = "cpu lazy"
proc_reversed = False
proc_tree = False
proc_colors = True
proc_gradient = True
proc_per_core = False
proc_mem_bytes = True
BTOPEOF

    success "btop config → $dir/btop.conf"
}

write_glava_toggle() {
    section "GLava toggle script"
    local dir="$HOME/Documents/scripts"
    mkdir -p "$dir"

    if [ -f "$dir/toggle_glava.sh" ]; then
        warn "toggle_glava.sh already exists — skipping."
        return
    fi

    cat > "$dir/toggle_glava.sh" << 'TOGGLEEOF'
#!/usr/bin/env bash
if pidof glava &>/dev/null; then
    killall glava
else
    glava --desktop &
fi
TOGGLEEOF

    chmod +x "$dir/toggle_glava.sh"
    success "GLava toggle → $dir/toggle_glava.sh"
}

# ── Checks ────────────────────────────────────────────────────────────────────
check_wallpaper() {
    section "Wallpaper"
    mkdir -p "$HOME/Pictures"
    if [ -f "$HOME/Pictures/kittybkg.png" ]; then
        success "Found ~/Pictures/kittybkg.png"
    else
        warn "~/Pictures/kittybkg.png not found (used as kitty terminal background)."
        warn "  Copy your image: cp /path/to/image.png ~/Pictures/kittybkg.png"
        warn ""
        warn "  For the desktop wallpaper (swww), after logging into Hyprland:"
        warn "  swww img ~/Pictures/yourwallpaper.png"
        warn "  swww will restore it automatically on next login."
    fi
}

check_waybar() {
    section "Waybar"
    local dir="$HOME/.config/waybar"
    if [ -f "$dir/config" ] || [ -f "$dir/config.jsonc" ]; then
        success "Waybar config already present — leaving it alone."
    else
        warn "No waybar config at $dir — waybar will use its built-in defaults."
        warn "  System default is usually at: /etc/xdg/waybar/"
        warn "  Starter configs: https://github.com/Alexays/Waybar/wiki/Configuration"
    fi
}

check_polkit() {
    section "Polkit agent"
    local agent="/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
    if [ -f "$agent" ]; then
        success "polkit-gnome agent found at expected path."
    else
        warn "polkit-gnome agent not found at: $agent"
        warn "  Find it: find /usr -name 'polkit-gnome*' 2>/dev/null"
        warn "  Then update the exec-once line in ~/.config/hypr/hyprland.conf"
    fi
}

print_summary() {
    section "Done"
    echo ""
    echo -e "  ${BOLD}Config files written:${NC}"
    echo "    ~/.config/hypr/hyprland.conf"
    echo "    ~/.config/kitty/kitty.conf"
    echo "    ~/.config/rofi/config.rasi"
    echo "    ~/.config/glava/rc.glsl"
    echo "    ~/.config/glava/bars.glsl"
    echo "    ~/.config/btop/btop.conf"
    echo "    ~/Documents/scripts/toggle_glava.sh"
    echo ""
    echo -e "  ${BOLD}${YELLOW}Still needed from you:${NC}"
    echo "  1. Wallpaper images:"
    echo "       cp yourimage.png ~/Pictures/kittybkg.png   (kitty bg)"
    echo "       swww img ~/Pictures/wallpaper.png           (desktop, after first login)"
    echo ""
    echo "  2. Figtree font for rofi:"
    echo "       https://fonts.google.com/specimen/Figtree"
    echo "       cp Figtree*.ttf ~/.local/share/fonts/ && fc-cache -f"
    echo ""
    echo "  3. Confirm monitor name:"
    echo "       hyprctl monitors   →  update 'monitor=' in hyprland.conf if needed"
    echo ""
    echo "  4. Still missing configs (drop them in chat to add):"
    echo "       ~/.config/waybar/config + style.css"
    echo "       ~/.config/wofi/style.css"
    echo ""
    echo -e "  ${GREEN}${BOLD}Ready — log into Hyprland whenever you're set!${NC}"
}

# ══════════════════════════════════════════════════════════════════════════════
main() {
    echo -e "${BOLD}${CYAN}"
    echo "  ╔════════════════════════════════════════════╗"
    echo "  ║   Hyprland Dotfiles Installer  v2          ║"
    echo "  ║   Configs: hyprland, kitty, rofi,          ║"
    echo "  ║            glava, btop                     ║"
    echo "  ║   Target: 2560x1440                        ║"
    echo "  ╚════════════════════════════════════════════╝"
    echo -e "${NC}"

    detect_distro

    echo ""
    read -rp "$(echo -e "${YELLOW}Install packages? (y/N): ${NC}")" ans_pkg
    [[ "$ans_pkg" =~ ^[Yy]$ ]] && install_packages || warn "Skipping package install."

    echo ""
    read -rp "$(echo -e "${YELLOW}Write all config files? (y/N): ${NC}")" ans_cfg
    if [[ "$ans_cfg" =~ ^[Yy]$ ]]; then
        write_hyprland_config
        write_kitty_config
        write_rofi_config
        write_glava_config
        write_btop_config
        write_glava_toggle
    else
        warn "Skipping config files."
    fi

    check_wallpaper
    check_waybar
    check_polkit
    print_summary
}

main "$@"
