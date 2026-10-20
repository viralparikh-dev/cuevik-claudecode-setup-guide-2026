# Claude Code Setup Guide (Windows, 2026)

Setup checklist and approved skills for developers using Claude Code on Windows, through the **VS Code extension** and the **Claude desktop app**.

## What's in this repo

| File | Purpose |
|---|---|
| `ClaudeCode-2026Setup-n-Skills.docx` | The guide: onboarding checklist, approved skills, how to install them, and a VS Code vs desktop app quick reference. |
| `Install-ClaudeSkills.ps1` | Installs every approved skill in one run. |

## How to use

1. **Read the guide first.** Work through the onboarding checklist (accounts, Git, VS Code, desktop app).
2. **Run the install script** from PowerShell in this folder:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Install-ClaudeSkills.ps1
   ```

3. **Restart** VS Code and the Claude desktop app, or run `/reload-plugins` in open sessions.
4. In each front-end project, run `/impeccable init` once in the Claude prompt box.

## What the script needs

| Requirement | Needed for | If missing |
|---|---|---|
| Git for Windows | Adding plugin marketplaces | Script stops |
| Claude Code CLI (`claude`) | Installing plugins | Script installs it |
| Node.js (`npx`) | Cloudflare Security Audit skill | Skipped with a warning |
| uv | Graphify | Skipped with a warning |
| Python 3.9+ as `python3` | Claude Security plugin | Warning only |

The script is safe to run again: anything already installed is skipped. It ends with a summary showing what was installed, skipped or failed.

## Before you run it

- Review the script; the full listing is also in the guide's appendix.
- Most skills are community-built and run with your agent's permissions. Skills marked **(official)** in the guide are built by Anthropic.
- The Cloudflare step may ask you to confirm in the terminal.
