# Changelog

## 1.2.0 — 2026-11-05

### Added

- Repository discovery falls back to the project directory's own name when a project has no
  transcript left to read a working directory from. The name is the working directory with its path
  separators replaced by `-`, which is lossy because real directory names contain hyphens too, so
  each hyphen is read both ways and the filesystem settles it: a candidate counts only if it exists
  and is a main git checkout. Found on a WSL2 install whose project directories held memory but no
  transcripts, where discovery had reported no repositories at all.

## 1.1.0 — 2026-11-05

Windows support, tested on a real Windows 11 box (PowerShell 5.1, Python 3.14, Git 2.56) and in CI
on `windows-latest`.

### Added

- `wrapup-check.cmd`, for PowerShell and `cmd`, which have no shebang. It runs each of `py -3`,
  `python` and `python3` rather than trusting the name: on a Windows machine without Python those
  names resolve to the Microsoft Store's install prompt. Exit codes pass through unchanged.
- Processes on Windows come from `Win32_Process` over PowerShell. The ownership walk — which Claude
  session owns a watcher — works the same; process owner isn't read, so `owner_only` is ignored
  there. A platform with no process list now says so and is not counted as attention, instead of
  reporting an empty list that reads as "nothing is running".
- Windows Scheduled Tasks in the schedules section via `schtasks`, skipping the `\Microsoft\` tree.
- `tests/smoke`: a cross-platform test of config, discovery, every section, exit codes and the state
  file, using only Python, git and the filesystem. CI runs it on Linux, macOS and Windows, plus the
  `.cmd` launcher under `cmd.exe` and the shebang under Git Bash.

### Fixed

- `os.getuid()` does not exist on Windows, so the temp and process sections raised `AttributeError`
  there. Owner filtering is now skipped where the OS has no uid to compare.
- Repository discovery read only POSIX working directories from transcripts, so it found nothing on
  Windows. `C:\...` paths are now recognised.
- Temp roots are discovered from `TEMP` and `TMP` as well as `TMPDIR`, so Windows has one.
- A Claude process is matched with either path separator and a `.exe`/`.cmd`/`.ps1` suffix.

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
