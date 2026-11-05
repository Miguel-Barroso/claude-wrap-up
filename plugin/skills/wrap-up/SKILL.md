---
name: wrap-up
description: End-of-session pass that consolidates memory and cleans up after this session. Rewrites notes that grew by appended rounds into current-state notes, fixes stale index pointers and other notes the session made wrong, stops this session's leftover watchers, removes schedules and temp files it created, keeps and lists rollbacks, lists uncommitted work, and reports open items. Use on "/wrap-up", "wrap up", "sign off", "signing off", "consolidate memory", "housekeeping", or "clean up before we stop".
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/wrapup-check *)
---

# Wrap-up

Two halves: consolidating memory (judgment) and housekeeping (only this session's debris).
A read-only checker does the mechanical part.

Next to this file:
- `wrapup-check`: the checker. It reports memory-index problems, dated items coming due, watcher
  processes (each labelled by owner), temp paths, leftover schedules and git state. Flags: `--json`,
  `--brief`, `--only memory,due,processes,temp,schedules,git`, `--remote [HOST…]`, `--show-config`,
  `--today YYYY-MM-DD`, `--no-sizes`. Exit 1 means something needs attention; it is not a failure.
- `config.example.json`: every setting, with what it is for. Copy it only to change a default.
- `tests/run-tests`: planted-fault tests. Run them after changing the checker.

Run it as `${CLAUDE_SKILL_DIR}/wrapup-check`.

## Configuration: usually none

With no config the checker discovers what to check — memory directories under the Claude config
dir, repositories from each project's recorded working directory, temp roots from the environment,
and host aliases from `~/.ssh/config`. A config only overrides what you name in it, per key, and
lives at `~/.claude/wrap-up/config.json` (or `$WRAPUP_CONFIG`), outside the skill, so an update
cannot overwrite it.

**Start every wrap-up by reading `--show-config` if you have not seen it this session.** It prints
the directories, repos, temp roots and hosts in effect, and each memory directory's own rules. Don't
guess at them, and don't go looking for a config file by hand.

## Ground rules

- **This session's debris only.** If the session did not create something, list it and ask before
  deleting it. When ownership is unclear, list it and leave it alone.
- **"Since this session started" is not proof of ownership.** The checker marks temp paths and
  schedules newer than this session's start, which also covers anything a *concurrent* session made
  in that window. Only act on what is in your inventory.
- **Never stop another session's processes.** The checker labels each watcher `this-session`,
  `other-session`, `orphan` (no Claude ancestor left, adopted by launchd/init) or `outside-claude`.
  Only `this-session` processes that are in your inventory are yours to stop. Orphans from earlier
  sessions: list them and ask.
- **No commits, pushes or PRs** unless the owner asked for them in this session. Repo-native memory
  is covered in step 3.
- **Exact edits.** Edit memory and indexes with exact-match replacements: the Edit tool, or a script
  that asserts exactly one match. Shell output can be filtered or abbreviated, so read with the Read
  tool before you build an `old_string`.
- **Do not start new work.** If something still needs doing, put it in the report.

## 1. Inventory the session

Work from the conversation, not from guesses. List:
- memory files written or edited, in every directory, including repo-native memory
- repos changed, branches created, PRs opened (number, state)
- remote hosts and containers written to, and what was written
- temp files and directories created, local and remote (exact paths)
- background shells, Monitor tasks, pollers, `nohup` scripts, cron/launchd/systemd entries, and
  scheduled wakeups or loops started
- rollback copies made (path, what each protects, date)
- anything mid-flight: CI running, a deploy, a PR waiting on checks, a reply awaited

If the conversation was compacted, rebuild what you can from the summary, `git reflog`, file times
and checker output, and mark those items as inferred.

## 2. Run the checker

```
${CLAUDE_SKILL_DIR}/wrapup-check            # everything
${CLAUDE_SKILL_DIR}/wrapup-check --only memory,due    # after each round of memory edits
```

Read every section against the inventory:
- **Memory:** broken links, unindexed notes, frontmatter gaps, duplicate names, and index size
  against the load limit. The limit matters because only the first 200 lines / 25 KB of an
  auto-loaded index reach context at session start; an index the checker reports as unlimited is one
  that is read on demand, not loaded.
- **Dated items:** each is either still open (it goes in the report) or done (update the note so it
  stops matching: rewrite it as history, or mark it ✅).
- **Processes:** match each `this-session` process to the inventory by PID and command.
- **Temp:** paths newer than the session start come first; older ones are listed separately and are
  not yours.
- **Schedules:** crontab entries, launchd agents, systemd user timers and Claude scheduled tasks.
  Ones created during this session are flagged; the rest are listed so you can match them.
- **Git:** per-repo state for steps 5 and 6.

Long pre-existing lists are capped in the human output — use `--json` for all of them. You may fix
pre-existing index gaps that are mechanical (a missing pointer for a note that exists). Report other
pre-existing problems; don't fix them.

## 3. Consolidate memory

**Respect each project's memory rules.** Before writing anything for a project, read its `CLAUDE.md`
(repo root), any memory README or index it points to, and that directory's `rules` in
`--show-config`. Project rules win. A common split puts durable project lessons in the repo (for
example `docs/agent-memory/knowledge/` plus a line in its `INDEX.md`, committed separately on a docs
branch via a docs-only PR, never directly on a protected branch) and only machine or operator facts
in the per-project memory directory. Look each time; don't assume.

If the project has no memory directory and no memory convention, skip to step 4 and say so in the
report — do not invent a convention or create a directory.

For every memory file written this session:

1. **Rewrite to current state** if the note grew by appended "round 2 / follow-up / update / <date>:"
   sections. Make it ONE note: what is true now, where things live (paths, hosts, URLs), what is still
   open (absolute date, owner), and reusable gotchas. History that no longer matters goes. Decisions
   and their reasons stay, including reversals and why. Keep rollback paths, undo steps, and anything
   the owner decided and does not want raised again.
2. **Update the note's `description` and its one-line pointer in the index** so neither is stale.
   Follow the index's existing pointer format. Replace that one line by exact match; never rewrite
   the index blind. If the index is near its load limit, tighten pointers and merge stale ones rather
   than letting it grow.
3. **Fix other notes this session made wrong.** Search every memory directory `--show-config` lists,
   and the project's repo memory, for the names, hosts, IPs, versions, URLs, ports, branches and
   decisions the session changed, not only the files written today. Update them, or mark them
   superseded with a link to the current note. Notes that say "pending X" when X is now done count.
4. **Verify before recording.** A fact goes in only if it was checked this session (command output,
   a file, a live endpoint); otherwise label it unverified or leave it out. Convert relative dates
   ("today", "next week", "in two weeks") to absolute YYYY-MM-DD.
5. **Follow the format in use.** One fact per file. Where the directory uses frontmatter, match it
   (`name`, `description`, `metadata.type`). Search for an existing canonical note before creating
   one, and extend it rather than duplicating it.
6. **Don't save** what the repo already records (code, git history), what only mattered to this
   session, or secrets.
7. Re-run `--only memory,due` until the memory section is clean.

**Repo-native memory:** write the file and its index line on a docs-only branch. If other sessions
may be using that checkout, use a separate `git worktree` rather than switching the shared checkout's
branch. Commit, push and open the PR only if the owner asked for that in this session. Otherwise
leave it ready and ask in the report, in one line: what, and which branch.

## 4. Housekeeping: only what this session created

- **Processes:** stop this session's leftover pollers, monitors and background shells. Use TaskStop
  for harness tasks and `kill <pid>` for scripts you started detached. Check the PID and command
  against the inventory before each kill. Never touch `other-session` processes. Orphans from earlier
  sessions: list them and ask.
- **Schedules:** remove the cron entries, launchd agents, systemd timers, scheduled tasks and
  wakeups this session created, by name. A schedule the owner asked for is not debris — if the
  session installed it deliberately, record it in memory instead and say so in the report.
- **Temp:** delete the session's temp files and directories by exact path, locally and remotely (host
  `/tmp`, container `/tmp`; container names can change on redeploy, so find containers with a
  filter). Don't delete by prefix glob, because a concurrent session may use the same prefix. List
  again afterwards to confirm.
- **Rollback copies:** keep them by default and list each with its path, date and what it protects.
  Delete one only when it is provably redundant, for example a verified backup already holds the same
  data. Name the backup and how you verified it, and say so in the report.
- **Branches:** delete local branches this session created whose work is merged. Prefer
  `git branch -d`. Use `-D` only for a squash-merged branch whose PR you confirmed merged (e.g.
  `gh pr view`). Leave every other branch alone, including other `[gone]` branches the checker lists.
- **Older debris** (temp paths from earlier sessions, orphans, gone branches you didn't create): don't
  delete it. Offer it in the report as one batch of exact paths for the owner to approve or decline.

## 5. Remote hosts

Only check a host this session actually wrote to.

```
${CLAUDE_SKILL_DIR}/wrapup-check --only memory --remote <host> …
```

`--remote` with no host runs the hosts the config lists. Naming a host runs it even when it is only
an alias in `~/.ssh/config`, using portable default checks (your `/tmp` entries from the last three
days, your watcher-like processes). **Ask the owner before the first remote check on a host in this
session** — naming a host is what authorizes touching it, so it is your call to raise, not the
checker's. Every command is echoed before it runs; read what actually ran rather than assuming.

Config `checks` are shell commands run verbatim over ssh. Treat the config as executable code: if
one looks like it writes, stop and ask.

## 6. Uncommitted work

List it per repo: changed and untracked files, unpushed commits, and which of them are this session's.
Do not commit or push unless the owner asks.

## 7. Final report

Keep it short, in plain sentences, and don't paste checker output. Sections:
- **Memory:** notes consolidated, other notes corrected (which ones, and what changed), index state.
- **Cleaned:** processes stopped, schedules removed, temp files removed (local and remote), branches
  deleted.
- **Rollbacks kept:** path, what it protects, date.
- **Waiting on you:** uncommitted work per repo; yes/no questions (a PR to open, older debris to
  delete, a host to check).
- **Open items:** what, the absolute date, and who owns it (the owner, a later session, a third party).

Close the report one of two ways:
- If nothing is running and nothing is mid-flight, say the owner can sign off.
- Otherwise, say what is still running and what happens if they sign off now.

## Run state and the session-start notice

A full run records what it found in `~/.claude/wrap-up/state.json` (or `$WRAPUP_STATE`), so a later
`--brief` can separate new findings from ones already reported. Nothing else reads or writes it, and
`--brief`/`--hook` never write. `--no-save-state` skips the write.

`wrapup-check --hook` prints SessionStart hook JSON (`systemMessage` only). It shows one to three
lines only when an earlier session left something behind, adds nothing to Claude's context, exits 0
even on failure, and changes nothing. Installed as a plugin it stays silent until the installer turns
the notice on; registered by hand in `settings.json`, that registration is the opt-in.
