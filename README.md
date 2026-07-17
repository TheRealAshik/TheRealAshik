# TheRealAshik — Script Launcher

A collection of PowerShell utility scripts with a terminal-based launcher.
Run any script directly from GitHub — no manual downloading needed.

---

## Quick Start

Open **PowerShell** and paste one of these:

### Open the interactive TUI menu
```powershell
irm https://raw.githubusercontent.com/TheRealAshik/TheRealAshik/main/run.ps1 | iex
```

### Run a specific script directly
```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/TheRealAshik/TheRealAshik/main/run.ps1))) -Script force_delete
```

### List all available scripts
```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/TheRealAshik/TheRealAshik/main/run.ps1))) -List
```

---

## TUI Launcher Controls

| Key           | Action              |
|---------------|---------------------|
| `Up` / `Down` | Navigate scripts    |
| `Enter`       | Run selected script |
| `Q` / `Esc`   | Quit                |

---

## Available Scripts

| Name           | Description                                             |
|----------------|---------------------------------------------------------|
| `force_delete` | Forcefully delete a locked file or folder (runs as Admin) |

---

## Adding a New Script

1. Add your `.ps1` file to the `scripts/` folder.
2. Register it in **both** `launcher.ps1` and `run.ps1` under the `$Scripts` / `$Registry` sections:

**launcher.ps1**
```powershell
@{ Name = "My Script"; Path = "scripts/my_script.ps1"; Desc = "Does something cool" }
```

**run.ps1**
```powershell
"my_script" = @{ Path = "scripts/my_script.ps1"; Desc = "Does something cool" }
```

3. Push to `main` — it's instantly available to run remotely.

---

## How It Works

- `run.ps1` — entry point; fetches and runs scripts by name, or launches the TUI
- `launcher.ps1` — interactive arrow-key menu that streams scripts from raw GitHub URLs
- Scripts run in memory via `Invoke-Expression` — nothing is saved to disk
