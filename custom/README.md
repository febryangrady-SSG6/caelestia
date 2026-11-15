# Personal `caelestia-kde` Fork & Reinstall Guide

This directory documents and automates every customization and fix applied on top of upstream [`ladybug-me/caelestia-kde`](https://github.com/ladybug-me/caelestia-kde) so that:
1. Reinstalling on a fresh Arch / CachyOS + KDE Plasma system is a single command sequence.
2. Any future AI agent or user can immediately see **what** was changed, **why**, and **where**.

---

## Quick Reinstall (Fresh OS)

### Option A — Install directly from this fork
```bash
git clone --recurse-submodules https://github.com/febryangrady-SSG6/caelestia.git ~/caelestia-kde
cd ~/caelestia-kde
bash install.sh
bash custom/apply.sh
```

### Option B — Apply onto an existing upstream `caelestia-kde` checkout
```bash
# Inside an upstream checkout:
git am /path/to/this/repo/custom/patches/*.patch
bash /path/to/this/repo/custom/apply.sh
```
Or, if you only want the live config + patched QML/JS files without building from source, clone this repo and run:
```bash
bash ~/caelestia-kde/custom/apply.sh
```

---

## Inventory of Code Patches (`custom/patches/`)

1. **`0001-fix-launcher-launch-qalc-directly-without-fish-wrapp.patch`**
   - **File:** `shell/modules/launcher/items/CalcItem.qml`
   - **Problem:** Clicking **Open in calculator** on `>calc` ran `fish -C "exec qalc -i ..."`, which failed/closed immediately when `fish` wasn't configured cleanly.
   - **Fix:** Launch `["...terminal", "qalc", "-i", root.math]` directly.

2. **`0002-fix-lockscreen-use-mediaActionSource-in-LockScreenUi.patch`**
   - **File:** `src/kde/shells/caelestia.desktop/contents/lockscreen/LockScreenUi.qml`
   - **Problem:** Lockscreen media controls (`previous`, `playPause`, `next`) called `root.actions` / `root.send(...)` instead of `mediaActionSource.actions` / `mediaActionSource.send(...)`, causing `TypeError` when clicking media buttons on the lockscreen.
   - **Fix:** Reference `mediaActionSource` inside `sendAction(action)`.

3. **`0003-fix-greeter-show-setup-hint-when-no-greeter-media-is.patch`**
   - **File:** `shell/modules/bar/popouts/Greeter.qml`
   - **Problem:** Clicking the bar greeter before any GIF/media paths were configured showed an empty black popout box.
   - **Fix:** Show a centered placeholder (`waving_hand` + instructions) when `!root.mediaPath`.

4. **`0004-feat-ai-add-Antigravity-agy-CLI-provider-to-sidebar-.patch`**
   - **Files:**
     - `shell/modules/sidebar/ai/antigravity.js` (new)
     - `shell/modules/sidebar/ai/ClaudeCodeSession.qml`
     - `shell/modules/sidebar/ai/chatsessions.js`
     - `shell/modules/sidebar/AiAssistant.qml`
     - `shell/modules/sidebar/Content.qml`
   - **Summary:** Adds **Antigravity** (`/usr/bin/agy`) as a first-class CLI AI provider in the sidebar AI Assistant alongside Ollama and Claude Code:
     - Auto-detects `agy` via `command -v agy` and discovers models asynchronously via `agy models` (handles both TTY space-padded and non-TTY tab-separated output).
     - Caches model list, selected model, and effort level via `QtCore.Settings` (`[AntigravityAI]` in `~/.config/Caelestia/caelestia-shell.conf`) without requiring changes to compiled C++ `GlobalConfig.ai`.
     - Streams responses (`agy -p ... --output-format stream-json`), tool cards, token counts, usage summaries, auto-titles (`--output-format json --model gemini-3.8-flash-low`), prompt suggestions, attachments (`--add-dir`), CWD selector, permission selector (excluding unsupported `--mode auto`), multi-turn resume (`--conversation <id>`), and terminal handoff (`agy --conversation <id>`).

5. **`0005-fix-colors-repair-KDE-Selection-and-Complementary-co.patch`**
   - **File:** `src/bin/caelestia-color`
   - **Problem:** The vendored `Matugen.colors` KDE color template maps `[Colors:Selection]` `ForegroundNormal` / `ForegroundLink` to `secondary_fixed` and `ForegroundInactive` to `on_surface_variant` on `BackgroundNormal = primary` (1.31:1 contrast in `gruvbox/soft/dark`), and maps `[Colors:Complementary]` `ForegroundNormal` to `on_primary_container` on `surface` (1.09:1 contrast). Existing `cmd_kde_selection` returned early whenever `name != "dynamic"`, leaving named schemes unpatched.
   - **Fix:** Added `contrast_ratio()` and updated `cmd_kde_selection` in `src/bin/caelestia-color` to run for **all** schemes (dynamic and named), setting `[Colors:Selection]` `ForegroundNormal` to `#000000`/`#ffffff` against `primary`, repairing `ForegroundLink` and `ForegroundInactive` (`#262626`/`#d9d9d9`) when contrast `< 4.5:1`, and repairing `[Colors:Complementary]` `ForegroundNormal` (`onSurface` when `>= 4.5:1`, otherwise `#000000`/`#ffffff`) when contrast `< 4.5:1`.

6. **`0006-fix-menu-avoid-QtQuick.Controls.Menu-shadowing-and-c.patch`**
   - **File:** `shell/components/controls/Menu.qml`
   - **Problem:** `Menu.qml` had an unqualified `import QtQuick.Controls`, so `QtQuick.Controls.Menu` (`Right=5`, `Top=1`, `Bottom=7`) shadowed `Menu.qml`'s own `enum Side` (`Top=0, Bottom=1, Left=2, Right=3`) in the root `attachSideX`/`thisSideX` defaults (`5`), while child expressions/callers (`SplitButton.qml`) used `Side.Right` (`3`). Because `5 !== 3`, `thisSideX === Menu.Right` evaluated `false`, skipping `off -= width` and opening `SplitButton` dropdown menus (like Utilities Screen Capture) off the right edge of the button/screen.
   - **Fix:** Aliased `import QtQuick.Controls as Controls` (`Controls.ScrollBar.vertical`) so `Menu` enum values resolve consistently, used `menu.width` / `menu.height` explicitly, and clamped `menu.x` within `[0, root.parent.width - menu.implicitWidth]`.

7. **`0007-fix-menu-auto-close-when-anchor-or-utilities-drawer-.patch`**
   - **Files:** `shell/components/controls/Menu.qml`, `shell/modules/utilities/cards/CaptureCard.qml`
   - **Problem:** Because `Menu` reparents itself onto `Interactions` so it isn't clipped by parent containers, closing the `Utilities` drawer on unhover (or hiding any anchor/parent container) left an open `SplitButton` context menu floating over the screen.
   - **Fix:** Added an `attachTo.onVisibleChanged` / `onExpandedChanged` visibility guard in `Menu.qml` to close immediately when `attachTo` hides, and collapsed `recordSplitBtn.expanded` / `shotSplitBtn.expanded` immediately on `!visibilities.utilities` in `CaptureCard.qml`.

8. **`0008-fix-tooltip-walk-to-window-root-item-instead-of-stop.patch`**
   - **File:** `shell/components/controls/Tooltip.qml`
   - **Problem:** `Tooltip`'s `parent` binding checked `parentItem.anchors.fill !== undefined`, which is `true` for every QML `Item` (`anchors.fill` defaults to `null`, not `undefined`). That caused `parent` to stop at `target.parent` (such as the `46px`-tall `Row` in `RegionSelection.qml`), clamping tooltips like `Full Screen Screenshot` and `Close` directly on top of the hovered button where the `Popup` stole hover, closed, restored hover, and flickered continuously.
   - **Fix:** Walk up to the topmost ancestor item (`while (p && p.parent) p = p.parent`), guard `clamp` upper bounds with `Math.max(padding, ...)`, compute initial position synchronously alongside `Qt.callLater`, and hide the tooltip if `target.visible` becomes `false`.

9. **`0009-fix-bar-left-align-labels-in-BarComponentContext-pop.patch`**
   - **File:** `shell/modules/bar/popouts/BarComponentContext.qml`
   - **Problem:** `RowLayout` inside `ActionRow` stretched to the wider row without any child setting `Layout.fillWidth: true`, causing Qt `RowLayout` to expand the spacing between the `settings` icon and shorter labels like `Dock settings` instead of left-aligning them with `Elements & Modules`.
   - **Fix:** Added `Layout.fillWidth: true` on `StyledText` inside `ActionRow`.

10. **`0010-fix-launcher-add-vertical-padding-and-align-selectio.patch`**
   - **File:** `shell/modules/launcher/items/AppTile.qml`
   - **Problem:** `AppTile`'s selection highlight `StyledRect` had `anchors.margins: Tokens.spacing.extraSmall` (`4px` inset) while `tileArea` (`StateLayer`) filled the whole tile (`0px` inset), and `baseIconSize` + `content.y` consumed the full `92px` tile height with zero bottom padding, causing two-line app labels (e.g., `Helium Browser`) to touch/overlap the bottom border of the selection box.
   - **Fix:** Unified `StyledRect` with `tileArea` at `anchors.fill: parent` and added balanced vertical padding (`_verticalPadding` top/bottom) with centered `content.y` so multi-line labels stay cleanly padded inside the highlight box.

11. **`0011-feat-dashboard-add-Media-GIF-selector-to-DashboardPa.patch`**
   - **Files:** `shell/modules/nexus/pages/panels/DashboardPanel.qml`, `shell/modules/nexus/PageDictionary.qml`
   - **Summary:** Adds a **Media GIF** preset selector (`Kuru Kuru`, `Bongo Cat`, `Dino`) via `SelectRow` and a **Custom media GIF** file picker (`FileDialog` for GIF/image files) via `NavRow` to Nexus Dashboard settings (`GlobalConfig.paths.mediaGif` + `GlobalConfig.save()`), indexed under `Media GIF` in `PageDictionary.qml`.

12. **`0012-fix-launcher-prevent-ContentList-opacity-from-gettin.patch`**
   - **File:** `shell/modules/launcher/ContentList.qml`
   - **Problem:** `ContentList`'s `Behavior on state` gated `enabled` on `&& root.opacity === 1`. As soon as the state transition fade-out reduced `opacity` below `1`, `enabled` flipped to `false`, so closing the launcher or switching modes (e.g., `Alt+Tab` `windowSwitcher`, `>wallpaper `, etc.) while mid-fade aborted the `SequentialAnimation` cleanly before the `to: 1` fade-in ran—leaving `ContentList` permanently dimmed (`opacity < 1`) until Quickshell restarted.
   - **Fix:** Removed `root.opacity === 1` from `Behavior on state`'s `enabled` condition, dropped the hardcoded `from: 1` on fade-out, and guaranteed `root.opacity = 1` whenever `stateTransitionAnim` stops (`onRunningChanged`), `state` changes with the behavior disabled (`onStateChanged`), or the launcher opens (`onLauncherChanged`).

13. **`0013-fix-utilities-import-qs.services-for-DrawerConfirmMo.patch`**
   - **File:** `shell/modules/utilities/DrawerConfirmModal.qml`
   - **Problem:** `DrawerConfirmModal.qml` referenced `Colours.palette.m3onSurfaceVariant` for the confirmation dialog body text without importing `qs.services`, causing `Colours` to fail lookup and fall back to `#000000` black text on dark surfaces (e.g. `Delete recording?`).
   - **Fix:** Added `import qs.services`.

14. **`0014-feat-launcher-confirm-Log-Out-Restart-and-Shut-Down-.patch`**
   - **File:** `shell/modules/launcher/Content.qml`
   - **Summary:** Adds a modal confirmation dialog (`sessionConfirmPopup` via `requestSessionConfirmation`) when clicking **Log Out**, **Restart**, or **Shut Down** in the Launcher power menu footer (leaving **Sleep** immediate), with destructive error styling for **Shut Down** and automatic dismissal when the launcher closes.

15. **`0015-feat-launcher-animate-session-confirmation-popup-ent.patch`**
   - **File:** `shell/modules/launcher/Content.qml`
   - **Summary:** Adds Material 3 `Elevation` plus opacity/scale `enter` (`0.88 -> 1`) and `exit` (`1 -> 0.92`) `Transition`s on `sessionConfirmPopup` so it pops in and dismisses smoothly.

16. **`0016-feat-session-add-Sleep-action-confirmations-hibernat.patch`**
   - **Files:** `shell/services/SessionOptions.qml` (new), `shell/modules/session/Content.qml`, `shell/modules/nexus/pages/SessionPage.qml`, `shell/modules/nexus/PageDictionary.qml`
   - **Summary:**
     - Adds a **Sleep** button (`["suspend"]`, immediate) to the Ctrl+Alt+Del session menu (`modules/session/Content.qml`).
     - Adds an animated modal confirmation popup (`sessionConfirmPopup` with `Elevation` and scale/fade `enter`/`exit` transitions on `Overlay.overlay`) for **Log out**, **Shut down**, **Hibernate**, and **Restart**.
     - Replaces the duplicate `caelestiaMode` dino images with `Config.paths.sessionGif || "root:/assets/dino.gif"` (keeping monochrome `Colouriser` only for `dino.gif`).
     - Adds `SessionOptions` (`QtCore.Settings` `[Session].showHibernate`) and controls in Nexus **Session** (`SessionPage.qml`) to toggle **Show hibernate** and select **Session GIF** (`Dino`, `Kuru Kuru`, `Bongo Cat`, or custom GIF via `FileDialog`).

17. **`0017-fix-lockscreen-route-image-icon-through-Kirigami.Ico.patch`**
   - **File:** `src/kde/shells/caelestia.desktop/contents/lockscreen/components/NotifDock.qml`
   - **Problem:** `resolveImageUrl` stripped `image://icon/` from notification icons (e.g. `image://icon/system-software-update`), passing a bare icon name into QML `Image { source: ... }` which failed trying to open `file:///.../lockscreen/components/system-software-update`.
   - **Fix:** Return `""` from `resolveImageUrl` for `image://icon/` and scheme-less non-path strings, and add `resolveImageIcon` so `Kirigami.Icon` renders the themed icon fallback cleanly.

18. **`0018-feat-lockscreen-use-standard-neutral-grey-color-sche.patch`**
   - **File:** `src/kde/shells/caelestia.desktop/contents/lockscreen/LockScreenUi.qml`
   - **Summary:** Adds `standardGrey` (default `true`) and `applySchemeData` helper, keeping the active lockscreen wallpaper intact while switching the lockscreen palette defaults (`clSurface`, `clSurfaceFg`, `clSurfaceContainer`, `clPrimary`, `clTerms`, etc.) to standard neutral grey unless `lock.standardGrey` is explicitly set to `false` in `shell.json`.

19. **`0019-fix-launch-pass-e-when-executing-commands-in-konsole.patch`**
   - **Files:** `shell/utils/Launch.qml`, `shell/modules/launcher/items/CalcItem.qml`, `shell/modules/nexus/pages/UpdatesPage.qml`
   - **Summary:** Adds `Launch.terminalExecPrefix(baseTerminal)` and routes `terminalCommand`, `CalcItem` (`qalc`), and `UpdatesPage` through it so Konsole receives `-e` before inline commands while bare terminal launches (`Meta+Return`, desktop context menu) run `["konsole"]` cleanly.

20. **`0020-fix-color-ensure-Konsole-and-terminal-OSC-ANSI-color.patch`**
   - **File:** `src/bin/caelestia-color`
   - **Problem:** `cmd_konsole_scheme` and `terminal-sequences` mapped ANSI slots 6, 10, 12, and 13 to `onPrimaryContainer` / `onTertiaryContainer`, which invert to `#000000` on light containers in `dynamic` dark schemes (rendering numbers in `qalc` invisible black on dark `#131313` backgrounds).
   - **Fix:** Adds `resolve_terminal_palette(colours)` using WCAG `contrast_ratio` (>= 4.5 for colors 1–7, 9–15; >= 3.0 for dim black 8) with fallbacks to `term0..term15` / `primary` / `secondary` / `tertiary` / `onSurface`, and applies it in both `cmd_konsole_scheme` and `cmd_terminal_sequences`.

21. **`0021-fix-dock-increase-dock-icon-ratio-to-match-Windows-t.patch`**
   - **Files:** `shell/modules/bar/components/Dock.qml`, `shell/modules/nexus/pages/panels/taskbar/BarDock.qml`
   - **Problem:** Even with `bar.dock.iconSize` set to `40`, `Dock.qml` scaled icons down to `0.7` (`28px`) with `12px` spacing inside the `40px` bar pill, making dock icons look overly small compared to Windows taskbar icons, while `BarDock.qml` capped the slider maximum at unscaled `innerWidth` (`40`).
   - **Fix:** Increases `iconSize` in `Dock.qml` to `Math.max(16, Math.min(configuredItemSize - 4, Math.round(configuredItemSize * 0.88 / 2) * 2))` (`36px` in a `40px` pill), tightens icon spacing to `Tokens.spacing.small` (`8px`), shifts active horizontal dock icons up by `-1px` for running-dot clearance, and scales the `BarDock.qml` slider `to:` bound with `Config.bar.scale`.

22. **`0022-fix-dock-uncap-icon-size-above-40-and-add-highlight-.patch`**
   - **Files:** `shell/modules/bar/BarWidgets.qml`, `shell/modules/bar/BarWrapper.qml`, `shell/modules/bar/components/Dock.qml`, `shell/modules/nexus/pages/panels/taskbar/BarDock.qml`
   - **Problem:** Dock icons were still hard-clamped by the `40px` bar thickness (`Tokens.sizes.bar.innerWidth`) and `BarDock.qml` slider `to:` cap, and using `36px` icons inside a `40x40` highlight box inside a `40px` pill left only `2px` margin around icons and `0px` margin inside the pill.
   - **Fix:** Moves dock geometry helpers into `BarWidgets.qml`, treats `bar.dock.iconSize` directly as the icon size, adds proportional highlight tile padding (`Math.max(6, Math.round(iconSize * 0.16))` per side, `-2px` active icon offset, `2px` bottom dot inset), adds cross-axis padding (`Tokens.padding.extraSmall`) inside the dock pill, expands `BarWrapper.contentWidth` automatically when the dock is taller than `baseInnerThickness`, and opens the `BarDock.qml` slider range to `20..64` (default override `48`).

---

## Inventory of System & Config Overrides (`custom/apply.sh`)

| Area | What `custom/apply.sh` configures | Reason |
| :--- | :--- | :--- |
| **KDE & Konsole contrast** | Syncs patched `src/bin/caelestia-color` to `~/.local/bin/caelestia-color` and re-applies active scheme (with `CAELESTIA_NO_DEFER=1`) | Ensures `[Colors:Selection]` / `[Colors:Complementary]` and Konsole / OSC ANSI terminal contrast fixes apply to both dynamic and named schemes. |
| **Lockscreen & SDDM QML modules** | Installs world-readable system copies of `/usr/lib/qt6/qml/Caelestia` and `/usr/lib/qt6/qml/M3Shapes` from `~/.local/lib/qt6/qml/...` | Both `kscreenlocker_greet` and user `sddm` (which cannot traverse `0700` `~/.local`) resolve `Caelestia` and `M3Shapes` cleanly without a black screen. |
| **KWin workspace tracker** | Installs `kwin_workspace_tracker.so` to `/usr/lib/qt6/plugins/kwin/effects/plugins/` if built | Ensures KWin loads the workspace tracker effect cleanly. |
| **Inactive window opacity** | Sets `kwinrulesrc` `[caelestia-opacity] opacityinactive=100`, `opacityinactiverule=2` | Keeps non-focused windows opaque instead of semi-transparent. |
| **Terminal (`foot`)** | Installs `custom/configs/foot.ini` (`shell=bash`) | Prevents desktop **Open Terminal** / `foot` from failing on unconfigured `fish`. |
| **Keybinds** | Installs `custom/configs/keybinds.json` + updates `kglobalshortcutsrc` | `Meta+W` / `Meta+Tab` for Caelestia Overview (unbinding KDE's conflicting `Meta+W` Overview), `Print` + `Meta+Shift+S` for Screenshot. |
| **`shell.json` defaults** | Deep-merges `custom/configs/shell.overrides.json` into `~/.config/caelestia/shell.json` | Sets `ai.defaultProvider = "antigravity"`, default browser `helium-browser`, default terminal `konsole`, `bar.dock.iconSize = 48`, `launcher.hiddenApps` (`foot`, `footclient`, `foot-server`, `systemsettings`), dashboard media GIF (`kurukuru.gif`), and bar greeter GIFs (`bongocat.gif` / `kurukuru.gif`) without clobbering chat history. |
| **Default apps & Nexus launcher** | Sets `helium.desktop` via `xdg-settings` / `xdg-mime`, `TerminalApplication=konsole` / `TerminalService=org.kde.konsole.desktop` in `kdeglobals`, and installs `custom/configs/caelestia-nexus.desktop` + `caelestia-settings.svg` | Uses Helium Browser and Konsole as defaults, hides the duplicate `System Settings` entry (`systemsettings`) so only `KDE System Settings` appears, and adds a `Caelestia Settings` (Nexus) app entry under Settings. |
| **Sleep delay & AMD AM5 wakeup** | Installs `custom/configs/10-sleep-delay.conf` -> `/etc/systemd/logind.conf.d/10-sleep-delay.conf` (`InhibitDelayMaxSec=2`) and, on `A620M-HDV/M.2+` / `GP17` hosts, installs `90-disable-usb-wakeup.rules` (`1d57:fa60` dongle + `0000:00:08.1`/`11:00.3`/`11:00.4`/`0e:00.0`) and `disable-acpi-wakeup.service` (`GP17`, `XHC0`, `XHC1`, `XH00`) while keeping wired keyboard `XHC2`/`5-1` and Power Button enabled | Prevents immediate spurious S3 wakeups (`pm_wakeup_irq=36` on `GP17`/`XHC0`/`1d57:fa60`) and caps `kwin_wayland` pre-sleep delay lock hangs at 2s instead of 5s. |
| **SDDM login theme** | Installs `custom/sddm-theme/` -> `/usr/share/sddm/themes/caelestia-lockscreen/`, copies current wallpaper & avatar, writes `/etc/sddm.conf.d/zz-caelestia.conf` (`Current=caelestia-lockscreen`, `GreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1`), and enables `sddm.service` | Matches the SDDM login screen visually to the standard-grey Caelestia lockscreen (`caelestia.desktop`) with the same layout, blur card, clock, greeting, password pill, session switcher, and power controls. |

---

## Notes for Future AI Agents
- **Antigravity CLI flags used:** `agy -p <prompt> --output-format stream-json`, `--conversation <id>`, repeatable `--add-dir <dir>`, `--mode accept-edits` / `--mode plan` / `--dangerously-skip-permissions`, `--model <id>`, `--effort <level>`. Note `--mode auto` is unavailable on standard accounts and intentionally omitted from Antigravity's permission dropdown.
- **Prerequisites for Antigravity in sidebar:** `/usr/bin/agy` must be installed and authenticated (`agy login`) as the desktop user (`darkmattz`).
- **Verification commands after changes:**
  ```bash
  /usr/lib/qt6/bin/qmllint ~/.config/quickshell/caelestia/modules/sidebar/AiAssistant.qml ~/.config/quickshell/caelestia/modules/sidebar/ai/ClaudeCodeSession.qml ~/.config/quickshell/caelestia/modules/sidebar/Content.qml
  systemctl --user restart caelestia-shell.service
  journalctl --user -u caelestia-shell.service -n 50 --no-pager
  ```
