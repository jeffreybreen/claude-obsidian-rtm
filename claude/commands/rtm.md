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
2. Clean up the title that becomes the RTM task name. (This never touches the Obsidian line — see Step 2 scope below.)
   - **Deterministic strip (always):** resolve wikilinks to their display text (`[[Foo|Bar]]` → `Bar`, `[[Foo]]` → `Foo`) and trim whitespace. Keep this result — it is the "original" recorded in the task note (step 7).
   - **Semantic strip + summarize (only when the cleaned text reads awkwardly as a todo title — e.g. longer than ~60 chars, or a colon/em-dash introduces a sub-clause).** Use judgment, not regex:
     - Strip entity prefixes that label *the user* or *the user's entities* the task is for (e.g. `John Doe:`, `JD:`, `[JD]`, `Doe Enterprises —`, `Trust:`, and similar). This is the user's personal RTM list, so such prefixes are noise. Recognize the pattern semantically — do **not** maintain a hardcoded list, because new entity prefixes keep appearing.
     - Rewrite as an imperative title of ≤60 chars.
     - **Reject the rewrite if it drops a number, ticker symbol, date, or proper noun present in the source** — fall back to the deterministic-strip-only text in that case.
3. Extract due date if present. Recognize the Tasks plugin emoji form `📅 YYYY-MM-DD`, the inline field `due:: YYYY-MM-DD`, or a plain `due: <date>` — where `<date>` may be ISO or natural language (`tomorrow`, `next fri`), resolved relative to today. Remove the matched marker from the title. (Don't use RTM's `^date` shortcut in the vault — Obsidian reads a trailing `^` as a block reference.)
4. Extract priority if present and map it to an RTM priority level. Recognize either RTM's own shortcuts — `!1`, `!2`, `!3` — or the Obsidian Tasks plugin emoji (`⏫` = 1, `🔼` = 2, `🔽` = 3). Remove whichever marker you matched from the title text so it doesn't show up in the RTM task name.
5. Note the source file path.
6. Create the task in RTM via MCP tools, in the vault-named list, using the cleaned-up title and passing the extracted due date and priority if present.
7. Add an RTM task note so tasks can be traced back, via `rtm_add_note`. It takes exactly two parameters, `task_id` and `content` — there is no `title`, `text`, or `note` parameter, and passing one fails with an opaque "Unknown error". Put the entire Source: / Original: block into `content` as a single multi-line string, so a terse title can always be expanded:

   ```
   rtm_add_note(task_id="XXXXX", content="Source: <relative path to .md file>\n\nOriginal:\n<full line text after deterministic strip>")
   ```
8. Append `[rtm_task_id::XXXXX]` to the end of the Obsidian line, using the task\_id returned by RTM.

Process tasks one at a time — do not blast them in parallel.

**Step 2 scope.** The title cleanup affects only the RTM task name and note; the Obsidian line keeps the user's wording verbatim, gaining only the appended `[rtm_task_id::XXXXX]`. Pushing is once-only: a line that already carries an `rtm_task_id` was filtered out above, so an edited vault line is never re-summarized and the RTM title is never updated.

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
