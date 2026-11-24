#!/usr/bin/env bash
set -euo pipefail

# Idempotent post-install customizer for caelestia-kde on Arch/CachyOS + KDE Plasma.
# Never edits tracked upstream files in the repository: stages a temporary copy,
# applies custom/patches/*.patch there, optionally rebuilds the C++ QML plugin from
# the staged copy, and deploys patched files + system/user configs to live paths.
#
# Flags:
#   --check-patches   Stage upstream files, verify all custom/patches/*.patch apply
#                     cleanly, and exit without touching live system files.
#   --rebuild-plugin  Force rebuilding the patched C++ Caelestia QML plugin.

CHECK_ONLY=0
REBUILD_PLUGIN=0
for arg in "$@"; do
    case "$arg" in
        --check-patches) CHECK_ONLY=1 ;;
        --rebuild-plugin) REBUILD_PLUGIN=1 ;;
        -h|--help)
            sed -n '4,13p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$arg" >&2
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PATCH_DIR="$SCRIPT_DIR/patches"
QS_TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
PLASMA_SHELL_DIR="$HOME/.local/share/plasma/shells/caelestia.desktop"
SHELL_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/shell.json"
PLUGIN_STAMP="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/custom-plugin.sha256"
SUDO=()
[[ $EUID -ne 0 ]] && SUDO=(sudo)

log()  { printf '  [CUSTOM] %s\n' "$*"; }
warn() { printf '  [WARN]   %s\n' "$*" >&2; }
die()  { printf '  [ERR]    %s\n' "$*" >&2; exit 1; }

# 0. Stage a clean temporary copy of upstream files and apply all custom/patches/*.patch.
STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/caelestia-custom-stage.XXXXXX")"
trap 'rm -rf "$STAGE_DIR"' EXIT

shopt -s nullglob
PATCHES=("$PATCH_DIR"/*.patch)
shopt -u nullglob

if [[ ${#PATCHES[@]} -eq 0 ]]; then
    warn "No patches found in $PATCH_DIR"
else
    log "Staging clean upstream copy in $STAGE_DIR"
    mkdir -p "$STAGE_DIR/.github" "$STAGE_DIR/shell" "$STAGE_DIR/src/bin" "$STAGE_DIR/src/kde/shells"
    [[ -f "$REPO_ROOT/.github/version.env" ]] && cp -a "$REPO_ROOT/.github/version.env" "$STAGE_DIR/.github/version.env"

    # Copy shell/ excluding any local build directories so staging stays fast and clean.
    tar -C "$REPO_ROOT" \
        --exclude='shell/build' \
        --exclude='shell/kwin-effects/*/build' \
        --exclude='shell/assets/icons/yet-another-monochrome-icon-set' \
        -cf - shell | tar -C "$STAGE_DIR" -xf -
    [[ -d "$REPO_ROOT/src/bin" ]] && cp -a "$REPO_ROOT/src/bin/." "$STAGE_DIR/src/bin/"
    [[ -d "$REPO_ROOT/src/kde/shells/caelestia.desktop" ]] && \
        cp -a "$REPO_ROOT/src/kde/shells/caelestia.desktop" "$STAGE_DIR/src/kde/shells/"

    log "Applying ${#PATCHES[@]} patch(es) from $PATCH_DIR"
    for patch in "${PATCHES[@]}"; do
        if ! (cd "$STAGE_DIR" && git apply --check "$patch" 2>/dev/null); then
            die "Patch failed to apply cleanly against upstream checkout: $(basename "$patch")"
        fi
        (cd "$STAGE_DIR" && git apply "$patch")
    done
    log "All ${#PATCHES[@]} patch(es) applied cleanly."
fi

if [[ "$CHECK_ONLY" -eq 1 ]]; then
    log "Check complete (--check-patches); no live files modified."
    exit 0
fi

# Collect the unique set of live paths touched by custom/patches/*.patch.
mapfile -t PATCHED_FILES < <(python3 - "$PATCH_DIR" <<'PY'
import glob, os, sys

patch_dir = sys.argv[1]
paths = set()
for p in sorted(glob.glob(os.path.join(patch_dir, "*.patch"))):
    with open(p, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith("+++ b/"):
                paths.add(line[6:].strip())
for rel in sorted(paths):
    print(rel)
PY
)

# 1. Deploy patched QML/JS, Plasma lockscreen, and bin scripts from the staged copy.
HAS_PLUGIN_PATCH=0
PLUGIN_FILES=()

if [[ -d "$QS_TARGET" ]]; then
    log "Syncing patched shell QML/JS files to $QS_TARGET"
    for rel in "${PATCHED_FILES[@]}"; do
        case "$rel" in
            shell/plugin/*)
                HAS_PLUGIN_PATCH=1
                PLUGIN_FILES+=("$rel")
                ;;
            shell/*)
                src="$STAGE_DIR/$rel"
                dst="$QS_TARGET/${rel#shell/}"
                if [[ -f "$src" ]]; then
                    mode=644
                    [[ -x "$src" ]] && mode=755
                    install -Dm"$mode" "$src" "$dst"
                fi
                ;;
        esac
    done
else
    warn "$QS_TARGET not found; skipping live quickshell copy"
    for rel in "${PATCHED_FILES[@]}"; do
        if [[ "$rel" == shell/plugin/* ]]; then
            HAS_PLUGIN_PATCH=1
            PLUGIN_FILES+=("$rel")
        fi
    done
fi

if [[ -d "$PLASMA_SHELL_DIR" ]]; then
    deployed_lock=0
    for rel in "${PATCHED_FILES[@]}"; do
        if [[ "$rel" == src/kde/shells/caelestia.desktop/* && -f "$STAGE_DIR/$rel" ]]; then
            if [[ "$deployed_lock" -eq 0 ]]; then
                log "Syncing patched LockScreen QML files to $PLASMA_SHELL_DIR"
                deployed_lock=1
            fi
            install -Dm644 "$STAGE_DIR/$rel" "$PLASMA_SHELL_DIR/${rel#src/kde/shells/caelestia.desktop/}"
        fi
    done
fi

for rel in "${PATCHED_FILES[@]}"; do
    if [[ "$rel" == src/bin/* && -f "$STAGE_DIR/$rel" ]]; then
        bin_name="${rel#src/bin/}"
        log "Syncing patched $bin_name to $HOME/.local/bin/$bin_name"
        install -Dm755 "$STAGE_DIR/$rel" "$HOME/.local/bin/$bin_name"
    fi
done

# 1b. Rebuild the patched C++ Caelestia QML plugin in the temporary staging build dir
#     whenever plugin patches or Qt6 version change (or --rebuild-plugin is passed).
if [[ "$HAS_PLUGIN_PATCH" -eq 1 ]] && command -v cmake >/dev/null 2>&1; then
    qt_ver="$(pkg-config --modversion Qt6Core 2>/dev/null || echo unknown)"
    plugin_hash="$({
        printf 'qt:%s\n' "$qt_ver"
        for rel in "${PLUGIN_FILES[@]}"; do
            [[ -f "$STAGE_DIR/$rel" ]] && sha256sum "$STAGE_DIR/$rel" | awk -v r="$rel" '{print $1 " " r}'
        done
    } | sha256sum | awk '{print $1}')"

    need_plugin_build=0
    if [[ "$REBUILD_PLUGIN" -eq 1 ]]; then
        need_plugin_build=1
    elif [[ ! -d "$HOME/.local/lib/qt6/qml/Caelestia" ]]; then
        need_plugin_build=1
    elif [[ ! -f "$PLUGIN_STAMP" ]] || [[ "$(cat "$PLUGIN_STAMP" 2>/dev/null || true)" != "$plugin_hash" ]]; then
        need_plugin_build=1
    fi

    if [[ "$need_plugin_build" -eq 1 ]]; then
        log "Building patched C++ Caelestia QML plugin in temporary staging directory"
        if command -v ninja >/dev/null 2>&1; then
            CMAKE_GENERATOR="Ninja"
        else
            CMAKE_GENERATOR="Unix Makefiles"
        fi
        BUILD_JOBS=$(( $(nproc 2>/dev/null || echo 2) - 1 ))
        [[ $BUILD_JOBS -lt 1 ]] && BUILD_JOBS=1

        cmake -G "$CMAKE_GENERATOR" \
            -S "$STAGE_DIR/shell" \
            -B "$STAGE_DIR/build-plugin" \
            -DCMAKE_BUILD_TYPE=Release \
            -DENABLE_MODULES=plugin \
            -DCMAKE_INSTALL_PREFIX="$HOME/.local" \
            -DINSTALL_BINDIR="bin" \
            -DINSTALL_DATADIR="lib/caelestia" \
            -DINSTALL_QSCONFDIR="$QS_TARGET" \
            -DINSTALL_LIBDIR="lib/caelestia" \
            -DINSTALL_QMLDIR="lib/qt6/qml"
        cmake --build "$STAGE_DIR/build-plugin" -j"$BUILD_JOBS"
        cmake --install "$STAGE_DIR/build-plugin"

        mkdir -p "$(dirname "$PLUGIN_STAMP")"
        printf '%s\n' "$plugin_hash" > "$PLUGIN_STAMP"
        log "Patched C++ Caelestia QML plugin installed."
    else
        log "Patched C++ Caelestia QML plugin already up to date (pass --rebuild-plugin to force)."
    fi
fi

# Re-apply active KDE & Konsole colour scheme with contrast fixes if caelestia-color is present.
CAELESTIA_COLOR_BIN="$HOME/.local/bin/caelestia-color"
if [[ -x "$CAELESTIA_COLOR_BIN" && -f "${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/scheme.json" ]]; then
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

# 4. Disable inactive window transparency (opacityinactive=100) and hide KWin's
#    server-side titlebar on Nexus (which renders its own transparent glass header).
if command -v kwriteconfig6 >/dev/null 2>&1; then
    log "Setting inactive window opacity to 100 and frameless Nexus rule in kwinrulesrc"
    kwriteconfig6 --file kwinrulesrc --group caelestia-opacity --key opacityinactive 100
    kwriteconfig6 --file kwinrulesrc --group caelestia-opacity --key opacityinactiverule 2

    kwriteconfig6 --file kwinrulesrc --group caelestia-nexus-noborder --key Description "Caelestia: frameless Nexus settings window"
    kwriteconfig6 --file kwinrulesrc --group caelestia-nexus-noborder --key noborder true
    kwriteconfig6 --file kwinrulesrc --group caelestia-nexus-noborder --key noborderrule 2
    kwriteconfig6 --file kwinrulesrc --group caelestia-nexus-noborder --key wmclass quickshell
    kwriteconfig6 --file kwinrulesrc --group caelestia-nexus-noborder --key wmclassmatch 2
    kwriteconfig6 --file kwinrulesrc --group caelestia-nexus-noborder --key title "^(Appearance|Desktop & Tiling|Panels & Interface|Network & Connectivity|Display & Sound|Utilities & Tools|Applications & Shortcuts|System & Services|Nexus)$"
    kwriteconfig6 --file kwinrulesrc --group caelestia-nexus-noborder --key titlematch 3

    if command -v kreadconfig6 >/dev/null 2>&1; then
        kwin_order="$(kreadconfig6 --file kwinrulesrc --group General --key Order)"
        case ",$kwin_order," in
            *,caelestia-nexus-noborder,*) ;;
            *) kwriteconfig6 --file kwinrulesrc --group General --key Order "${kwin_order:+$kwin_order,}caelestia-nexus-noborder" ;;
        esac
    fi
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
