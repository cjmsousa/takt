#!/usr/bin/env bash
# Takt preflight: checks prerequisites before a Takt skill does any work.
#
# Usage:   preflight.sh <check> [<check> ...]
# Checks:  node | openspec | gh | git | github-remote | openspec-init | takt-init
#
# Output: one line per check, pipe-separated, for the calling skill to present:
#   OK|<check>|<detail>
#   FAIL|<check>|<problem>|<why Takt needs it>|<fix>
# The last line is a summary:
#   SUMMARY|PASS|<n> checks
#   SUMMARY|FAIL|<failed> of <n> checks failed
# Exit code: 0 if every check passed, 1 otherwise.
#
# Every check always runs, so the user sees everything missing at once.
# openspec-init also compares the installed OpenSpec CLI with the version that
# generated the repo's OpenSpec skills (OpenSpec's own `generatedBy` stamp in
# .claude/skills/openspec-*/SKILL.md). Takt keeps no version pin of its own.
#
# Portable to macOS's default bash 3.2: no associative arrays, no sort -V.

set -u

MIN_NODE="20.19.0"
OS="$(uname -s 2>/dev/null || echo unknown)"

total=0
failed=0

ok()   { total=$((total + 1)); echo "OK|$1|$2"; }
fail() { total=$((total + 1)); failed=$((failed + 1)); echo "FAIL|$1|$2|$3|$4"; }

# version_ge A B -> true if A >= B (numeric, dot-separated)
version_ge() {
  local a b i x y
  IFS=. read -r -a a <<< "$1"
  IFS=. read -r -a b <<< "$2"
  for i in 0 1 2; do
    x="${a[$i]:-0}"; y="${b[$i]:-0}"
    x="${x%%[!0-9]*}"; y="${y%%[!0-9]*}"
    x="${x:-0}"; y="${y:-0}"
    if [ "$x" -gt "$y" ]; then return 0; fi
    if [ "$x" -lt "$y" ]; then return 1; fi
  done
  return 0
}

install_hint() {
  # $1 = brew formula, $2 = generic instruction
  if [ "$OS" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
    echo "Run: brew install $1"
  else
    echo "$2"
  fi
}

check_node() {
  local why="OpenSpec runs on Node."
  if ! command -v node >/dev/null 2>&1; then
    fail node "Node.js is not installed." "$why" \
      "$(install_hint node "Install Node.js $MIN_NODE or newer from https://nodejs.org (or with nvm).")"
    return
  fi
  local v; v="$(node --version 2>/dev/null | sed 's/^v//')"
  if version_ge "$v" "$MIN_NODE"; then
    ok node "Node.js $v"
  else
    fail node "Node.js $v is too old; OpenSpec needs $MIN_NODE or newer." "$why" \
      "$(install_hint node "Upgrade Node.js to $MIN_NODE or newer (e.g. nvm install 22).") (then check with: node --version)"
  fi
}

check_openspec() {
  local why="Takt uses OpenSpec as its spec engine (init, explore, propose, apply, archive)."
  if ! command -v openspec >/dev/null 2>&1; then
    fail openspec "The OpenSpec CLI is not installed." "$why" \
      "Run: npm install -g @fission-ai/openspec@latest"
    return
  fi
  local v; v="$(installed_openspec_version)"
  ok openspec "OpenSpec ${v:-(unknown version)}"
}

installed_openspec_version() {
  openspec --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1
}

check_gh() {
  local why="Takt uses the GitHub CLI to create issues, labels, secrets and PRs."
  if ! command -v gh >/dev/null 2>&1; then
    fail gh "The GitHub CLI (gh) is not installed." "$why" \
      "$(install_hint gh "Install it from https://cli.github.com"), then run: gh auth login"
    return
  fi
  local user
  if ! gh auth status >/dev/null 2>&1; then
    fail gh "The GitHub CLI is installed but not signed in." "$why" "Run: gh auth login"
    return
  fi
  user="$(gh api user --jq .login 2>/dev/null || true)"
  ok gh "GitHub CLI signed in${user:+ as $user}"
}

check_git() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ok git "Git repo at $(git rev-parse --show-toplevel)"
  else
    fail git "This folder is not a git repository." \
      "Takt works on one project repo at a time." \
      "Open Claude Code in your project's folder (or run: git init), then try again."
  fi
}

check_github_remote() {
  local why="Changes become GitHub issues, so the repo must live on GitHub."
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fail github-remote "No git repository, so no GitHub remote." "$why" \
      "Open Claude Code in your project's folder, then try again."
    return
  fi
  local url; url="$(git remote get-url origin 2>/dev/null || true)"
  case "$url" in
    *github.com*) ok github-remote "origin → $url" ;;
    "") fail github-remote "This repo has no 'origin' remote." "$why" \
          "Create the repo on GitHub and push: gh repo create --source . --push" ;;
    *)  fail github-remote "origin points to $url, not GitHub." "$why" \
          "Point origin at a GitHub repo: git remote set-url origin <github-url>" ;;
  esac
}

check_openspec_init() {
  local root; root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  if [ ! -d "$root/openspec" ]; then
    fail openspec-init "OpenSpec is not set up in this repo (no openspec/ folder)." \
      "Specs and changes live in openspec/, and OpenSpec's commands are installed per repo." \
      "Run: /takt:setup"
    return
  fi
  # Versions that generated this repo's OpenSpec skills, e.g. "1.17.0".
  local stamps
  stamps="$(cat "$root"/.claude/skills/openspec-*/SKILL.md 2>/dev/null \
    | sed -n 's/^[[:space:]]*generatedBy:[[:space:]]*"\{0,1\}\([0-9][0-9.]*\)"\{0,1\}.*/\1/p' \
    | sort -u)"
  if [ -z "$stamps" ]; then
    ok openspec-init "openspec/ found (no OpenSpec skill version stamp to compare)"
    return
  fi
  local have; have="$(installed_openspec_version)"
  if [ -z "$have" ]; then
    ok openspec-init "openspec/ found (skills generated by OpenSpec $(echo $stamps))"
    return
  fi
  local why="The OpenSpec skills in this repo are generated for one CLI version; with a different CLI they can call commands or expect output it doesn't have."
  if [ "$(echo "$stamps" | wc -l | tr -d ' ')" -gt 1 ]; then
    fail openspec-init "This repo's OpenSpec skills were generated by different OpenSpec versions ($(echo $stamps))." "$why" \
      "Run: openspec update, then commit the changed files."
    return
  fi
  if [ "$stamps" = "$have" ]; then
    ok openspec-init "openspec/ found (skills match OpenSpec $have)"
  elif version_ge "$have" "$stamps"; then
    fail openspec-init "Your OpenSpec CLI ($have) is newer than the one that set up this repo ($stamps)." "$why" \
      "Run: openspec update, then commit the changed files."
  else
    fail openspec-init "Your OpenSpec CLI ($have) is older than the one that set up this repo ($stamps)." "$why" \
      "Run: npm install -g @fission-ai/openspec@$stamps"
  fi
}

check_takt_init() {
  local why="The factory needs its labels and workflow in this repo."
  if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
    fail takt-init "Can't check Takt labels without a signed-in GitHub CLI." "$why" \
      "Fix the gh check first, then try again."
    return
  fi
  if gh label list --limit 200 --json name --jq '.[].name' 2>/dev/null | grep -qx 'takt:propose'; then
    ok takt-init "Takt labels found"
  else
    fail takt-init "Takt isn't set up in this repo (no takt:propose label)." "$why" \
      "Run: /takt:setup"
  fi
}

if [ "$#" -eq 0 ]; then
  echo "usage: preflight.sh <check> [<check> ...]" >&2
  echo "checks: node openspec gh git github-remote openspec-init takt-init" >&2
  exit 2
fi

for c in "$@"; do
  case "$c" in
    node)          check_node ;;
    openspec)      check_openspec ;;
    gh)            check_gh ;;
    git)           check_git ;;
    github-remote) check_github_remote ;;
    openspec-init) check_openspec_init ;;
    takt-init)     check_takt_init ;;
    *) fail "$c" "Unknown check '$c'." "This is a bug in the calling skill." \
         "Report it in the takt repo." ;;
  esac
done

if [ "$failed" -eq 0 ]; then
  echo "SUMMARY|PASS|$total checks"
  exit 0
fi
echo "SUMMARY|FAIL|$failed of $total checks failed"
exit 1
