# wrap-up

End a Claude Code session on purpose instead of by closing the terminal.

A session accumulates two kinds of residue. One is what it *learned* — notes that grew by appended
"update:" blocks until the top of the file contradicts the bottom, an index pointer that still
describes last week's state. The other is what it *left running* — a poller nobody stopped, a
launchd agent installed for one test, scratch files in `/tmp`, a branch with no PR.

`wrap-up` is a skill that handles both at the end of a session, and `wrapup-check`, a read-only
checker, does the mechanical part: it reports what is actually there so the model works from
findings rather than from memory of the conversation.

The rule it is built around: **it only cleans up what the session itself created.** Everything else
is listed and left alone.

```
$ wrapup-check
== Memory
[ok] home: 60 notes, index 77/200 lines, 16.9/25 KB
[!] project-repo: 163 notes, index 273 lines
     ! not linked from INDEX.md: knowledge/feedback_pre_revenue.md
     ! frontmatter knowledge/project_age_gate.md: no frontmatter
     ! … 24 more notes with frontmatter gaps (use --json)
== Dated items (overdue, or due within the window)
[!] 2026-11-09 due in 4d: home/kernel_cve.md:30
     …"check for fixes, patch, remove stopgaps", due 2026-11-09, p2
== Watcher-like processes (this session = claude pid 25164)
[!] pid 48123   2.1h  this-session: [bash tool] while :; do sleep 60; gh run view …
[-] pid 51200  14.0m  other-session: tail -F /tmp/deploy.log
== Temp paths (3 since this session started, 462 older)
[!]    12m    4.0K  /tmp/probe-out.json
-- older than this session (462 paths; not this session's)
== Schedules (9 found, 1 to look at)
[!] launchd         18m  com.me.psu-watch.plist  (created during this session)
== Git repos
[!] code/my-project  (feature/thing)
     ! untracked docs/scratch.md
     ! unpushed: feature/thing: 2 commits ahead of origin/feature/thing

NEEDS ATTENTION: memory 1, due 1, processes 1, temp 3, schedules 1, git 1
```

## Install

**As a plugin** (updates with `/plugin`, and can show a session-start notice):

```
/plugin marketplace add Miguel-Barroso/claude-wrap-up
/plugin install wrap-up@claude-wrap-up
```

**As a plain skill** (one directory, no plugin machinery):

```
git clone https://github.com/Miguel-Barroso/claude-wrap-up
cp -R claude-wrap-up/plugin/skills/wrap-up ~/.claude/skills/wrap-up
```

Either way, start it with `/wrap-up`, or just say "wrap up" / "sign off" — the skill's description
covers those. Requires Python 3.8+ and `git`.

## Platforms

macOS, Linux and Windows. CI runs the full planted-fault suite on macOS and Linux, and a
cross-platform smoke test on all three, plus the Windows launcher under `cmd.exe` and the script's
own shebang under Git Bash.

On Windows, Claude Code runs commands and hooks through **Git Bash**, where the script works as it
does anywhere else. From PowerShell or `cmd` there is no shebang, so use `wrapup-check.cmd` beside
it: it runs each of `py -3`, `python` and `python3` rather than trusting the name, because on a
Windows machine without Python those names are the Microsoft Store's install prompt.

Two things differ there, both reported rather than silently wrong:

- **Processes** come from `Win32_Process` over PowerShell instead of `ps`. The ownership walk is the
  same; process owner isn't read, so `owner_only` has nothing to filter on. If neither `pwsh` nor
  `powershell` answers, the section says so and does not claim the machine is clean.
- **Schedules** add Windows Scheduled Tasks via `schtasks`, skipping the `\Microsoft\` tree that
  ships with Windows. `schtasks` reports no creation time, so those entries are listed for you to
  match rather than flagged as this session's.

The session-start notice is the one part that needs Git Bash: the hook a plugin registers is a
POSIX command, so without Git Bash it does nothing. Point a hand-written hook at `wrapup-check.cmd`
instead if you want the notice under PowerShell.

## Configuration: usually none

With no config file the checker discovers what to check:

| What | Where it comes from |
| --- | --- |
| Memory directories | `<claude dir>/projects/*/memory` that contain notes, with `MEMORY.md` or `INDEX.md` as the index |
| Repositories | the working directory recorded in each project's newest transcript, where that directory is a main checkout |
| Temp roots | `/tmp`, plus `$TMPDIR` when it is somewhere else |
| Remote hosts | host aliases in `~/.ssh/config` (checked only when you name one) |

Run `wrapup-check --show-config` to see what that resolved to, and `--no-config` to see what it
would resolve to while ignoring any config file.

To change a default, copy [`config.example.json`](plugin/skills/wrap-up/config.example.json) to
`~/.claude/wrap-up/config.json` and **keep only the keys you change** — anything you leave out stays
discovered. The file lives outside the skill directory on purpose, so updating the skill or the
plugin cannot overwrite it. `$WRAPUP_CONFIG` overrides the location.

The one setting most people will want is a `rules` line per memory directory: free text, shown in
the checker's output, saying what that directory's conventions are. It is how you stop a model
inventing a format.

## What the checker reports

| Section | What it finds |
| --- | --- |
| `memory` | notes the index doesn't point at, index links that point at nothing, frontmatter gaps, duplicate note names, and an index grown past the size that actually loads at session start (200 lines / 25 KB) |
| `due` | a date in a note, next to a word like EXPIRES / deadline / re-check, that is overdue or close |
| `processes` | watcher-like processes — pollers, `tail -f`, `nohup` loops — each labelled `this-session`, `other-session`, `orphan` or `outside-claude` by walking its ancestry |
| `temp` | scratch paths, split into ones newer than the current session's start and ones older, with sizes |
| `schedules` | crontab entries, launchd agents, systemd user timers and Claude scheduled tasks, flagging the ones created during this session |
| `git` | per repo: uncommitted and untracked files, unpushed commits, branches whose upstream is gone, stashes, worktrees |

`--only memory,due` runs a subset. `--json` gives everything, uncapped. Exit 1 means something needs
attention; it is not a failure.

### Why ownership labelling matters

Two Claude sessions on one machine will happily stop each other's work. The checker walks each
process's ancestry to find which `claude` process owns it, so `this-session` means this one and
nothing else. Temp paths and schedules get a weaker signal — "appeared after this session started" —
which also covers a concurrent session's work, so the skill treats that as a candidate list to match
against the session's own inventory, never as permission to delete.

## The session-start notice

`wrapup-check --hook` prints SessionStart hook JSON, and only when an earlier session left something
behind:

```
wrap-up check — Left behind: 2 unindexed memories; 1 orphan watcher from an earlier session
(pid 4812, 3.1h); my-project: uncommitted work.
Run /wrap-up to tidy up, or `wrapup-check` for details.
```

It is report-only: it exits 0 even when it fails, prints a `systemMessage` the *user* sees and Claude
does not, and adds nothing to context.

Installed as a plugin it is registered but silent until you turn it on — `/config` → wrap-up →
"Show a notice when a session starts". Installed as a plain skill, add it yourself, which is itself
the opt-in:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear",
        "hooks": [
          {
            "type": "command",
            "command": "[ ! -x \"$HOME/.claude/skills/wrap-up/wrapup-check\" ] || \"$HOME/.claude/skills/wrap-up/wrapup-check\" --hook",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

A notice that says the same thing every day gets ignored, so a full run records what it found in
`~/.claude/wrap-up/state.json` (`$WRAPUP_STATE` overrides it). Later notices then separate new
findings from ones you have already been told about:

```
wrap-up check — Left behind: my-project: 2 unpushed commits.
Still open from before: 4 items, oldest first seen 2026-10-28.
```

This is the only file the checker writes. `--brief` and `--hook` never write it; `--no-save-state`
skips the write.

## Remote hosts

A session that worked on a server leaves debris there too. Name a host and the checker runs two
read-only checks over ssh — your `/tmp` entries from the last three days, and your watcher-like
processes:

```
wrapup-check --only temp --remote myserver
```

Any alias in `~/.ssh/config` works by name, with no configuration. Naming it is what authorizes
touching it: a bare `--remote` runs only hosts your config lists explicitly, never everything ssh
knows about. Every command is echoed before it runs.

A host needs a config entry only when those defaults aren't enough — a different OS, `sudo`,
containers, extra places to look:

```json
{ "remote_hosts": [ { "host": "myserver",
    "notes": "Containers are named app-<uuid> and change on every deploy; find them by filter.",
    "checks": [ { "label": "rollback copies", "cmd": "ls -1dt /root/backups/* | head -20" } ] } ] }
```

Those commands run verbatim over ssh. **The config file is executable code — never paste one you
did not write.**

## What it will not do

- Delete anything the session did not create. Older debris is offered as a list for you to approve.
- Stop another session's processes.
- Commit, push, or open a PR unless you asked for it in that session.
- Delete a rollback copy, unless it can name the verified backup that makes it redundant.
- Modify anything it reads. `git` runs with optional locks off and nothing is fetched.

## Tests

`plugin/skills/wrap-up/tests/run-tests` builds a throwaway memory tree, temp root, schedules
directory, git repo with a bare remote, a discovery-only `HOME`, and two real watcher processes;
plants a fault of every kind; asserts the checker finds exactly those; then asserts it changed
nothing it read, by comparing hashes and mtimes of every file before and after. 81 checks. Run it
after changing anything.

```
plugin/skills/wrap-up/tests/run-tests
```

## License

MIT — see [LICENSE](LICENSE).
