# Personal `caelestia-kde` Customizations & Reinstall Guide

This directory holds **all** personal customizations, patches, configs, and deployment automation on top of stock upstream [`ladybug-me/caelestia-kde`](https://github.com/ladybug-me/caelestia-kde) **without ever editing upstream repository files directly**.

- All tracked files outside `custom/` remain 100% identical to `upstream/main` (`git diff upstream/main..HEAD -- ':!custom'` is empty).
- Every code change lives as a clean, ordered patch in `custom/patches/`.
- `custom/apply.sh` stages a temporary copy of the upstream files, applies `custom/patches/*.patch` inside that temporary staging directory, builds the patched C++ QML plugin there when needed, and deploys the patched files + system/user configs to their live paths.

---

## Quick Reinstall (Fresh OS)

### Option A — Install from this repo (stock upstream + `custom/`)
```bash
git clone --recurse-submodules https://github.com/febryangrady-SSG6/caelestia.git ~/caelestia-kde
cd ~/caelestia-kde
bash install.sh
bash custom/apply.sh
```

### Option B — Dry-run patch check or force C++ plugin rebuild
```bash
# Verify all patches apply cleanly against the current upstream checkout (no live changes):
bash custom/apply.sh --check-patches

# Force rebuilding the patched C++ Caelestia QML plugin:
bash custom/apply.sh --rebuild-plugin
```

### Updating Upstream (`ladybug-me/caelestia-kde`)
Because no upstream files are edited directly in the repo, syncing upstream is conflict-free:
```bash
git fetch upstream
git rebase upstream/main
bash custom/apply.sh --check-patches
bash custom/apply.sh
```
If an upstream release causes a patch in `custom/patches/` to fail `--check-patches`, refresh that patch in a temporary worktree/clone and update only `custom/patches/`.

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

23. **`0023-fix-nmqt-resolve-ethernet-interface-by-name-and-pass.patch`**
   - **File:** `shell/plugin/src/Caelestia/Services/NmQt.cpp`
   - **Problem:** Clicking **Connect** on a disconnected Ethernet interface (e.g. `enp9s0`) sent no D-Bus activation to NetworkManager: `refreshEthernetDevices()` left `connection` empty when disconnected, `connectEthernet` called `findNetworkInterface("enp9s0")` (which expects a D-Bus UNI path) and `findDeviceByIpFace("enp9s0")` (unreliable when disconnected), passed `interfaceName` instead of `dev->uni()` to `activateConnection()`, and didn't fall back to available/saved wired profiles. The same `findNetworkInterface`/`findDeviceByIpFace` bug affected `refreshWirelessDeviceDetails()` and `refreshEthernetDeviceDetails()`.
   - **Fix:** Adds `findDeviceByIdentifier()` (matching UNI, `interfaceName()`, `ipInterfaceName()`, or `findDeviceByIpFace`), populates disconnected Ethernet `connection` from `availableConnections()`, updates `connectEthernet()` to pass `dev->uni()` and fall back cleanly through named connections, `availableConnections()`, matching `ConnectionSettings::Wired` profiles, and `addAndActivateConnection()`, and logs D-Bus activation failures (requires rebuilding `shell/plugin` if applying onto an existing checkout via Option B).

24. **`0024-fix-session-add-keyboard-navigation-and-focus-ring-t.patch`**
   - **Files:** `shell/components/controls/SessionConfirmPopup.qml` (new), `shell/modules/session/Content.qml`, `shell/modules/launcher/Content.qml`
   - **Problem:** The session action confirmation popup (`Log out?`, `Shut down computer?`, `Hibernate computer?`, `Restart computer?`) neither focused a button on open nor handled arrow/`Tab`/`Enter`/`Space`/`Escape` keys, `Cancel` defaulted to `TextButton.Filled` looking identical to the confirm button, and `TextButton`/`ButtonBase` had no visible keyboard focus ring.
   - **Fix:** Extracts a shared `SessionConfirmPopup` component (`Tonal` **Cancel** focused safely on open + `Filled` confirm button), adds full keyboard navigation (`Left`/`Right`/`Tab`/`Backtab`/`H`/`L` to switch buttons, `Enter`/`Return`/`Space` to activate, `Esc` to dismiss), and renders a 2px `m3onSurface` outer focus ring + radius shift on whichever button currently holds `activeFocus`.

25. **`0025-fix-brightness-delegate-to-KWin-brightness-and-respe.patch`**
   - **Files:** `shell/plugin/src/Caelestia/Services/brightnesswatcher.hpp`, `shell/plugin/src/Caelestia/Services/brightnesswatcher.cpp`, `shell/services/Brightness.qml`
   - **Problem:** `Brightness.qml` unconditionally ran `ddcutil detect` / `ddcutil setvcp 10` on any DDC-capable monitor (`isDdc: ddcInfo !== null`), bypassing KDE's per-output `DDC/CI: disallowed` (`allowDdcCi: false`) and software brightness (`allowSdrSoftwareBrightness: true`) settings and changing physical hardware monitor brightness alongside KWin software brightness.
   - **Fix:** Exposes `hasBrightness(outputName)` and `ddcCiAllowed(outputName)` (plus `hasBrightnessChanged` / `ddcCiAllowedChanged` signals from Wayland `kde_output_device_v2` `capabilities` & `ddc_ci_allowed`) in `BrightnessWatcher`, and updates `Brightness.qml` to delegate brightness solely to KWin (`BrightnessWatcher.setBrightness`) whenever KWin manages brightness or disallows DDC/CI, only falling back to `ddcutil` if KWin does not manage brightness and allows DDC/CI (requires rebuilding `shell/plugin` if applying onto an existing checkout via Option B).

26. **`0026-fix-utilities-keep-DrawerScrim-within-wrapper-bounds.patch`**
   - **File:** `shell/modules/utilities/DrawerScrim.qml`
   - **Problem:** `DrawerScrim` extended `-Tokens.padding.large - Config.border.thickness` plus an extra `-parent.height * 0.1` (`~10%` overhang) past the bottom edge, drew two external `ShapePath` corner tails (`-border.smoothing * 2`), and only rounded `topLeftRadius`, causing the darkened modal backdrop (`Delete recording?`, etc.) to spill out below and beyond the rounded Utilities drawer panel.
   - **Fix:** Sizes `DrawerScrim` to the exact `Utilities.Wrapper` bounds (`-Tokens.padding.large` top/left, `-CUtils.clamp(Tokens.padding.large - Config.border.thickness, 0, Tokens.padding.large)` bottom/right), removes the `-10%` overhang and external `ShapePath` tails, and applies `radius: Surface.panelRounding` cleanly across all corners.

27. **`0027-fix-updates-make-update-notification-Install-Updates.patch`**
   - **Files:** `src/bin/caelestia-check-updates`, `shell/services/NotifData.qml`, `shell/modules/notifications/Notification.qml`, `shell/modules/sidebar/NotifActionList.qml`
   - **Problem:** Clicking **Install Updates** on `Caelestia Updates` notifications did nothing: `caelestia-check-updates` used `notify-send -w -t 300000` (dying after 5 minutes / across restarts so persisted notifications had no `invoke` callback), called nonexistent `caelestia shell toggleNexus`, left `$REPO` undefined, and opened Nexus Updates (which hides Install Update when only system packages are pending).
   - **Fix:** Adds `NotifData.invokeAction(action)` (shared by `Notification.qml` and `NotifActionList.qml`) so `Caelestia Updates` **Install Updates** / **Close** actions work even on expired or persisted notifications — launching the system package updater (`yay -Syu` / `sudo pacman -Syu` / `flatpak update`) in the configured terminal for `System Update Available`, or opening Nexus Updates (`nexus openPage updates -1`) for Caelestia UI updates — and fixes `$REPO` + the fallback handler in `src/bin/caelestia-check-updates`.

28. **`0028-fix-bluetooth-size-disconnect-and-delete-icon-button.patch`**
   - **File:** `shell/modules/bar/popouts/Bluetooth.qml`
   - **Problem:** `connectBtn` never set `implicitWidth`/`implicitHeight` (only `Layout.preferredWidth` in points rather than pixels), so the delete button `Loader` bound its `Item` to `0×0` — causing the `delete` icon to overflow left into `link_off` (collapsing `ListRow` spacing) and leaving its `StateLayer` hit area at `0×0`.
   - **Fix:** Sizes `connectBtn` and the delete button `Item` to match their rendered `MaterialIcon` dimensions (`Math.max(icon.implicitWidth, ...)`), restoring clean `ListRow` spacing and a clickable delete target.

29. **`0029-feat-bar-allow-scrolling-on-volume-and-microphone-st.patch`**
   - **Files:** `shell/modules/bar/components/BarIcon.qml`, `shell/modules/bar/components/StatusIcon.qml`
   - **Summary:** Adds opt-in `acceptsWheel` and `wheelScrolled(angleDelta)` to `BarIcon`'s `MouseArea` (leaving wheel events unaccepted for non-opted-in icons) and wires `StatusIcon` `"audio"` / `"microphone"` to `Audio.incrementVolume()` / `Audio.decrementVolume()` and `Audio.incrementSourceVolume()` / `Audio.decrementSourceVolume()`.

30. **`0030-fix-bar-keep-click-opened-status-icon-popouts-open-u.patch`**
   - **Files:** `shell/modules/bar/components/BarIcon.qml`, `shell/modules/drawers/ContentWindow.qml`
   - **Problem:** Clicking a status icon (e.g. Battery while Notifications sidebar is open) opened its popout without setting `popouts.staysOpen = true`, causing `popoutHideTimer` to close it 150ms after the pointer left the icon; `ContentWindow.transientOverlayOpen` also omitted `staysOpen` popouts from overlay input capture.
   - **Fix:** Sets `popouts.staysOpen = true` in `BarIcon.openPopout()` and includes `(panels.popouts.staysOpen && panels.popouts.hasCurrent)` in `ContentWindow.transientOverlayOpen` so click-opened popouts stay open until clicked away, toggled, or dismissed with `Esc`.

31. **`0031-fix-bar-balance-TrayOverflow-padding-and-float-hover.patch`**
   - **File:** `shell/modules/bar/popouts/TrayOverflow.qml`
   - **Problem:** `minRows: 2` forced a single row of tray icons into a 2-row-tall box (huge top/bottom margin) while `implicitWidth` had 0px horizontal padding; clamping `nameTag` inside the box then covered the icons and clipped the label.
   - **Fix:** Sets `minRows: 1`, caps `columns` to `filled` when non-empty, adds uniform `Tokens.padding.medium` padding on all four sides, and reparents `nameTag` to `root.Window.contentItem` positioned outside the box.

32. **`0032-fix-utilities-size-TimersCard-duration-field-to-fit-.patch`**
   - **File:** `shell/modules/utilities/cards/TimersCard.qml`
   - **Problem:** `digitsField` had a hardcoded `Layout.preferredWidth: 96`, causing the `"300 = 3:00"` placeholder to overflow its right outline border.
   - **Fix:** Measures `digitsField.placeholderText` with `TextMetrics` and sets `Layout.preferredWidth: Math.max(96, Math.ceil(digitsPlaceholderMetrics.width) + leftPadding + rightPadding)`.

33. **`0033-fix-colors-repair-KDE-View-DecorationFocus-and-Decor.patch`**
   - **File:** `src/bin/caelestia-color`
   - **Problem:** The vendored Matugen KDE template set `[Colors:View] DecorationFocus` to dark `primary_container` (`#254777`) while `[Colors:Selection] ForegroundNormal` is `#000000`, causing Darkly to render focused push buttons (e.g. Konsole's **Cancel** button) with black text on dark blue.
   - **Fix:** Updates `cmd_kde_selection()` to repair `[Colors:View]` `DecorationFocus` and `DecorationHover` to `#{primary}` whenever their WCAG contrast against `sel_fg` is `< 4.5`.

34. **`0034-fix-nexus-open-requested-page-or-subpage-directly-in.patch`**
   - **File:** `shell/modules/nexus/PageCompRegistry.qml`
   - **Problem:** `defaultPageForCategoryKey("bluetooth")` (and `"audio"`) resolved the parent category index and returned that category's default page (`"network"` / `"displays"`) instead of the requested page key, so clicking **Open settings** in the Bluetooth popout opened Network instead of Bluetooth.
   - **Fix:** Returns `categories[i].defaultPage` only when `key` matches a category key, and returns `key` itself when it matches a page or subpage key.

35. **`0035-fix-dock-increase-spacing-between-dock-icons-for-eas.patch`**
   - **File:** `shell/modules/bar/components/Dock.qml`
   - **Summary:** Increases `Dock.spacing` from `Tokens.spacing.extraSmall` to `Tokens.spacing.medium` so right-clicking between dock tiles to open the **Dock settings / Elements & Modules** menu is comfortable.

36. **`0036-feat-nexus-add-Antigravity-CLI-provider-settings-and.patch`**
   - **Files:** `shell/services/AntigravityOptions.qml` (new), `shell/modules/nexus/pages/AiSettingsPage.qml`, `shell/modules/sidebar/AiAssistant.qml`, `shell/modules/sidebar/Content.qml`
   - **Summary:** Adds a shared `AntigravityOptions` singleton (`QtCore.Settings` `[AntigravityAI]`, default `enabled: false`) and an **Antigravity** section in Nexus **AI Assistant** with enable toggle + reset-to-default button, `agy --version` status check, and **Log in to Antigravity** terminal action, wired live to the sidebar AI Assistant tab and provider list.

37. **`0037-feat-nexus-make-Nexus-settings-window-frameless-with.patch`**
   - **Files:** `shell/modules/nexus/WindowFactory.qml`, `shell/modules/nexus/Nexus.qml`
   - **Summary:** Replaces Nexus's opaque KWin titlebar (paired with `caelestia-nexus-noborder` in `kwinrulesrc` via `custom/apply.sh`) with a seamless transparent glass top bar floating over `Nexus`'s single `BlobInvertedRect` (`topInset: 36`), rounded outer corners (`StyledClippingRect` + `BlurMask`), 1px glass rim, drag/double-click maximize, and invisible edge/corner resize grips.

38. **`0038-fix-nexus-standardize-section-row-gaps-and-add-horiz.patch`**
   - **Files:** `shell/modules/nexus/pages/wallandstyle/AppearancePage.qml`, `shell/modules/nexus/pages/desktop/DesktopAddonsPage.qml`, `shell/modules/nexus/common/PageBase.qml`
   - **Summary:** Restores `Tokens.spacing.extraSmall / 2` row gaps on **Scaling**, **Animations**, **Corners & effects**, and **Desktop lyrics** sections, and adds `Tokens.padding.medium` horizontal margins to `PageBase` page headers.

39. **`0039-fix-bar-prevent-popout-open-and-close-animations-fro.patch`**
   - **Files:** `shell/modules/bar/popouts/ClipWrapper.qml`, `shell/modules/bar/popouts/Wrapper.qml`, `shell/modules/drawers/ContentWindow.qml`
   - **Problem:** Spring overshoot on `ClipWrapper.offsetScale`, `popoutBg` jelly `deformAmount`, `BlurMask` integer truncation at the bar edge, and `Wrapper` unloading `content` mid-close caused a visible gap between bar popouts and the bottom bar during open/close animations (especially with the Notifications sidebar open).
   - **Fix:** Switches `ClipWrapper` `Behavior on offsetScale` to `Anim.DefaultEffects` with clamped `clampedOffsetScale`, disables `deformAmount` on `popoutBg`, extends `popoutsWrapper`'s `BlurMask` overlap into the bar edge, and keeps `Wrapper` content active until `offsetScale` reaches `1`.

40. **`0040-fix-blur-add-circular-FilletBlur-for-drawer-junction.patch`**
   - **Files:** `shell/modules/drawers/blur/FilletBlur.qml` (new), `shell/modules/drawers/blur/BlurCorners.qml`, `shell/modules/drawers/blur/BlurOffsets.qml`, `shell/modules/drawers/ContentWindow.qml`
   - **Problem:** Concave drawer-to-bar/border junctions rendered semi-transparent glass without backdrop blur (especially on `popoutsWrapper`, `sidebar`, `launcher`, `dashboard`, and `utilities`), `BlurCorners` left 1–2px ghost blur residue dots when panels closed and poked slightly outside rounded corners mid-animation, and `BlurOffsets` scaled corner radius by `animScale`.
   - **Fix:** Adds a reusable 20-slice (`1px/row`) circular-arc `FilletBlur` matching `blob.frag`'s circular `smin` across all drawer junctions (guarding the sidebar bottom fillet when connected to a popout), adds `Tokens.padding.small` `BlurMask` edge overlap, switches additive `BlurCorners` strips to inscribed `m / steps` with per-corner `r > 0` gating, removes `* animScale` from `BlurOffsets.r`, and bases `popoutBg.connectedToSidebar` on `nonAnimWidth`.

41. **`0041-fix-bar-remove-popout-close-blur-halo-and-prevent-fi.patch`**
   - **Files:** `shell/modules/bar/popouts/ClipWrapper.qml`, `shell/modules/bar/popouts/Audio.qml`, `shell/modules/bar/popouts/Network.qml`, `shell/modules/drawers/Panels.qml`
   - **Problem:** `ClipWrapper`'s `- 5` anchor margin offset let `popoutBg` drift ahead of its `BlurMask` during fast close animations (leaving a lagging blurred halo at the top edge), and opening `Audio`/`Network` immediately after opening the Notifications sidebar initialized `_isSidebarOpen` to `false`, causing a brief width mismatch and cut/jump on the sidebar junction.
   - **Fix:** Removes the `- 5` margin offset from `ClipWrapper` anchors so `popoutBg` and `BlurMask` stay pixel-locked, initializes `_isSidebarOpen: popouts?.sidebarOpen ?? false` in `Audio.qml` and `Network.qml`, and switches `Panels.qml`'s `sidebar.pushSpacing` to check `popoutsWrapper.content.nonAnimWidth`.

42. **`0042-feat-nexus-render-native-KDecoration3-window-buttons.patch`**
   - **Files:** `shell/plugin/src/Caelestia/Services/CMakeLists.txt`, `shell/plugin/src/Caelestia/Services/kdedecorationbuttons.hpp` (new), `shell/plugin/src/Caelestia/Services/kdedecorationbuttons.cpp` (new), `shell/modules/nexus/WindowFactory.qml`
   - **Summary:** Adds a native `KDecoration3` QQuickPaintedItem (`KdeDecorationButtons`) that loads the active KDE window decoration plugin and button layout from `kwinrc` (`org.kde.kdecoration3`) once on startup, respects `recommendedBorderSize` when `BorderSizeAuto` is enabled, updates button geometry on maximize state changes (`nextState()`), uses neutral standard white (`#eff0f1` / `#bdc3c7` / `#da4453`) foreground icons, and renders left/right titlebar buttons in Nexus's frameless header.

43. **`0043-fix-nexus-clamp-and-clip-page-scrollbars-and-prevent.patch`**
   - **Files:** `shell/components/containers/StyledFlickable.qml`, `shell/components/containers/StyledListView.qml`, `shell/modules/nexus/Pages.qml`, `shell/modules/nexus/SubcategoryPane.qml`, `shell/modules/nexus/common/PageBase.qml`
   - **Problem:** Interrupted overscroll `rebound` transitions in `StyledFlickable`/`StyledListView` called `cancelFlick()` while `contentY < 0`, freezing `visibleArea.yPosition` negative and pushing `PageBase`'s unclamped, unclipped scrollbar thumb upward through the header and titlebar.
   - **Fix:** Guards the post-rebound fake-flick on `verticalOvershoot === 0 && horizontalOvershoot === 0` with `returnToBounds()`, sets `boundsBehavior: Flickable.StopAtBounds` and `clip: true` on `PageBase`, `SubcategoryPane`, and `Pages`, and clamps `scrollBar.y` and `scrollBar.height` strictly within `[0, flickable.height]`.

44. **`0044-fix-blur-fix-top-anchored-BlurOffsets-add-vertical-F.patch`**
   - **Files:** `shell/modules/bar/popouts/ClipWrapper.qml`, `shell/modules/drawers/ContentWindow.qml`, `shell/modules/drawers/Panels.qml`, `shell/modules/drawers/blur/BlurOffsets.qml`, `shell/modules/drawers/blur/FilletBlur.qml`
   - **Problem:** `BlurOffsets` swapped `blurOffsetTop` and `blurOffsetBottom` when `vAnchor === "top"`, pushing the Dashboard's `-7px` top overlap onto its bottom edge; vertically-anchored panels (`osdWrapper`, `sessionWrapper`, `utilities`, vertical-bar or side-snapped `popoutsWrapper`) lacked vertical-wall `FilletBlur` masks; and horizontal-bar popouts within `Config.border.smoothing` of a side border fused via `smin` while leaving a 4px unblurred gap and a 28px rounded cutout in the blur mask.
   - **Fix:** Maps `sTop`/`sBottom`/`sLeft`/`sRight` directly to `blurOffsetTop`/`Bottom`/`Left`/`Right` in `BlurOffsets.qml`, adds `vertical: true` support to `FilletBlur.qml` and wires it to `osdWrapper`, `sessionWrapper`, `utilities`, and side-attached `popoutsWrapper`, snaps `ClipWrapper` flush to the screen border when within `Config.border.smoothing`, and sets `popoutsWrapper.hAnchor`/`vAnchor` dynamically from border attachment.

45. **`0045-fix-nexus-add-balanced-header-top-and-side-margins-i.patch`**
   - **File:** `shell/modules/nexus/common/PageBase.qml`
   - **Summary:** Adds `Layout.topMargin: Tokens.padding.medium`, `Layout.bottomMargin: Tokens.spacing.extraSmall`, and `Tokens.padding.large` horizontal margins to `headerBand` so the circular back button and page title sit symmetrically inside the rounded top-left corner of the Nexus content card.

46. **`0046-fix-blur-add-horizontal-and-vertical-FilletBlur-for-.patch`**
   - **File:** `shell/modules/drawers/ContentWindow.qml`
   - **Summary:** Extends `panels.notifications`'s `BlurMask` offsets into its anchored screen borders/bar and adds horizontal-wall and vertical-wall (`vertical: true`) `FilletBlur` masks so both concave corner fillets of the notification popup are fully blurred.

47. **`0047-feat-launcher-use-single-line-macOS-Launchpad-style-.patch`**
   - **File:** `shell/modules/launcher/items/AppTile.qml`
   - **Summary:** Uses a single-line centered label (`labelLines: 1`) with right-side ellipsis (`…`) at rest (macOS Launchpad style) and word-boundary wrapping without mid-word splits in `Flip`/`Shrink` overflow modes, keeping hover tooltips for truncated names.

48. **`0048-feat-ui-add-toast-blur-masks-slider-row-layout-and-b.patch`**
   - **Files:** `shell/components/controls/SliderRow.qml`, `shell/modules/drawers/ContentWindow.qml`, `shell/modules/drawers/blur/BlurCorners.qml`, `shell/modules/drawers/blur/BlurOffsets.qml`, `shell/modules/nexus/WindowFactory.qml`, `shell/modules/utilities/toasts/Toasts.qml`
   - **Summary:** Adds `ToastBlurMask` entries in `ContentWindow.qml` backed by `Toasts.qml`, refines `SliderRow.qml` icon button and padding layout, and updates `BlurCorners.qml`, `BlurOffsets.qml`, and `WindowFactory.qml`.

49. **`0049-fix-font-use-QtRendering-for-text-while-keeping-Nati.patch`**
   - **Files:** `shell/components/StyledText.qml`, `shell/components/MaterialIcon.qml`, `shell/components/controls/TextFieldBase.qml`, `shell/modules/bar/popouts/Notes.qml`, `shell/modules/dashboard/NotesTab.qml`
   - **Problem:** `StyledText`, `TextFieldBase`, and Notes inputs forced `NativeRendering` (FreeType RGB subpixel AA), causing chromatic fringing on dark/translucent Wayland surfaces and blurry/fringed strokes when `StyledTextField` downscales its floating placeholder (`scale: root.smallFontScale`).
   - **Fix:** Switches text components (`StyledText`, `TextFieldBase`, `Notes`, `NotesTab`) to `QtRendering` for smooth grayscale antialiasing and clean scaling (macOS-like), while explicitly keeping `Text.NativeRendering` on `MaterialIcon.qml` so variable icon fonts (`Material Symbols Rounded` with `FILL=1`) render without SDF overlapping-contour artifacts.

50. **`0050-fix-dashboard-improve-Caelestia-logo-contrast-on-pri.patch`**
   - **File:** `shell/modules/dashboard/dash/User.qml`
   - **Problem:** `caelestiaLogo` rendered `topColour` and the KDE badge in `m3primary` on top of `m3primaryContainer`, producing very low contrast in muted schemes.
   - **Fix:** Uses `m3onPrimaryContainer` (75% opacity for the crescent/sparkles, 100% for the swoosh) and `m3onPrimaryContainer` / `m3primaryContainer` for the KDE badge and stroke.

51. **`0048-fix-filedialog-enable-KWin-backdrop-blur-on-FileDial.patch`**
   - **File:** `shell/components/filedialog/FileDialog.qml`
   - **Problem:** `FileDialog`'s `FloatingWindow` set `color: Colours.tPalette.m3surface` and `surfaceFormat.opaque: false` without a `BackgroundEffect.blurRegion`, rendering translucent glass with no KWin backdrop blur.
   - **Fix:** Adds `BackgroundEffect.blurRegion` bound to `dialogContent` when `GlobalConfig.appearance.transparency.enabled && GlobalConfig.appearance.blur` (matching `WhatsNewWindow.qml`).

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
- **Never edit upstream `caelestia-kde` files directly in this repository.** Keep `git diff upstream/main..HEAD -- ':!custom'` empty at all times. To add or modify a customization, create/update a numbered patch in `custom/patches/` (e.g., via a temporary git worktree or clone), verify with `bash custom/apply.sh --check-patches`, document it in `custom/README.md`, and deploy with `bash custom/apply.sh`.
- **Antigravity CLI flags used:** `agy -p <prompt> --output-format stream-json`, `--conversation <id>`, repeatable `--add-dir <dir>`, `--mode accept-edits` / `--mode plan` / `--dangerously-skip-permissions`, `--model <id>`, `--effort <level>`. Note `--mode auto` is unavailable on standard accounts and intentionally omitted from Antigravity's permission dropdown.
- **Prerequisites for Antigravity in sidebar:** `/usr/bin/agy` must be installed and authenticated (`agy login`) as the desktop user (`darkmattz`).
- **Verification commands after changes:**
  ```bash
  /usr/lib/qt6/bin/qmllint ~/.config/quickshell/caelestia/modules/sidebar/AiAssistant.qml ~/.config/quickshell/caelestia/modules/sidebar/ai/ClaudeCodeSession.qml ~/.config/quickshell/caelestia/modules/sidebar/Content.qml
  systemctl --user restart caelestia-shell.service
  journalctl --user -u caelestia-shell.service -n 50 --no-pager
  ```
