# Work and Home projects

Implemented on `projects`. Publication and merge into main authorized by the user on 23 October 2026.

Click Mnemo or choose **Open Mnemo…** to open the editor. **Projects** has Work and Home spaces. Create a project, add tasks, check them off, reopen completed tasks, and rename the project. Project names may repeat across spaces but not within one space. Names and task text are rendered as text, never HTML.

Tasks default to no reminder. **+ Reminder** reveals the existing days/date/time controls. Scheduled tasks use the same persistent thought bubbles and Done / Remind Me Later behavior as standalone reminders, with `Work · Project name` or `Home · Project name` above the task. Completing the thought bubble completes the project task. Work/Home selection filters the editor only; due reminders from both spaces still announce.

The **Reminders** tab retains existing standalone reminders and also shows scheduled project tasks with project labels. Unscheduled tasks appear inside their projects and never enter the scheduler.

## Persistence and migration

Projects and tasks live in the same atomic document at `~/Library/Application Support/Mnemo/reminders.json`. Version 2 contains `version`, `projects` and `reminders`. Each task is a reminder with optional `projectID` and `dueAt`; no-date tasks have status `task`.

Legacy reminder arrays are read without rewriting. Before the first mutation in the new format, Mnemo copies the original to `reminders.before-projects.json` without overwriting an existing backup. Existing IDs, deadlines, completion state and snooze times survive migration. Unreadable or unsupported data is never silently reset. Older builds cannot read version 2, so use this or a newer build after migration.

Storage is local to this Mac. There is no account, cloud sync, automatic project synchronization between Macs, or external service integration.

## Checks

- `desktop/tests/main.swift`: legacy backup and migration, project validation and Work/Home naming, atomic task persistence, optional dates, due handling, snoozing, completion/reopening, project labels and invalid references.
- `prototype/review/check-projects.mjs`: real editor navigation, create projects, undated and dated tasks, complete/reopen, Work/Home isolation, existing reminder access and project-labelled announcements.
- Existing reminder, page and native menu checks remain applicable.

Live installation check: the signed app launched, Projects showed separate Work/Home tabs, the new-project form opened and cancelled, and existing Reminders navigation and picker remained available. Left the editor on Work. No sample projects or tasks were added to the user’s data during UI verification.

## Office handoff

Pull the latest main, rebuild with the office Mac’s existing signing identity, install and relaunch. No new dependencies. Follow AGENTS.md if local changes are present; do not overwrite them. Reminders and projects are local per Mac, so this Git handoff transfers code only.

Latest editor polish: task and standalone labels both read “Remind me to...”, tasks share reminder placeholders, project creation has a full-width name field with aligned actions beneath, and project hover highlights have rounded corners and inset text.

Follow-ups: project archive/delete and cross-Mac data synchronization are not implemented. Physical multi-display/Spaces verification and energy measurements remain outstanding as documented in native-mac.md.
