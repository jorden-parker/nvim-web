#!/usr/bin/env bash
set -uo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sandbox_directory="$(mktemp -d)"
trap 'rm -rf "$sandbox_directory"' EXIT

failure_count=0

check() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'ok   %s\n' "$description"
  else
    failure_count=$((failure_count + 1))
    printf 'FAIL %s\n' "$description"
  fi
}

has_single_backup_containing() {
  local backup_glob="$1" marker_file="$2" backups
  backups=("$backup_glob"*)
  [ "${#backups[@]}" -eq 1 ] && [ -f "${backups[0]}/$marker_file" ]
}

source_repository="$sandbox_directory/source"

snapshot_working_tree_as_repository() {
  mkdir -p "$source_repository"
  (cd "$repository_root" && git ls-files --cached --others --exclude-standard -z | xargs -0 tar -cf -) \
    | tar -xf - -C "$source_repository"
  git -C "$source_repository" init --quiet --initial-branch main
  git -C "$source_repository" add --all
  git -C "$source_repository" -c user.name=installer-spec -c user.email=installer-spec@example.invalid \
    commit --quiet --message snapshot
}

run_installer() {
  HOME="$sandbox_directory/home" \
    XDG_CONFIG_HOME="$sandbox_directory/home/.config" \
    XDG_DATA_HOME="$sandbox_directory/home/.local/share" \
    XDG_STATE_HOME="$sandbox_directory/home/.local/state" \
    XDG_CACHE_HOME="$sandbox_directory/home/.cache" \
    NVIM_WEB_REPOSITORY="file://$source_repository" \
    NVIM_WEB_SKIP_PLUGIN_SYNC=1 \
    bash "$repository_root/install.sh" "$@"
}

config_directory="$sandbox_directory/home/.config/nvim"
data_directory="$sandbox_directory/home/.local/share/nvim"

mkdir -p "$config_directory" "$data_directory"
printf 'previous config\n' > "$config_directory/previous-init.lua"
printf 'previous data\n' > "$data_directory/previous-data.txt"

check "the working tree is snapshotted as the install source" snapshot_working_tree_as_repository

check "the installer exits successfully over an existing config" run_installer
check "the new config is in place" test -f "$config_directory/init.lua"
check "the new config is a git checkout" test -d "$config_directory/.git"
check "the previous config is gone from the config directory" test ! -e "$config_directory/previous-init.lua"
check "the previous config is kept in one timestamped backup" \
  has_single_backup_containing "$config_directory.backup-" previous-init.lua
check "plugin data is left alone by default" test -f "$data_directory/previous-data.txt"

check "the installer exits successfully with --fresh" run_installer --fresh
check "--fresh moves plugin data into a backup" \
  has_single_backup_containing "$data_directory.backup-" previous-data.txt
check "--fresh leaves no plugin data behind" test ! -e "$data_directory/previous-data.txt"

rm -rf "${sandbox_directory:?}/home"
check "the installer works when no config exists yet" run_installer
check "a fresh machine gets the config" test -f "$config_directory/init.lua"

stub_directory="$sandbox_directory/stub-bin"
state_directory="$sandbox_directory/home/.local/state/nvim"
installer_output="$sandbox_directory/installer-output.txt"

write_neovim_stub() {
  mkdir -p "$stub_directory"
  cat > "$stub_directory/nvim" <<'STUB'
#!/usr/bin/env bash
if [ "${1:-}" = "--version" ]; then
  printf 'NVIM v0.12.4\n'
  exit 0
fi
printf 'noisy plugin manager output\n'
printf 'tool download interrupted\n' >&2
exit "${NEOVIM_STUB_EXIT_CODE:-0}"
STUB
  chmod +x "$stub_directory/nvim"
}

run_installer_with_plugin_install() {
  PATH="$stub_directory:$PATH" \
    HOME="$sandbox_directory/home" \
    XDG_CONFIG_HOME="$sandbox_directory/home/.config" \
    XDG_DATA_HOME="$sandbox_directory/home/.local/share" \
    XDG_STATE_HOME="$sandbox_directory/home/.local/state" \
    XDG_CACHE_HOME="$sandbox_directory/home/.cache" \
    NVIM_WEB_REPOSITORY="file://$source_repository" \
    bash "$repository_root/install.sh" > "$installer_output" 2>&1
}

is_absent_from_output() {
  ! grep -q "$1" "$installer_output"
}

write_neovim_stub
check "the installer exits successfully when it installs plugins" run_installer_with_plugin_install
check "plugin manager output stays out of the terminal" is_absent_from_output "noisy plugin manager output"
check "plugin manager errors stay out of the terminal" is_absent_from_output "tool download interrupted"
check "plugin manager output is kept in a log file" \
  grep -q "noisy plugin manager output" "$state_directory/nvim-web-install.log"
check "plugin manager errors are kept in the log file" \
  grep -q "tool download interrupted" "$state_directory/nvim-web-install.log"

export NEOVIM_STUB_EXIT_CODE=1
check "the installer still succeeds when the plugin install fails" run_installer_with_plugin_install
check "a failed plugin install points at the log file" grep -q "nvim-web-install.log" "$installer_output"
unset NEOVIM_STUB_EXIT_CODE

if [ "$failure_count" -eq 0 ]; then
  printf 'all checks passed\n'
  exit 0
fi
printf '%s check(s) failed\n' "$failure_count"
exit 1
