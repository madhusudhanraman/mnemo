# Mnemo for macOS

A floating ghost that remembers things for you. Click Mnemo—or his Dock icon—to open reminders. Drag him to move; Shift-drag turns him. He drifts, pirouettes and plays Peekaboo on his own. After a quiet spell his eyes droop and movement slows; approaching him wakes him and may prompt a curious tilt. Completing a reminder triggers a gentle spiral flutter through his sheet.

## Reminders

Choose **Days** or **Date & Time**. The custom picker has a calendar and an scrollable hour/minute wheels with AM/PM.

When a reminder is due, Mnemo glows and spins before showing a thought bubble. Choose **Done** or **Remind Me Later**. Later postpones by three hours. Unanswered bubbles remain until acted on, including after sleep or relaunch. Multiple due reminders wait in deadline order. The first gets the full entrance; subsequent reminders glow without a pirouette, with a spiral flutter after Done. Reduce Motion skips the prelude. There are no macOS notification banners or notification permission requests.

Reminders are saved in `~/Library/Application Support/Mnemo/reminders.json`. Mnemo catches up after sleep or relaunch, but must be running to show reminders. Launch at login is not yet configured.

## Appearance

The menu bar offers size and colour controls. **Auto** colour samples the background behind Mnemo and needs Screen Recording permission. Samples stay in memory and are never saved or sent. **White** and **Lavender** need no screen permission. Size and position persist across launches.

The installed app is `~/Applications/Mnemo.app`.

## Development

Requires macOS and Apple Command Line Tools:

```sh
node prototype/build.mjs
sh desktop/build.sh
```

Builds reuse the local signing identity pinned in the ignored `desktop/signing-identity.local`, or `MNEMO_SIGNING_IDENTITY`. A failure with a selected identity stops the build. No keys or trust settings are created. Ad-hoc signing is a fallback only when no identity is configured; it can invalidate permissions across rebuilds. This app is not notarised for distribution.

Checks use disposable data:

```sh
swiftc -swift-version 5 -module-cache-path /tmp/mnemo-swift-cache desktop/Sources/ReminderStore.swift desktop/tests/main.swift -o /tmp/mnemo-store-tests
/tmp/mnemo-store-tests
node prototype/review/check-reminders.mjs
node prototype/review/check-page.mjs
node prototype/review/check-ghost.mjs
node prototype/review/check-cloth-gpu.mjs
node prototype/review/check-hover-tilt.mjs
```

## Resource use

The companion renders at up to 20 frames/second while idle, 10 while sleepy, and 30 during interactions or reminder entrances. A paused, unchanged ghost does not repeatedly render; hiding Mnemo, screen sleep and inactive sessions suspend rendering. The desktop renderer uses a canvas matched to the chosen ghost size with a maximum 2× pixel ratio and a reduced mesh. Cloth motion and Whirl Flutter run in a vertex shader, with only eye anchoring on the CPU. Opaque frames render directly; extra compositing buffers are allocated only for Peekaboo and released when the sheet returns. Autonomous gesture checks are spaced 90–180 seconds apart, with Peekaboo every 3–5 minutes when eligible. The reminder editor loads a separate page without Three.js or a second 3D scene. Auto colour backs off from five to twenty seconds on a stable background and checks sooner after moves or app switches; manual colour avoids background sampling entirely. These are workload limits, not a battery-life guarantee.
