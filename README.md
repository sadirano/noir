# Noir

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Noir is the starting point for a fresh Windows machine: one interactive setup
script (`noir.ps1`) plus a small set of lightweight CMD utilities designed to be
launched with minimal keystrokes via **Win + R**.

## Install

One-liner on a fresh machine — installs to `%LOCALAPPDATA%\noir` (override with
the `NOIR_DIR` environment variable) and launches the setup menu:

**Windows PowerShell**

```powershell
irm https://sadirano.com.br/noir | iex
```

**Windows CMD**

```
curl -fsSL https://sadirano.com.br/noir.cmd -o %TEMP%\noir.cmd && %TEMP%\noir.cmd && del %TEMP%\noir.cmd
```

The short URLs are redirects on sadirano.com.br; the underlying files are
served from this repo and always work directly:

```powershell
irm https://raw.githubusercontent.com/sadirano/noir/main/install/install.ps1 | iex
```

## Setup: noir.ps1

Run it on a fresh machine (plain Windows PowerShell 5.1 is fine):

```powershell
.\noir.ps1
```

It opens an interactive checklist of every setup step — navigate with Up/Down
(or J/K), Space toggles a step, A toggles all, Enter runs the selection, Q
quits. Steps are color-coded: Visual (magenta), Application/Programs (yellow),
Configuration (cyan). Noir probes the machine first: steps it detects as
already set up are marked `ok` and start unchecked, everything missing starts
checked — so on any machine, Enter runs exactly what's absent. Re-running a
package step updates it instead of reinstalling.

Other modes:

```powershell
.\noir.ps1 -Yolo     # accept absolutely everything, no checklist
.\noir.ps1 -Doctor   # report what's already set up; changes nothing
```

Highlights of what the steps cover:

- **Visual** — dark mode, hidden desktop icons, taskbar cleanup/auto-hide,
  solid black wallpaper.
- **Application** — Scoop + the sadirano bucket (nix, which brings Neovim),
  clink wired to the core doskey macros, standalone Neovim/bat/fzf/ripgrep-all
  picks, Windows Terminal + Nerd Fonts, Node.js, Python, C build tools,
  ripgrep/fd, PowerShell 7 + PowerToys, OneDrive removal, Windhawk.
- **Configuration** — nag-screen/ad-personalization opt-outs, **noir-path**
  (puts Noir's `core\` and `user\` folders on PATH), **core-macros** (registers the
  doskey macros for cmd and the `q`/`cc` functions for PowerShell),
  **noir-alias** (points nix's `noir` alias at this install), Neovim
  config and dotfiles clones, Windows Terminal preferences, git identity.

## Core commands

The `core\` folder holds the CMD utilities, runnable from Win + R (or any
shell) once `noir-path` has run:

| Command | What it does |
|---|---|
| `adm [cmd] [args]` | Elevation primitive. `call adm "%~f0"` at the top of a script re-launches it elevated; bare `adm` opens an elevated cmd. |
| `env` | Opens the Environment Variables editor, elevated. |
| `h` | Hibernates the machine (`shutdown /h`). |
| `hosts` | Opens the hosts file elevated, honoring `%EDITOR%` (falls back to Notepad). |
| `restart` | Kills Explorer, waits for a keypress, restores it. |
| `u [name[.ext]]` | Creates/edits a personal script in `user\` (see below). |

Macros registered by the **core-macros** step (cmd via `doskey.mac`,
PowerShell via `core.ps1`): `cc` copies the current directory to the
clipboard, `q` exits the shell.

## User scripts: the `user\` folder

`user\` is your personal script bin. The **noir-path** step puts it on PATH, so
anything you drop there runs from anywhere — including Win + R. Its contents
are yours alone and stay out of git.

Create or edit a script with `u`:

```
u deploy        -> edits user\deploy.cmd (default extension)
u notes.ps1     -> edits user\notes.ps1  (given extension wins)
u               -> opens the user\ folder in the editor
```

`u` opens the file via [nix](https://github.com/sadirano/nix)'s `e` command
(`e user@noir ...`), so the `noir` alias must point at your Noir install —
the **noir-alias** setup step registers it for you.

## Tests

```
tests\run_tests.cmd
```

Runs every suite: structural and dry-run tests for the elevation primitive
(no UAC prompts), structural checks for the other core commands and macros,
and noir.ps1 checks — parse, step-table shape via the AST, and a read-only
`-Doctor` run. Suites also run individually (`tests\test_adm.cmd`, ...).

## Dependencies

- **nix** — used by `u` for alias-based editing.

## History

Noir is old — older than this repo. It began around 2016–2017 as a handful of
crude `.cmd` files living in `%userprofile%`, launched from Win + R, one script
calling another. By March 2017 it had a name and a Bitbucket repo (later
reclaimed by the platform for inactivity; a single photograph survives). It was
reborn on GitHub in 2023 as a Python task dispatcher whose README already
stated the dream: *"fast and easy replication on other computers."*

Over the years Noir dispersed into specialized children — **Core** (the
elevation and shell utilities) and **Omni** (folder navigation) — and lay
fallow while they carried the torch. This repo is the homecoming: Core has
been absorbed back in as `core\`, Omni retired in favor of
[nix](https://github.com/sadirano/nix), and Noir returns to what it was always
meant to be — the one command that turns a fresh Windows machine into home.

The full saga, reconstructed commit by commit back to the 2017 genesis, lives
in [noir_chronicles](https://github.com/sadirano/noir_chronicles).

## License

MIT — see [LICENSE](LICENSE).
