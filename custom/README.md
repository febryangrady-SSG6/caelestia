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

---

## Inventory of System & Config Overrides (`custom/apply.sh`)

| Area | What `custom/apply.sh` configures | Reason |
| :--- | :--- | :--- |
| **KDE color contrast** | Syncs patched `src/bin/caelestia-color` to `~/.local/bin/caelestia-color` and re-applies active named scheme | Ensures `[Colors:Selection]` and `[Colors:Complementary]` contrast fixes apply to named schemes (e.g. `gruvbox/soft/dark`). |
| **Lockscreen QML modules** | Symlinks `/usr/lib/qt6/qml/Caelestia` and `/usr/lib/qt6/qml/M3Shapes` -> `~/.local/lib/qt6/qml/...` | `kscreenlocker_greet` can miss user `QML2_IMPORT_PATH`, leading to a black screen on `Meta+L`. |
| **KWin workspace tracker** | Installs `kwin_workspace_tracker.so` to `/usr/lib/qt6/plugins/kwin/effects/plugins/` if built | Ensures KWin loads the workspace tracker effect cleanly. |
| **Inactive window opacity** | Sets `kwinrulesrc` `[caelestia-opacity] opacityinactive=100`, `opacityinactiverule=2` | Keeps non-focused windows opaque instead of semi-transparent. |
| **Terminal (`foot`)** | Installs `custom/configs/foot.ini` (`shell=bash`) | Prevents desktop **Open Terminal** / `foot` from failing on unconfigured `fish`. |
| **Keybinds** | Installs `custom/configs/keybinds.json` + updates `kglobalshortcutsrc` | `Meta+W` / `Meta+Tab` for Caelestia Overview (unbinding KDE's conflicting `Meta+W` Overview), `Print` + `Meta+Shift+S` for Screenshot. |
| **`shell.json` defaults** | Deep-merges `custom/configs/shell.overrides.json` into `~/.config/caelestia/shell.json` | Sets `ai.defaultProvider = "antigravity"`, default browser `helium-browser`, and bar greeter GIFs (`bongocat.gif` / `kurukuru.gif`) without clobbering chat history. |
| **Default browser** | Sets `helium.desktop` via `xdg-settings` / `xdg-mime` if installed | Uses Helium Browser as default browser. |

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
