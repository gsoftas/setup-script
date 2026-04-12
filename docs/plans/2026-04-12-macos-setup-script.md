# macOS Setup Script Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the pasted legacy macOS laptop setup script with a modern, smaller, more resilient version.

**Architecture:** Create a single Bash script that bootstraps Homebrew, installs a curated set of formulas and casks one item at a time, configures `mise` for language management, and optionally skips Mac App Store installs via a CLI flag. The script should treat individual package failures as non-fatal, record them, and print a summary at the end.

**Tech Stack:** Bash, Homebrew, `mas`, `mise`, standard macOS command-line tools.

---

### Task 1: Create the replacement script

**Files:**
- Create: `setup-macos.sh`

**Step 1: Write the failing test**

Use syntax validation as the initial executable guard for this standalone shell script.

**Step 2: Run test to verify it fails**

Run: `bash -n setup-macos.sh`
Expected: fail because the file does not exist yet.

**Step 3: Write minimal implementation**

Create a Bash script that:
- checks for macOS
- supports `--skip-app-store`
- bootstraps Homebrew
- installs formulas, casks, and optional App Store apps individually
- installs and activates `mise`
- installs global `python`, `node`, and `ruby` toolchains with `mise`
- logs failures without aborting the full run

**Step 4: Run test to verify it passes**

Run: `bash -n setup-macos.sh`
Expected: PASS with no syntax errors.

### Task 2: Verify behavior and safety guards

**Files:**
- Modify: `setup-macos.sh`

**Step 1: Write the failing test**

Use a shell lint pass as the next guardrail.

**Step 2: Run test to verify it fails**

Run: `shellcheck setup-macos.sh`
Expected: identify any quoting, portability, or control-flow issues.

**Step 3: Write minimal implementation**

Fix any shellcheck findings while keeping the script simple.

**Step 4: Run test to verify it passes**

Run: `shellcheck setup-macos.sh`
Expected: no actionable warnings for the shipped script.

### Task 3: Final verification

**Files:**
- Verify: `setup-macos.sh`

**Step 1: Run the final checks**

Run:
- `bash -n setup-macos.sh`
- `shellcheck setup-macos.sh`

**Step 2: Confirm runtime usage help**

Run: `bash setup-macos.sh --help`
Expected: usage text prints without executing installs.
