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

Project detail includes Delete Project, followed by an inline confirmation. Confirming permanently removes the project and all its tasks, including scheduled reminders, in one native atomic save; other projects and standalone reminders remain. Cancelling changes nothing. Cross-Mac data synchronization and project archiving are not implemented. Physical multi-display/Spaces verification and energy measurements remain outstanding as documented in native-mac.md.

Project list tidy-up on `tidy-project-list`: compact rows show the project name, a badge for open tasks only, and a decorative chevron. Empty projects omit the badge. Task previews are removed; screen-reader labels retain the open-task count, and keyboard focus highlights the full row. Project navigation and count updates after task completion are covered by the editor checks.

## Project view design — 23 October

The project and its tasks form the main visual hierarchy. The compact composer sits below the project title and above pending tasks, keeping capture accessible as the list grows; reminder scheduling expands only when requested. Undated project tasks omit redundant “No reminder” labels, row actions use quiet text controls, and keyboard focus remains explicit. DOM order follows the same hierarchy; standalone reminders retain capture-first ordering. The existing dark plum palette is retained with softer boundaries and a restrained type/spacing scale.

This is an interpretation of Christopher Alexander’s emphasis on coherent wholes and local adaptation, not a claim that particular screen layouts were prescribed by him. Source: https://www.patternlanguage.com/archive/ieee.html . Refine through actual use, especially long project/task names, many tasks and expanded scheduling.

## Item notes and time wheels — 23 October

Tasks and standalone reminders accept optional plain-text notes (up to 10,000 characters). Notes are always visible as an optional text area in the editor and as plain text under a saved item, and are restored when editing. Empty notes are omitted from native storage; older documents decode without changes. Notes remain attached through Done, reopening and snoozing. Native persistence checks cover reload, completion, clearing and length validation; project editor checks cover entry, safe text rendering and editing.

Time wheels now update the selected time and summary without rebuilding the calendar during scroll. Native scroll momentum is retained; snapping waits for scrollend, with a 250 ms idle fallback. Programmatic scroll synchronization is ignored when already at the selected row. Trackpad feel still requires live verification.

Removed persistent success text such as “Task added.” The newly displayed item provides save feedback; validation and save errors still appear when needed.

## Usage location

Native Settings → Use Mnemo at offers Home, Work and Both. Home or Work hides the space tabs and filters the project list to that space; Both restores the tabs. The preference is stored locally per Mac as `usageLocation` and defaults to Both for existing installations. All projects remain saved, and scheduled reminders from either space still announce. Changing the preference does not clear an editor draft; an open project can be finished before returning to the filtered list.

Project titles now act as rename controls: click (or keyboard-activate) the title to edit it in place, Enter/Save commits and Escape/Cancel leaves it unchanged. Renaming preserves the task draft. Notes use the plain “Notes” label. The user selected font study B: Avenir Next throughout the editor, with Avenir and sans-serif fallbacks.

Navigation uses the top Projects tab to return from any project to its list, including when already selected. Removed the duplicate list heading and secondary back button; the list creation action reads “+ New” (accessible name “New project”).
