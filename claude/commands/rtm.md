Sync #todo tasks between this Obsidian vault and Remember The Milk.

## Step 1: Determine the RTM list

The RTM list name is the current working directory name (the vault name). Use the RTM MCP tools to check whether this list exists. If it does not, create it and remember that this run is a first sync (for the Step 4 report).

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

## Step 3: Echo completions

- Grep `.md` files for the pattern `- \[ \] .*#todo.*\[rtm_task_id::` to find synced-but-unchecked lines.
- For each matching line, extract the task\_id and query RTM for the task's completion status.
  - If the task is complete in RTM, change `- [ ]` to `- [x]` in Obsidian. Preserve everything else on the line.
  - If the task\_id is not found in RTM (deleted or missing), flag it in the report but do not modify the Obsidian line.

## Step 4: Report

Summarize:

- Tasks pushed to RTM: count and brief list of descriptions.
- Tasks checked off from RTM completions: count and brief list.
- Errors or skipped items (e.g., task\_id not found in RTM).
- Note if this was the first sync (i.e., the list was newly created).
