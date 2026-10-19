# Mnemo

A small ghost for your Mac. He lingers nearby and carries reminders in thought bubbles.

Click Mnemo to add a reminder. Drag him to move. Choose his size and colour from the menu bar.

## A little company

| Linger | Sleepy Drift | Curious Tilt |
| :---: | :---: | :---: |
| ![Mnemo gently swaying](docs/media/linger.gif) | ![Mnemo settling into sleepy drift](docs/media/sleepy.gif) | ![Mnemo tilting curiously](docs/media/curious.gif) |

| Whirl Flutter | Peekaboo |
| :---: | :---: |
| ![A spiral flutter through Mnemo’s sheet](docs/media/flutter.gif) | ![Mnemo fading away and returning, leaving his eyes visible](docs/media/peekaboo.gif) |

*Model renders using the production geometry and behaviour curves; lighting approximates the app. Gestures are shown on demand here and occur less often on the desktop.*

## Reminders

Set a reminder in days, or choose a date and time. When it is due, Mnemo glows and spins, then shows a thought bubble that stays until you respond.

- **Done** completes it with a Whirl Flutter.
- **Remind Me Later** postpones it by three hours.
- Multiple reminders queue in deadline order.

No macOS notification banners. Reminders are saved locally and catch up after sleep or relaunch. Mnemo must be running; launch at login is not yet configured.

## Build and run

Requires macOS, Apple Command Line Tools and Node.js. No npm install is needed.

```sh
node prototype/build.mjs
sh desktop/build.sh
open desktop/build/Mnemo.app
```

This is a development build, not a notarised release. For stable Screen Recording permission across rebuilds, configure a signing identity as described in [desktop development](desktop/README.md).

Auto colour adjusts to the background and needs Screen Recording permission. Samples stay in memory and are never saved or sent. Manual White and Lavender colours need no screen access.

## Development

- [Desktop app and resource limits](desktop/README.md)
- [Browser prototypes and visual previews](prototype/README.md)
- [Recreate the GIFs](docs/media/README.md)

Checks use disposable data:

```sh
for check in prototype/review/check-*.mjs; do node "$check"; done
swiftc -swift-version 5 -module-cache-path /tmp/mnemo-swift-cache \
  desktop/Sources/ReminderStore.swift desktop/tests/main.swift -o /tmp/mnemo-store-tests
/tmp/mnemo-store-tests
```

During the first week, watch for missed or duplicate reminders, sleep/wake behaviour, smooth transitions, background contrast, and CPU use while idle. Please include the macOS version and steps to reproduce when reporting a problem.

Three.js is vendored under its [MIT license](prototype/vendor/LICENSE).
