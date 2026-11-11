#!/usr/bin/env bash
set -uo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_environment="${NVIM_WEB_TEST_ENVIRONMENT:-$repository_root/.test-environment}"

mkdir -p "$test_environment/config" "$test_environment/data" "$test_environment/state" "$test_environment/cache"
ln -sfn "$repository_root" "$test_environment/config/nvim"

export GH_CONFIG_DIR="${GH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/gh}"
export XDG_CONFIG_HOME="$test_environment/config"
export XDG_DATA_HOME="$test_environment/data"
export XDG_STATE_HOME="$test_environment/state"
export XDG_CACHE_HOME="$test_environment/cache"
unset NVIM_APPNAME

failed_suites=0

run_suite() {
  local suite_name="$1"
  shift
  printf '\n== %s\n' "$suite_name"
  if ! "$@"; then
    failed_suites=$((failed_suites + 1))
  fi
}

cd "$repository_root" || exit 1

run_suite "project tooling detection" nvim -l tests/project_tooling_spec.lua
run_suite "install script" bash tests/install_spec.sh
run_suite "editor" nvim -l tests/editor_spec.lua

printf '\n'
if [ "$failed_suites" -eq 0 ]; then
  printf 'all suites passed\n'
  exit 0
fi
printf '%s suite(s) failed\n' "$failed_suites"
exit 1
