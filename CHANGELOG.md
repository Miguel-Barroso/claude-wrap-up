# Changelog

## 1.0.0 — 2026-11-05

First public release. The skill and its checker had been in daily private use since 2026-10-30; this
release is what came out of reading back how those runs actually went.

### Added

- **Zero configuration.** Memory directories, repositories, temp roots and ssh hosts are discovered
  — from the Claude config dir, from each project's recorded working directory, from the environment
  and from `~/.ssh/config`. A config file is now optional and overrides discovery per key.
  `--show-config` prints what resolved, `--no-config` ignores the file.
- **Config lives outside the skill**, at `~/.claude/wrap-up/config.json` or `$WRAPUP_CONFIG`, where
  updating the skill or plugin cannot overwrite it.
- **Temp paths are scoped to the session.** Paths newer than the current session's start are
  reported as this session's; older ones are listed separately and never claimed. Before this, a
  `/tmp` with hundreds of old entries flagged all of them, which is why the session-start notice had
  to leave temp out.
- **Run state.** A full run records what it found, so later notices separate new findings from ones
  already reported ("Still open from before: 4 items, oldest first seen 2026-10-28"). The only file
  the checker writes; `--brief` and `--hook` never write it.
- **A schedules section**: crontab entries, launchd agents, systemd user timers and Claude scheduled
  tasks, flagging those created during the current session. Earlier runs checked these by hand or
  not at all.
- **Memory directories can be repo-native.** Per-directory `index` filename, `recursive`,
  `require_frontmatter`, `include`/`exclude` globs, `index_limits` and `types`, so a repo's own
  `docs/agent-memory/INDEX.md` is checked by the same pass as a `MEMORY.md`. The load-limit check
  now applies only to an index that actually loads at session start.
- **Remote checks need no shell.** Any alias in `~/.ssh/config` can be checked by name with portable
  read-only defaults; a config entry is needed only when those aren't enough. Every command is
  echoed before it runs.
- `--version`, `--show-config`, `--no-config`, `--state`, `--no-save-state`, `--plugin`.
- Distribution as a Claude Code plugin, with the session-start notice registered but silent until
  the installer turns it on.

### Changed

- Long pre-existing lists are capped in the human output with a count, so one directory's backlog
  cannot bury the rest of the report. `--json` is still complete.
- The memory section names the actual index file (`not linked from INDEX.md`), and reports each
  directory's own `rules` so conventions travel with the finding.
- Tests: 45 checks → 81, all hermetic. The session age, run-state path and schedule directories are
  injectable, process-ownership assertions adapt to running outside a Claude session, and the
  read-only assertion still compares hashes and mtimes of every file before and after.
