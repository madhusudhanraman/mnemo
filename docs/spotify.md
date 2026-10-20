# Spotify on Hover

Worktree/branch: spotify-integration, starting from native-mac commit 584975e. Included in the 20 October 2026 integration into main.

Enable **Spotify on Hover** in native Settings. Spotify must be installed and running. macOS may ask for Automation permission for Mnemo to communicate with Spotify. No Spotify web login, credentials, web playback SDK or network connection is added by Mnemo.

Hover for 300 ms to reveal title, artist and Skip beneath the companion. Moving onto the caption keeps it open; leaving both fades it out after 500 ms. Click Mnemo still opens reminders. Persistent reminders suppress music from the start of their announcement. Paused/stopped playback and disabled integration hide the caption. Long titles truncate with a native tooltip. Caption fits its content up to 220 points wide and is clamped to the panel bounds.

Native Apple Events use Spotify's installed scripting dictionary (player state, current track name/artist, next track). They run on a serial background queue with a five-second timeout per request. Track strings are rendered using textContent, never code or HTML. No scripts are compiled or executed. Spotify isn't intentionally launched, resumed or skipped automatically. Only Skip sends a playback command.

Reads occur on enable, hover entry, and at most every five seconds while hovered and the session/display are active. No extra polling timer, rendering loop, album-art requests or playback progress updates are added. Denied Automation access stops further requests until the setting is toggled again. Permission errors appear in Settings. No track information is persisted or logged.

Checks: prototype/review/check-spotify-caption.mjs covers hover delay, transition to controls, Skip, reminder priority, pause, safe text and viewport bounds. Existing page and native menu checks cover renderer behavior and native controls. The installed service connected successfully on retry after an initial Spotify timeout. The hover appearance and actual Skip still need user confirmation. This is for the Mac Spotify app, not the browser player.

## Known issue: screen-edge clipping

Reported by the user on 20 October 2026: when Mnemo is close to a screen edge, the Spotify caption is not fully visible. The current bounds check only considers the transparent companion panel, not the display's visible frame. Follow-up: place the caption within the actual display work area (including Dock/menu bar), shifting it inward or above Mnemo when needed; preserve hover access to Skip and test all edges, sizes and multiple-display layouts. This issue is recorded, not fixed in this integration.
