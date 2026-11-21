#!/usr/bin/env bash
set -euo pipefail

# Idempotent post-install customizer for caelestia-kde on Arch/CachyOS + KDE Plasma.
# Safe to run on top of either this fork or a stock upstream install.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
QS_TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
PLASMA_LOCKSCREEN_DIR="$HOME/.local/share/plasma/shells/caelestia.desktop/contents/lockscreen"
PLASMA_LOCKSCREEN="$PLASMA_LOCKSCREEN_DIR/LockScreenUi.qml"
SHELL_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/shell.json"
SUDO=()
[[ $EUID -ne 0 ]] && SUDO=(sudo)

log()  { printf '  [CUSTOM] %s\n' "$*"; }
warn() { printf '  [WARN]   %s\n' "$*" >&2; }

# 1. Sync patched QML/JS files into the live quickshell + Plasma lockscreen paths.
#    Works even if the user installed from upstream first and cloned this later.
if [[ -d "$QS_TARGET" ]]; then
    log "Syncing patched shell QML/JS files to $QS_TARGET"
    install -Dm644 "$REPO_ROOT/shell/components/controls/Menu.qml" \
        "$QS_TARGET/components/controls/Menu.qml"
    install -Dm644 "$REPO_ROOT/shell/components/controls/SessionConfirmPopup.qml" \
        "$QS_TARGET/components/controls/SessionConfirmPopup.qml"
    install -Dm644 "$REPO_ROOT/shell/components/controls/Tooltip.qml" \
        "$QS_TARGET/components/controls/Tooltip.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/utilities/DrawerConfirmModal.qml" \
        "$QS_TARGET/modules/utilities/DrawerConfirmModal.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/utilities/DrawerScrim.qml" \
        "$QS_TARGET/modules/utilities/DrawerScrim.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/utilities/cards/CaptureCard.qml" \
        "$QS_TARGET/modules/utilities/cards/CaptureCard.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/launcher/ContentList.qml" \
        "$QS_TARGET/modules/launcher/ContentList.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/launcher/Content.qml" \
        "$QS_TARGET/modules/launcher/Content.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/launcher/items/AppTile.qml" \
        "$QS_TARGET/modules/launcher/items/AppTile.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/launcher/items/CalcItem.qml" \
        "$QS_TARGET/modules/launcher/items/CalcItem.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/bar/BarWidgets.qml" \
        "$QS_TARGET/modules/bar/BarWidgets.qml"
    install -Dm755 "$REPO_ROOT/shell/modules/bar/BarWrapper.qml" \
        "$QS_TARGET/modules/bar/BarWrapper.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/bar/components/Dock.qml" \
        "$QS_TARGET/modules/bar/components/Dock.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/bar/popouts/BarComponentContext.qml" \
        "$QS_TARGET/modules/bar/popouts/BarComponentContext.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/bar/popouts/Greeter.qml" \
        "$QS_TARGET/modules/bar/popouts/Greeter.qml"
    install -Dm644 "$REPO_ROOT/shell/utils/Launch.qml" \
        "$QS_TARGET/utils/Launch.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/nexus/PageRowIndex.qml" \
        "$QS_TARGET/modules/nexus/PageRowIndex.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/nexus/pages/SessionPage.qml" \
        "$QS_TARGET/modules/nexus/pages/SessionPage.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/nexus/pages/UpdatesPage.qml" \
        "$QS_TARGET/modules/nexus/pages/UpdatesPage.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/nexus/pages/panels/DashboardPanel.qml" \
        "$QS_TARGET/modules/nexus/pages/panels/DashboardPanel.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/nexus/pages/panels/taskbar/BarDock.qml" \
        "$QS_TARGET/modules/nexus/pages/panels/taskbar/BarDock.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/session/Content.qml" \
        "$QS_TARGET/modules/session/Content.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/notifications/Notification.qml" \
        "$QS_TARGET/modules/notifications/Notification.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/sidebar/NotifActionList.qml" \
        "$QS_TARGET/modules/sidebar/NotifActionList.qml"
    install -Dm644 "$REPO_ROOT/shell/services/Brightness.qml" \
        "$QS_TARGET/services/Brightness.qml"
    install -Dm644 "$REPO_ROOT/shell/services/NotifData.qml" \
        "$QS_TARGET/services/NotifData.qml"
    install -Dm644 "$REPO_ROOT/shell/services/SessionOptions.qml" \
        "$QS_TARGET/services/SessionOptions.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/sidebar/AiAssistant.qml" \
        "$QS_TARGET/modules/sidebar/AiAssistant.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/sidebar/Content.qml" \
        "$QS_TARGET/modules/sidebar/Content.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/sidebar/ai/ClaudeCodeSession.qml" \
        "$QS_TARGET/modules/sidebar/ai/ClaudeCodeSession.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/sidebar/ai/antigravity.js" \
        "$QS_TARGET/modules/sidebar/ai/antigravity.js"
    install -Dm644 "$REPO_ROOT/shell/modules/sidebar/ai/chatsessions.js" \
        "$QS_TARGET/modules/sidebar/ai/chatsessions.js"
else
    warn "$QS_TARGET not found; skipping live quickshell copy"
fi

if [[ -d "$PLASMA_LOCKSCREEN_DIR" ]]; then
    log "Syncing patched LockScreen QML files to $PLASMA_LOCKSCREEN_DIR"
    install -Dm644 "$REPO_ROOT/src/kde/shells/caelestia.desktop/contents/lockscreen/LockScreenUi.qml" \
        "$PLASMA_LOCKSCREEN"
    install -Dm644 "$REPO_ROOT/src/kde/shells/caelestia.desktop/contents/lockscreen/components/NotifDock.qml" \
        "$PLASMA_LOCKSCREEN_DIR/components/NotifDock.qml"
fi

CAELESTIA_CHECK_UPDATES_BIN="$HOME/.local/bin/caelestia-check-updates"
if [[ -f "$REPO_ROOT/src/bin/caelestia-check-updates" ]]; then
    log "Syncing patched caelestia-check-updates to $CAELESTIA_CHECK_UPDATES_BIN"
    install -Dm755 "$REPO_ROOT/src/bin/caelestia-check-updates" "$CAELESTIA_CHECK_UPDATES_BIN"
fi

CAELESTIA_COLOR_BIN="$HOME/.local/bin/caelestia-color"
if [[ -f "$REPO_ROOT/src/bin/caelestia-color" ]]; then
    log "Syncing patched caelestia-color to $CAELESTIA_COLOR_BIN"
    install -Dm755 "$REPO_ROOT/src/bin/caelestia-color" "$CAELESTIA_COLOR_BIN"
    if [[ -f "${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/scheme.json" ]]; then
        scheme_name="$("$CAELESTIA_COLOR_BIN" scheme get -n 2>/dev/null || true)"
        scheme_flavour="$("$CAELESTIA_COLOR_BIN" scheme get -f 2>/dev/null || true)"
        scheme_mode="$("$CAELESTIA_COLOR_BIN" scheme get -m 2>/dev/null || true)"
        scheme_variant="$("$CAELESTIA_COLOR_BIN" scheme get -v 2>/dev/null || true)"
        if [[ -n "$scheme_name" ]]; then
            scheme_args=(-n "$scheme_name")
            [[ -n "$scheme_flavour" ]] && scheme_args+=(-f "$scheme_flavour")
            [[ -n "$scheme_mode" ]] && scheme_args+=(-m "$scheme_mode")
            [[ -n "$scheme_variant" ]] && scheme_args+=(-v "$scheme_variant")
            log "Re-applying active KDE & Konsole colour scheme ($scheme_name) with contrast fix"
            CAELESTIA_NO_DEFER=1 "$CAELESTIA_COLOR_BIN" scheme set "${scheme_args[@]}" >/dev/null 2>&1 || true
        fi
    fi
fi

# 2. Ensure kscreenlocker_greet and SDDM (which runs as user 'sddm' and cannot traverse
#    0700 ~/.local) can resolve Caelestia and M3Shapes QML modules under /usr/lib/qt6/qml.
for mod in Caelestia M3Shapes; do
    user_mod="$HOME/.local/lib/qt6/qml/$mod"
    sys_mod="/usr/lib/qt6/qml/$mod"
    if [[ -d "$user_mod" ]]; then
        log "Installing system-wide QML module copy $sys_mod"
        "${SUDO[@]}" rm -rf "$sys_mod"
        "${SUDO[@]}" cp -a "$user_mod" "$sys_mod"
        "${SUDO[@]}" chown -R root:root "$sys_mod"
        "${SUDO[@]}" chmod -R a+rX "$sys_mod"
    fi
done

# 3. Ensure kwin_workspace_tracker plugin is installed system-wide if built locally.
wt_build="$REPO_ROOT/shell/kwin-effects/workspace-tracker/build"
if [[ -d "$wt_build" && ! -f /usr/lib/qt6/plugins/kwin/effects/plugins/kwin_workspace_tracker.so ]]; then
    log "Installing kwin_workspace_tracker plugin (sudo required)"
    sudo cmake --install "$wt_build"
fi

# 4. Disable inactive window transparency (opacityinactive=100).
if command -v kwriteconfig6 >/dev/null 2>&1; then
    log "Setting inactive window opacity to 100 in kwinrulesrc"
    kwriteconfig6 --file kwinrulesrc --group caelestia-opacity --key opacityinactive 100
    kwriteconfig6 --file kwinrulesrc --group caelestia-opacity --key opacityinactiverule 2
fi

# 5. Terminal config: foot using bash instead of fish.
if [[ -f "$SCRIPT_DIR/configs/foot.ini" ]]; then
    log "Installing foot.ini (shell=bash)"
    install -Dm644 "$SCRIPT_DIR/configs/foot.ini" "${XDG_CONFIG_HOME:-$HOME/.config}/foot/foot.ini"
fi

# 6. Keybinds (Meta+W/Meta+Tab overview, Meta+Shift+S/Print screenshot) + KGlobalAccel sync.
if [[ -f "$SCRIPT_DIR/configs/keybinds.json" ]]; then
    log "Installing keybinds.json"
    install -Dm644 "$SCRIPT_DIR/configs/keybinds.json" "${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/keybinds.json"
fi

if command -v kwriteconfig6 >/dev/null 2>&1; then
    log "Syncing KGlobalAccel shortcuts (Overview & Screenshot)"
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Overview" "none,Meta+W,Toggle Overview"
    kwriteconfig6 --file kglobalshortcutsrc --group caelestia --key "caelestia-shortcut-overview" $'Meta+W\tMeta+Tab,none,Toggle overview'
    kwriteconfig6 --file kglobalshortcutsrc --group caelestia --key "caelestia-shortcut-screenshot" $'Print\tMeta+Shift+S,none,Toggle screenshot overlay'
fi

# 7. Deep-merge non-destructive preferences into ~/.config/caelestia/shell.json.
log "Merging shell.overrides.json into $SHELL_JSON"
python3 - "$SCRIPT_DIR/configs/shell.overrides.json" "$SHELL_JSON" <<'PY'
import json, os, sys

ovr_path, dst_path = sys.argv[1], sys.argv[2]
with open(ovr_path, "r", encoding="utf-8") as f:
    overrides = json.load(f)

data = {}
if os.path.exists(dst_path):
    with open(dst_path, "r", encoding="utf-8") as f:
        try:
            data = json.load(f)
        except Exception:
            data = {}

def deep_merge(base, upd):
    for k, v in upd.items():
        if isinstance(v, dict) and isinstance(base.get(k), dict):
            deep_merge(base[k], v)
        elif k == "hiddenApps" and isinstance(v, list) and isinstance(base.get(k), list):
            seen = set(base[k])
            base[k] = list(base[k]) + [x for x in v if x not in seen]
        else:
            base[k] = v

deep_merge(data, overrides)
os.makedirs(os.path.dirname(dst_path), exist_ok=True)
with open(dst_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4)
    f.write("\n")
PY

# 8. Set Helium as default browser and Konsole as default KDE terminal if installed.
if [[ -f /usr/share/applications/helium.desktop || -f "$HOME/.local/share/applications/helium.desktop" ]]; then
    if command -v xdg-settings >/dev/null 2>&1; then
        xdg-settings set default-web-browser helium.desktop || true
    fi
    if command -v xdg-mime >/dev/null 2>&1; then
        xdg-mime default helium.desktop text/html x-scheme-handler/http x-scheme-handler/https || true
    fi
fi
if command -v konsole >/dev/null 2>&1 && command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kdeglobals --group General --key TerminalApplication konsole
    kwriteconfig6 --file kdeglobals --group General --key TerminalService org.kde.konsole.desktop
fi
if [[ -f "$SCRIPT_DIR/configs/caelestia-nexus.desktop" ]]; then
    log "Installing Caelestia Settings (Nexus) launcher entry"
    install -Dm644 "$SCRIPT_DIR/configs/caelestia-nexus.desktop" \
        "${XDG_DATA_HOME:-$HOME/.local/share}/applications/caelestia-nexus.desktop"
    if [[ -f "$REPO_ROOT/assets/caelestia.svg" ]]; then
        install -Dm644 "$REPO_ROOT/assets/caelestia.svg" \
            "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps/caelestia-settings.svg"
    fi
fi

# 9. Cap systemd-logind pre-sleep delay lock wait + apply AMD AM5/ASRock wakeup fixes if present.
if [[ -f "$SCRIPT_DIR/configs/10-sleep-delay.conf" ]]; then
    log "Installing systemd-logind sleep delay drop-in (InhibitDelayMaxSec=2)"
    "${SUDO[@]}" install -Dm644 "$SCRIPT_DIR/configs/10-sleep-delay.conf" \
        /etc/systemd/logind.conf.d/10-sleep-delay.conf
fi

board_name="$(cat /sys/class/dmi/id/board_name 2>/dev/null || true)"
if [[ "$board_name" == "A620M-HDV/M.2+" ]] || grep -qE '^GP17[[:space:]]' /proc/acpi/wakeup 2>/dev/null; then
    log "Applying AMD AM5/ASRock USB & ACPI wakeup rules"
    "${SUDO[@]}" install -Dm644 "$SCRIPT_DIR/configs/90-disable-usb-wakeup.rules" \
        /etc/udev/rules.d/90-disable-usb-wakeup.rules
    "${SUDO[@]}" udevadm control --reload-rules
    "${SUDO[@]}" udevadm trigger --subsystem-match=usb --subsystem-match=pci || true

    "${SUDO[@]}" install -Dm644 "$SCRIPT_DIR/configs/disable-acpi-wakeup.service" \
        /etc/systemd/system/disable-acpi-wakeup.service
    "${SUDO[@]}" systemctl daemon-reload
    "${SUDO[@]}" systemctl enable --now disable-acpi-wakeup.service
fi

# 9b. Install Caelestia lockscreen-matched SDDM theme if SDDM is installed.
if [[ -d "$SCRIPT_DIR/sddm-theme" ]] && command -v sddm >/dev/null 2>&1; then
    sddm_theme_dir="/usr/share/sddm/themes/caelestia-lockscreen"
    log "Installing SDDM theme -> $sddm_theme_dir"
    "${SUDO[@]}" mkdir -p "$sddm_theme_dir"
    "${SUDO[@]}" cp -a "$SCRIPT_DIR/sddm-theme/." "$sddm_theme_dir/"

    wall_src=""
    if command -v kreadconfig6 >/dev/null 2>&1; then
        wall_cfg="$(kreadconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image 2>/dev/null || true)"
        wall_cfg="${wall_cfg#file://}"
        [[ -f "$wall_cfg" ]] && wall_src="$wall_cfg"
    fi
    if [[ -z "$wall_src" && -f "${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/wallpaper/current" ]]; then
        wall_src="$(readlink -f "${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/wallpaper/current" 2>/dev/null || true)"
    fi
    if [[ -n "$wall_src" && -f "$wall_src" ]]; then
        "${SUDO[@]}" install -Dm644 "$wall_src" "$sddm_theme_dir/assets/background"
    fi

    avatar_src=""
    for candidate in "$HOME/.face" "$HOME/.face.icon" "/var/lib/AccountsService/icons/$USER"; do
        if [[ -f "$candidate" ]]; then
            avatar_src="$candidate"
            break
        fi
    done
    if [[ -n "$avatar_src" ]]; then
        "${SUDO[@]}" install -Dm644 "$avatar_src" "$sddm_theme_dir/assets/avatar"
        "${SUDO[@]}" install -Dm644 "$avatar_src" "/usr/share/sddm/faces/$USER.face.icon"
    fi

    "${SUDO[@]}" chown -R root:root "$sddm_theme_dir"
    "${SUDO[@]}" chmod -R a+rX "$sddm_theme_dir"

    "${SUDO[@]}" mkdir -p /etc/sddm.conf.d
    "${SUDO[@]}" tee /etc/sddm.conf.d/zz-caelestia.conf >/dev/null <<'EOF'
[General]
GreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1

[Theme]
Current=caelestia-lockscreen
EOF
    "${SUDO[@]}" chmod 644 /etc/sddm.conf.d/zz-caelestia.conf

    if ! systemctl is-enabled --quiet sddm.service 2>/dev/null; then
        if systemctl is-enabled --quiet plasmalogin.service 2>/dev/null; then
            log "Switching display-manager service from plasmalogin to sddm (takes effect next reboot)"
            "${SUDO[@]}" systemctl disable plasmalogin.service || true
        fi
        "${SUDO[@]}" systemctl enable sddm.service
    fi
fi

# 10. Reload KWin and restart caelestia-shell if running inside a user session.
if command -v qdbus6 >/dev/null 2>&1; then
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    qdbus6 org.kde.kglobalaccel /kglobalaccel reloadConfig >/dev/null 2>&1 || true
fi
if systemctl --user is-active --quiet caelestia-shell.service 2>/dev/null; then
    log "Restarting caelestia-shell.service"
    systemctl --user restart caelestia-shell.service
fi

log "All custom overrides applied."
