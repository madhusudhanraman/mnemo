# Spotify on Hover

Worktree/branch: spotify-integration, starting from native-mac commit 584975e. Included in the 20 October 2026 integration into main.

Enable **Spotify on Hover** in native Settings. Spotify must be installed and running. macOS may ask for Automation permission for Mnemo to communicate with Spotify. No Spotify web login, credentials, web playback SDK or network connection is added by Mnemo.

Hover for 300 ms while music is playing, or two seconds for a paused track, to reveal title, artist and Previous / Play–Pause / Next controls near the companion. Moving onto the caption keeps it open; leaving both fades it out after 500 ms. Click Mnemo still opens reminders. Persistent reminders suppress music from the start of their announcement. Paused tracks remain available on hover with a Play button; stopped playback and disabled integration hide the caption. Long titles truncate with a native tooltip. Caption fits its content up to 220 points wide and is clamped to the panel bounds.

Native Apple Events use Spotify's installed scripting dictionary (player state, current track name/artist, previous track, play/pause and next track). They run on a serial background queue with a five-second timeout per request. Track strings are rendered using textContent, never code or HTML. No scripts are compiled or executed. Spotify isn't intentionally launched, resumed or skipped automatically. Only explicit control clicks send playback commands.

Reads occur on enable, hover entry, and at most every five seconds while hovered and the session/display are active. No extra polling timer, rendering loop, album-art requests or playback progress updates are added. Denied Automation access stops further requests until the setting is toggled again. Permission errors appear in Settings. No track information is persisted or logged.

Checks: prototype/review/check-spotify-caption.mjs covers hover delay, transition to controls, Previous / Play–Pause / Next, paused-track resume, reminder priority, pause, safe text and viewport bounds. Existing page and native menu checks cover renderer behavior and native controls. The installed service connected successfully on retry after an initial Spotify timeout. The hover appearance and actual Skip still need user confirmation. This is for the Mac Spotify app, not the browser player.

## Screen-edge placement

Reported on 20 October: the caption could extend beyond the display near an edge.

22 October local follow-up: movement now constrains the body with a 20-point side/bottom margin and no top margin (the rendered crown may reach the menu bar) rather than reserving a whole panel around it. A larger transparent companion panel provides space for tiles on every side. Native code reports the intersection with the current display’s visible frame (excluding Dock/menu bar) after movement and display recovery. Reminders prefer above and music prefers below; both fall back to left/right or the other vertical side when needed. Reminders still suppress music. Only body and visible controls receive mouse input.

Native bounds/menu checks, page activity/rendering checks, Spotify hover/Skip/priority checks and placement checks for all corners and partially offscreen windows pass. Signed build installed for visual verification; multi-display hardware and live Spotify behaviour still need confirmation. The larger transparent surface’s energy impact has not been measured.

22 October: hover controls now include Previous, Play/Pause and Next, using Spotify’s installed scripting dictionary (`Prev`, `PlPs`, `Next`). Paused tracks retain their metadata and remain eligible for hover. All controls disable while a request is pending. Native command mapping and page control/paused-state checks pass; actual playback commands still need live confirmation.
