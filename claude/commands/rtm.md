Sync #todo tasks between this Obsidian vault and Remember The Milk.

## Prerequisite: run from the vault root

This command must run from the vault root — the directory whose final path segment becomes the RTM list name (Step 1) and whose tree is scanned for tasks. A vault root is identified by a `.obsidian/` directory directly inside it.

Before anything else, confirm the working directory is a vault root:

```
test -d .obsidian && echo "vault root OK" || echo "NOT a vault root"
```

If `.obsidian/` is absent, **stop immediately and report** that the working directory is not a vault root — do not scan for tasks and do not create an RTM list. Proceeding from the wrong directory fails silently: it would scan the wrong tree and create a mis-named list.

## Prerequisite: the RTM MCP server must be authenticated

This command needs the `rtm_*` MCP tools (`rtm_add_task`, `rtm_complete_task`, `rtm_add_note`, plus list/query). Check for them **before** the discovery/scan work below. If none are available, the Remember The Milk server has lost its OAuth token (RTM expires it periodically). Do not fabricate task IDs, invent a sync, or run a full dry-run first — go straight to re-authentication.

Re-authenticate **from inside this session**. Do **not** tell the user to open a terminal or run `/mcp`: this runs headlessly (e.g. via the Claudian Obsidian plugin), so there is no REPL — and a bare `claude mcp login` in a non-TTY shell aborts before it can serve its callback (`stdin isn't a terminal`). The pattern that works is a pseudo-TTY (`script`) wrapped around a **backgrounded** login:

1. Create a private temp file for the login output — do **not** reuse a fixed, shared path like `/tmp/rtm-login.log` (predictable, collides across runs, leaks the auth URL into a world-readable file). Use your session scratchpad directory if you have one; otherwise create one with `mktemp` and note the concrete path it prints — reuse that literal path in the next steps, because shell variables do **not** persist between your separate commands:

   ```
   mktemp -t rtm-login
   ```

2. Launch the login in the background under a pseudo-TTY, writing its output to that file (`<logfile>` below is the path from step 1). Use `run_in_background` — it must not block your turn, and you must **not** kill it; it holds a `localhost` callback server open while it waits:

   ```
   script -q <logfile> claude mcp login rememberthemilk --no-browser
   ```

3. Read `<logfile>` (re-read until the line appears — it takes a moment) and surface the full authorization URL to the user verbatim, as a clickable link (the `https://www.rememberthemilk.com/oauth/authorize.rtm?...` line).

4. **Confirm the callback server is alive before telling the user to click.** Parse the port from the URL's `redirect_uri` (`http://localhost:PORT/callback`) and run `lsof -nP -iTCP:PORT -sTCP:LISTEN`. If nothing is listening, or the background task already exited non-zero, the pseudo-TTY approach has failed — do not send the user to a dead port; report it and fall back to asking them to run `claude mcp login rememberthemilk` in a real terminal (Terminal.app).

5. With the listener confirmed, tell the user to click the URL and approve in RTM. The browser redirect lands on the `localhost:PORT/callback` the process is waiting on and auth completes automatically — no paste-back. Do not touch the process; let it exit on its own.

6. Once it exits (`Authenticated with "rememberthemilk"`), the token is stored user-scoped and persists across projects. But **the `rtm_*` tools do not hot-load into this running session** — MCP tools bind at session startup. So tell the user to start a fresh session and re-run `/rtm`; no re-auth is needed. Nothing was written to the vault or RTM this run, so it is a clean re-run.

## Step 1: Determine the RTM list

The RTM list name is the vault name, which is the final path segment of the working directory shown in your environment context (e.g., for `/path/to/obsidian/MyVault`, the list name is `MyVault`). Do not shell out to compute this — just read the path you already have.

Use the RTM MCP tools to check whether this list exists. If it does not, create it and remember that this run is a first sync (for the Step 4 report).

## Step 2: Push unsynced tasks

Finding unsynced tasks is a grep plus a filter (ripgrep does not support lookaheads, so don't try to express "does not contain" as a single pattern):

- Grep `.md` files for all unchecked `#todo` lines. Run this exact command — the pattern begins with a literal `-`, so it **must** be passed with `-e` (or ripgrep treats it as a flag and the whole invocation fails). Do not reconstruct it a different way:

  ```
  rg -n -g '*.md' -g '!.obsidian/**' -e '- \[ \] .*#todo' .
  ```
- From those results, discard any line that contains the literal string `[rtm_task_id::` — those are already synced.
- Also discard any match that sits inside a fenced code block (```) or wrapped in inline backticks — these are documentation or examples (e.g. a note describing this very sync process), not live tasks. A literal reading that skips this filter will push fake example tasks into RTM.

For each matching line:

1. Extract the task description: the human-readable text on the line, stripping tags (`#todo`, etc.) and inline fields (`[key::value]`).
2. Clean up the title that becomes the RTM task name. (This never touches the Obsidian line — see Step 2 scope below.)
   - **Deterministic strip (always):** resolve **every** wikilink to its display text (`[[Foo|Bar]]` → `Bar`, `[[Foo]]` → `Foo`) and trim whitespace. The RTM task name must never contain `[[` or `]]` — verify the brackets are gone before creating the task. Keep this result — it is the "original" recorded in the task note (step 8).
   - **Semantic strip + summarize (only when the cleaned text reads awkwardly as a todo title — e.g. longer than ~60 chars, or a colon/em-dash introduces a sub-clause).** Use judgment, not regex:
     - Strip entity prefixes that label *the user* or *the user's entities* the task is for (e.g. `John Doe:`, `JD:`, `[JD]`, `Doe Enterprises —`, `Trust:`, and similar). This is the user's personal RTM list, so such prefixes are noise. Recognize the pattern semantically — do **not** maintain a hardcoded list, because new entity prefixes keep appearing.
     - Rewrite as an imperative title of ≤60 chars.
     - **Reject the rewrite if it drops a number, ticker symbol, date, or proper noun present in the source** — fall back to the deterministic-strip-only text in that case.
3. Extract due date if present. Recognize the Tasks plugin emoji form `📅 YYYY-MM-DD`, the inline field `due:: YYYY-MM-DD`, or a plain `due: <date>` — where `<date>` may be ISO or natural language (`tomorrow`, `next fri`), resolved relative to today. Remove the matched marker from the title. (Don't use RTM's `^date` shortcut in the vault — Obsidian reads a trailing `^` as a block reference.)
4. Extract priority if present and map it to an RTM priority level. Recognize either RTM's own shortcuts — `!1`, `!2`, `!3` — or the Obsidian Tasks plugin emoji (`⏫` = 1, `🔼` = 2, `🔽` = 3). Remove whichever marker you matched from the title text so it doesn't show up in the RTM task name.
5. Note the source file path.
6. Create the task in RTM via MCP tools, in the vault-named list, using the cleaned-up title and passing the extracted due date and priority if present.
7. **Immediately** append `[rtm_task_id::XXXXX]` to the end of the Obsidian line, using the task\_id returned by RTM. Do this *before* the note step below — it is the dedup marker, and writing it first guarantees that if anything fails afterward (the note step included), the next run sees the line as already synced and never re-pushes a duplicate.
8. Add an RTM task note so tasks can be traced back, via `rtm_add_note`. It takes exactly two parameters, `task_id` and `content` — there is no `title`, `text`, or `note` parameter, and passing one fails with an opaque "Unknown error". The note is the least critical artifact, so it comes last. Put the entire Source: / Original: block into `content` as a single multi-line string, so a terse title can always be expanded:

   ```
   rtm_add_note(task_id="XXXXX", content="Source: <relative path to .md file>\n\nOriginal:\n<full line text after deterministic strip>")
   ```

Process tasks one at a time — do not blast them in parallel.

**Step 2 scope.** The title cleanup affects only the RTM task name and note; the Obsidian line keeps the user's wording verbatim, gaining only the appended `[rtm_task_id::XXXXX]`. Pushing is once-only: a line that already carries an `rtm_task_id` was filtered out above, so an edited vault line is never re-summarized and the RTM title is never updated.

## Step 3: Reconcile completions (both directions)

- Grep `.md` files for all synced lines (both `- [ ]` and `- [x]`), using the same `-e` form so the pattern is never misread as a flag:

  ```
  rg -n -g '*.md' -g '!.obsidian/**' -e '\[rtm_task_id::' .
  ```
- Discard any match inside a fenced code block (```) or inline backticks — same exclusion as Step 2. The note documenting this sync process carries an example `[rtm_task_id::...]`; reconciling it would query a task that does not exist.
- Dedupe the remaining lines by task\_id: the same task\_id legitimately appears in several notes (e.g. copied across multiple daily notes). Group every line that shares a task\_id and reconcile the group as a unit — one RTM query per distinct task\_id, not one per line. If copies disagree on checkbox state, **completion wins**: treat the task as checked, complete it in RTM, and sync *all* copies in the vault to `- [x]`.
- For each distinct task\_id, parse the Obsidian checkbox state (the group's state, after the completion-wins rule above) and query RTM for the task's completion status. Then:
  - RTM complete, Obsidian unchecked → change `- [ ]` to `- [x]` in Obsidian on every copy. Preserve everything else on the line.
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
- Documentation/example lines skipped (matches inside code blocks or backticks that were not treated as live tasks): count, so a deliberate skip is never mistaken for full coverage.
- Note if this was the first sync (i.e., the list was newly created).
