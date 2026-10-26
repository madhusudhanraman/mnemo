# Native Mac work

Branch: `native-mac`. Work stays local until the user asks to push.

## First: menu bar navigation

Fix the menu bar dropdown before other native-app work. The user reports that hovering over items does not highlight them and moving through the menu feels unsmooth.

Check hover highlighting, movement between items, opening and crossing into submenus, keyboard navigation, and dismissal. Enabled items should respond like standard macOS menu items, with no missing highlights or interruptions.

Completed locally. The user confirmed smooth menu navigation after fully removing both companion mouse-event monitors while AppKit tracks the menu. Returning early from installed monitors was insufficient. Monitors are reinstalled asynchronously after all menus close.

Also retain native menu/status-item objects when changing colour, defer menu-state updates until tracking ends, avoid unchanged checkmark assignments, and pause 3D redraws while menus are open. The native regression check covers menu identity, colour checkmarks, deferred updates, nested tracking, action targets, removal of event monitors during tracking, and restoration after dismissal (`sh desktop/tests/check-menus.sh`). Temporary native highlight timing diagnostics have been removed. Nothing has been pushed.

## Installation and startup

Implemented locally: `desktop/install.sh` verifies and stages the signed app, installs at `~/Applications/Mnemo.app`, and rolls back on failure. Build-folder copies redirect ordinary launches to the installed app; `--development` explicitly opts out. A cross-process file lock is acquired before reminder storage or UI creation. A duplicate launch reveals the running companion and exits.

Launch at Login is an optional native menu checkbox using `SMAppService.mainApp`; it is never registered automatically. It reads real system registration state, shows pending approval separately, and reports errors. It is only available in the installed app. Startup creates the companion without opening the editor; later Dock activation still opens reminders. Regression checks cover login states/error handling and cross-process lock exclusion/release (`sh desktop/tests/check-startup.sh`). Actual logout/login and OS approval are not exercised by these tests. The signed build was installed and launched from Applications; startup showed only the companion, the native Launch at Login option was present, and an attempted build-folder launch left only the installed Mnemo process running. Login startup was not enabled during verification.

## Dock and native Settings

Completed locally: the menu bar icon remains available; Show in Dock defaults to on and persists across launches. The native Settings window has Dock visibility, Launch at Login, colour and a size shortcut. It is available through Settings… in the status menu and the application menu (Command-comma). The Dock context menu offers reminders and Settings; a Dock reopen still opens reminders. Closing Settings or the reminder editor leaves the companion running; Quit exits.

Live verification: the installed Settings window showed login startup enabled, hiding the Dock icon kept Settings usable, and showing the Dock icon again restored the original preference. Closing both Settings and the editor left Mnemo running. Native tests cover Settings action bindings, approval/busy state, appearance controls and Dock-menu targets. Nothing pushed.

## Next

- Verify multiple-display dragging, monitor disconnection/reconnection and changed display layouts on hardware.
- Verify Spaces, fullscreen and Stage Manager behaviour across apps.
- Reduce Motion, Reduce Transparency, Increase Contrast, keyboard access and VoiceOver.
- Low Power Mode adaptation and suspension during screen sleep or lock.
- Reminder editor focus, keyboard shortcuts and thought-bubble placement near screen edges.


### Login registration follow-up

The first live click exposed an incorrect early rejection of `SMAppService.Status.notFound` and an app-modal error alert inside the menu action. A stack sample confirmed `NSAlert.runModal`, rather than a stuck registration API, was blocking menu use.

The controller now attempts registration from not-found state, performs registration on a serial background queue, and returns results to the main queue. Pending, approval and error feedback appears in the menu with an optional Open Login Settings action; no app-modal login alerts remain. Tests explicitly hold a registration operation open and verify the main queue stays responsive, plus verify registration from not-found state.

After reinstalling, the user's enable request was retried successfully. macOS background-task registration reports Mnemo enabled and allowed; the menu reopened normally afterward. Login startup is now enabled on this Mac. Actual logout/login remains untested. Nothing pushed.

## Displays and Spaces

Implemented locally: remember normalized resting positions by display ID, restore the preferred display when it reconnects, and recover onto the nearest available display after disconnection or display layout/resolution changes. Dragging to a different display makes it preferred. Transparent canvas margins do not constrain movement. No extra polling is introduced.

The companion continues to join all Spaces with fullscreen auxiliary behavior. The editor and Settings remain ordinary windows in their own Space. Space changes refresh visibility and background sampling without activating Mnemo or opening the editor. Physical monitor hot-plug, fullscreen across other apps and Stage Manager still require live verification.

## Spotify companion

When Spotify is playing and no reminder is being shown, optionally display the current track with a Skip control. Reminders always take priority. Keep this opt-in and visually quiet; pause or hide the track display when playback stops. Investigate supported local integration and any Automation permission before implementation. Implemented separately on spotify-integration; see docs/spotify.md.

### Mission Control

The companion explicitly uses stationary behavior, alongside canJoinAllSpaces and fullScreenAuxiliary. A floating window otherwise defaults to transient and disappears in Mission Control. It also ignores normal window cycling; the editor and Settings retain normal window behavior. Native checks verify these flags. The user confirmed that Mnemo remains visible in Mission Control after installing this change.

## Simplified menus — 22 October

The status dropdown keeps My reminders, Settings, Show/hide ghost, Pause/resume motion and Quit. Size, Colour and Launch at Login are accessed through native Settings; their duplicate entries were removed from both the status dropdown and application menu. Native checks verify the compact menu contents and retained Settings controls.

## Companion and editor follow-up — 22 October

On `fix-idle-jumps`: native dragging anchors the window to the original mouse grab point and retains mouse capture until release. Body bounds reserve 20 points at the sides/bottom, with the rendered crown allowed up to the menu bar. The larger transparent panel lets reminder/music tiles choose any side without imposing large movement margins. Physical multi-display verification remains pending.

The editor title is now Mnemo with no duplicate body heading. Date/time wheels show an approximate time remaining (exact date/time in a tooltip). Blank reminders randomly rotate five curated placeholders, avoiding consecutive repeats and preserving drafts: Invade Berlin; Knock over a casino; Give the skeletons a bigger closet; Embark on a fool’s errand; Schedule a wild goose chase. Pirouettes retain idle sway throughout to avoid a snap at the start/end.

26 October local fix: added the standard macOS Edit menu with responder-chain Undo/Redo, Cut/Copy/Paste and Select All commands. The application previously supplied only its app menu, leaving Command-V without a menu key equivalent in WebKit reminder/task fields. Signed build installed; menu bindings covered by native menu checks. Physical keyboard paste still needs user confirmation.
