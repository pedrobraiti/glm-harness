# Best Practices — Python

This file complements `BEST_PRACTICES.md` with Python-specific conventions.
All rules from the global file still apply.

---

## Python Version

Always use **Python 3.12 or newer** for any project.

- 3.12 is the baseline — broad library support, stable, actively maintained.
- Do not lock to the version currently installed on the machine if a more appropriate version exists for the project.
- Avoid pre-release or alpha versions (e.g. 3.14.x alphas) in production code.

---

## Virtual Environment

Every Python project must have its own virtual environment. No exceptions.

- Create it with: `python -m venv .venv`
- The venv folder must be `.venv` (with the dot) and must be listed in `.gitignore`.
- Never install project dependencies globally on the system Python.
- Always activate the venv before running or installing anything in the project.

**On Windows (PowerShell)**, if you hit a script execution error when activating the venv, run this first:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
Then activate with:
```powershell
& ".venv\Scripts\Activate.ps1"
```

---

## Dependencies

- Keep a `requirements.txt` (or `pyproject.toml`) always up to date.
- Pin versions for production projects. Use loose ranges only for libraries.
- Separate dev dependencies (testing, linting) from runtime dependencies when possible.

---

## Tooling

Before choosing libraries or tools for a project, research what is currently the best fit for that specific use case. Do not default to a fixed stack — Python's ecosystem evolves fast and the right tool depends on the project type.

When in doubt, prefer tools that are:
- Actively maintained
- Widely adopted by the community
- Compatible with Python 3.12+

---

*Read `BEST_PRACTICES.md` first. This file only adds what is Python-specific.*
