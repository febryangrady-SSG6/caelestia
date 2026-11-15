#!/usr/bin/env bash
set -euo pipefail

# Idempotent post-install customizer for caelestia-kde on Arch/CachyOS + KDE Plasma.
# Safe to run on top of either this fork or a stock upstream install.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
QS_TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
PLASMA_LOCKSCREEN="$HOME/.local/share/plasma/shells/caelestia.desktop/contents/lockscreen/LockScreenUi.qml"
SHELL_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/shell.json"

log()  { printf '  [CUSTOM] %s\n' "$*"; }
warn() { printf '  [WARN]   %s\n' "$*" >&2; }

# 1. Sync patched QML/JS files into the live quickshell + Plasma lockscreen paths.
#    Works even if the user installed from upstream first and cloned this later.
if [[ -d "$QS_TARGET" ]]; then
    log "Syncing patched shell QML/JS files to $QS_TARGET"
    install -Dm644 "$REPO_ROOT/shell/modules/launcher/items/CalcItem.qml" \
        "$QS_TARGET/modules/launcher/items/CalcItem.qml"
    install -Dm644 "$REPO_ROOT/shell/modules/bar/popouts/Greeter.qml" \
        "$QS_TARGET/modules/bar/popouts/Greeter.qml"
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

if [[ -d "$(dirname "$PLASMA_LOCKSCREEN")" ]]; then
    log "Syncing patched LockScreenUi.qml to $PLASMA_LOCKSCREEN"
    install -Dm644 "$REPO_ROOT/src/kde/shells/caelestia.desktop/contents/lockscreen/LockScreenUi.qml" \
        "$PLASMA_LOCKSCREEN"
fi

CAELESTIA_COLOR_BIN="$HOME/.local/bin/caelestia-color"
if [[ -f "$REPO_ROOT/src/bin/caelestia-color" ]]; then
    log "Syncing patched caelestia-color to $CAELESTIA_COLOR_BIN"
    install -Dm755 "$REPO_ROOT/src/bin/caelestia-color" "$CAELESTIA_COLOR_BIN"
    if [[ -f "${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/scheme.json" ]]; then
        scheme_name="$("$CAELESTIA_COLOR_BIN" scheme get -n 2>/dev/null || true)"
        scheme_flavour="$("$CAELESTIA_COLOR_BIN" scheme get -f 2>/dev/null || true)"
        scheme_mode="$("$CAELESTIA_COLOR_BIN" scheme get -m 2>/dev/null || true)"
        if [[ -n "$scheme_name" && "$scheme_name" != "dynamic" ]]; then
            scheme_args=(-n "$scheme_name")
            [[ -n "$scheme_flavour" ]] && scheme_args+=(-f "$scheme_flavour")
            [[ -n "$scheme_mode" ]] && scheme_args+=(-m "$scheme_mode")
            log "Re-applying active KDE colour scheme ($scheme_name) with contrast fix"
            "$CAELESTIA_COLOR_BIN" scheme set "${scheme_args[@]}" >/dev/null 2>&1 || true
        fi
    fi
fi

# 2. Ensure kscreenlocker_greet (which ignores user QML2_IMPORT_PATH on some systems)
#    can resolve Caelestia and M3Shapes QML modules under /usr/lib/qt6/qml.
for mod in Caelestia M3Shapes; do
    user_mod="$HOME/.local/lib/qt6/qml/$mod"
    sys_mod="/usr/lib/qt6/qml/$mod"
    if [[ -d "$user_mod" && ! -e "$sys_mod" ]]; then
        log "Linking $sys_mod -> $user_mod (sudo required)"
        sudo ln -sfn "$user_mod" "$sys_mod"
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
        else:
            base[k] = v

deep_merge(data, overrides)
os.makedirs(os.path.dirname(dst_path), exist_ok=True)
with open(dst_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4)
    f.write("\n")
PY

# 8. Set Helium as default browser if installed.
if [[ -f /usr/share/applications/helium.desktop || -f "$HOME/.local/share/applications/helium.desktop" ]]; then
    if command -v xdg-settings >/dev/null 2>&1; then
        xdg-settings set default-web-browser helium.desktop || true
    fi
    if command -v xdg-mime >/dev/null 2>&1; then
        xdg-mime default helium.desktop text/html x-scheme-handler/http x-scheme-handler/https || true
    fi
fi

# 9. Reload KWin and restart caelestia-shell if running inside a user session.
if command -v qdbus6 >/dev/null 2>&1; then
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    qdbus6 org.kde.kglobalaccel /kglobalaccel reloadConfig >/dev/null 2>&1 || true
fi
if systemctl --user is-active --quiet caelestia-shell.service 2>/dev/null; then
    log "Restarting caelestia-shell.service"
    systemctl --user restart caelestia-shell.service
fi

log "All custom overrides applied."
