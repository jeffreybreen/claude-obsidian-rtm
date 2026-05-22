Sync #todo tasks between this Obsidian vault and Remember The Milk.

## Step 1: Determine the RTM list

The RTM list name is the vault name, which is the final path segment of the working directory shown in your environment context (e.g., for `/path/to/obsidian/MyVault`, the list name is `MyVault`). Do not shell out to compute this — just read the path you already have.

Use the RTM MCP tools to check whether this list exists. If it does not, create it and remember that this run is a first sync (for the Step 4 report).

## Step 2: Push unsynced tasks

Finding unsynced tasks is a grep plus a filter (ripgrep does not support lookaheads, so don't try to express "does not contain" as a single pattern):

- Grep `.md` files for the pattern `- \[ \] .*#todo` to find all unchecked `#todo` lines.
- From those results, discard any line that contains the literal string `[rtm_task_id::` — those are already synced.

For each matching line:

1. Extract the task description: the human-readable text on the line, stripping tags (`#todo`, etc.) and inline fields (`[key::value]`).
2. Extract due date if present. Recognize Tasks plugin formats: `📅 YYYY-MM-DD` or `due:: YYYY-MM-DD`.
3. Extract priority if present. Map Tasks plugin emoji to RTM priority: `⏫` = priority 1, `🔼` = priority 2, `🔽` = priority 3.
4. Note the source file path.
5. Create the task in RTM via MCP tools, in the vault-named list, passing the extracted due date and priority if present.
6. Add an RTM task note containing the source file path so tasks can be traced back.
7. Append `[rtm_task_id::XXXXX]` to the end of the Obsidian line, using the task\_id returned by RTM.

Process tasks one at a time — do not blast them in parallel.

## Step 3: Reconcile completions (both directions)

- Grep `.md` files for `\[rtm_task_id::` to find all synced lines (both `- [ ]` and `- [x]`).
- For each matching line, parse the Obsidian checkbox state, extract the task\_id, and query RTM for the task's completion status. Then:
  - RTM complete, Obsidian unchecked → change `- [ ]` to `- [x]` in Obsidian. Preserve everything else on the line.
  - RTM incomplete, Obsidian checked → call `rtm_complete_task` to mark it complete in RTM.
  - Both already agree → no-op.
  - task\_id not found in RTM (deleted or missing) → flag in the report; do not modify the Obsidian line.

Completion wins over reopening: if Obsidian is checked but RTM was reopened, we re-complete RTM rather than unchecking Obsidian.

## Step 4: Report

Summarize:

- Tasks pushed to RTM (new): count and brief list of descriptions.
- Tasks completed in RTM from Obsidian check-offs: count and brief list.
- Tasks checked off in Obsidian from RTM completions: count and brief list.
- Errors or skipped items (e.g., task\_id not found in RTM).
- Note if this was the first sync (i.e., the list was newly created).
