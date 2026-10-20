# Mnemo: working notes for coding agents

These notes are shared by every coding agent working on this repo (Claude Code reads them through `CLAUDE.md`; Codex reads `AGENTS.md` directly). Keep the instructions tool-neutral.

Mnemo is developed on two Macs (personal and work), coordinated through GitHub. Feature branches only; PRs go into `main`. Never commit or push to `main` directly, and never merge PRs.

## Current work

Idle energy and the settle/stir behaviour: see `docs/performance.md` for status, measurements and open questions. Read it before continuing that work.

## Publishing changes

As part of finishing any development change, commit and push it to the current feature branch, then confirm the branch and commit are on GitHub. Do not leave completed work only on one Mac. Main and PR rules above still apply.

## Machine handoff

When the user says they are switching to the other machine (leaving this one):

1. `git status`. If there are changes on `main`, move them to a new feature branch first.
2. Commit everything not ignored, as `WIP: handoff from <short hostname>` if the work is unfinished.
3. `git push -u origin HEAD`. Push the current feature branch only.
4. Report the branch name and commit, and confirm nothing is left unpushed (`git status -sb` shows no "ahead").

When the user says they have switched to this machine (arriving):

1. `git fetch --prune`.
2. If the working tree has uncommitted changes, stop and ask before touching anything.
3. Switch to the branch they were working on (ask if unclear; the most recently updated remote branch is the usual guess) and `git pull --ff-only`. If it cannot fast-forward, stop and explain; never force-push or reset.
4. Rebuild and relaunch: quit any running Mnemo, then `node prototype/build.mjs && sh desktop/build.sh && open desktop/build/Mnemo.app`.

## Per-machine setup (not in Git)

- Commit email for this repo is the personal Gmail address: `git config user.email` in this clone.
- Optional signing identity "Mnemo Local Development" in each Mac's keychain keeps Screen Recording permission across rebuilds.
- Reminders data (`~/Library/Application Support/Mnemo/reminders.json`) is local to each Mac.
