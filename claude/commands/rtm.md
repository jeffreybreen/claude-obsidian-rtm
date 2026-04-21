Sync #todo tasks between this Obsidian vault and Remember The Milk.

## Step 1: Determine the RTM list

The RTM list name is the current working directory name (the vault name). Use the RTM MCP tools to check whether this list exists. If it does not, create it.

## Step 2: Push unsynced tasks

Search all `.md` files in the vault for lines matching this pattern:

- Unchecked checkbox (`- [ ]`)
- Contains `#todo`
- Does NOT contain `[rtm_task_id::`

Skip any line that is already checked (`- [x]`).

For each matching line:

1. Extract the task description: the human-readable text on the line, stripping tags (`#todo`, etc.) and inline fields (`[key::value]`).
2. Extract due date if present. Recognize Tasks plugin formats: `📅 YYYY-MM-DD` or `due:: YYYY-MM-DD`.
3. Extract priority if present. Map Tasks plugin emoji to RTM priority: `⏫` = priority 1, `🔼` = priority 2, `🔽` = priority 3.
4. Note the source file path.

Create the task in RTM via MCP tools, in the vault-named list. Add an RTM task note with the source file path so tasks can be traced back.

Write the returned task\_id back onto the Obsidian line by appending `[rtm_task_id::XXXXX]` at the end of the line.

Process tasks one at a time. Do not blast them in parallel.

## Step 3: Echo completions

Search all `.md` files for lines that are:

- Unchecked (`- [ ]`)
- Contain `#todo`
- Contain `[rtm_task_id::`

For each matching line, extract the task\_id and query RTM for the task's completion status.

- If the task is complete in RTM, change `- [ ]` to `- [x]` in Obsidian. Preserve everything else on the line.
- If the task\_id is not found in RTM (deleted or missing), flag it in the report but do not modify the Obsidian line.

## Step 4: Report

Summarize:

- Tasks pushed to RTM: count and brief list of descriptions.
- Tasks checked off from RTM completions: count and brief list.
- Errors or skipped items (e.g., task\_id not found in RTM).
- Note if this was the first sync (i.e., the list was newly created).
