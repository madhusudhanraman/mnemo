# Mnemo

A little ghost for your Mac who keeps your reminders company.

![Mnemo](docs/media/mnemo.png)

- **Reminders:** click Mnemo to add one, in days or at a specific date and time. Due reminders appear as thought bubbles and stay until you choose **Done** or **Remind Me Later** (three hours). Multiple reminders form a queue—no macOS notification banners.
- **Projects:** organise tasks into Home and Work projects, add notes, and choose which projects appear on each Mac.
- **Spotify:** hover to see the current song, play/pause, skip or go back. The heart saves or removes songs from Liked Songs after a one-time [Spotify connection](docs/spotify.md#liked-songs).
- **A quiet companion:** Mnemo drifts, tilts, pirouettes and plays peekaboo. He settles when the Mac is idle and flutters when you finish a reminder.
- **Make him yours:** drag to move, adjust size and colour, and choose Launch at Login or whether to show him in the Dock. Auto colour adapts to the background.

Reminders and projects stay on this Mac; there is no cross-Mac sync. Mnemo must be running to show reminders and catches up after sleep or relaunch. Auto colour needs Screen Recording permission; background samples are never saved or sent. Spotify playback uses macOS Automation permission; Liked Songs uses Spotify sign-in with credentials stored in Keychain.

## Build and run

Requires macOS, Apple Command Line Tools and Node.js. No npm install needed.

```sh
node prototype/build.mjs
sh desktop/build.sh
# Quit Mnemo before installing:
sh desktop/install.sh
open ~/Applications/Mnemo.app
```

This is a development build, not a notarised release. See [desktop setup](desktop/README.md) for signing and permissions, [prototypes](prototype/README.md) for previews, and [performance notes](docs/performance.md) for resource behaviour.

Three.js is vendored under its [MIT license](prototype/vendor/LICENSE).
