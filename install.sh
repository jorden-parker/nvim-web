#!/usr/bin/env bash
set -euo pipefail

repository_url="${NVIM_WEB_REPOSITORY:-https://github.com/jorden-parker/nvim-web.git}"
config_directory="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
data_directory="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
state_directory="${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
cache_directory="${XDG_CACHE_HOME:-$HOME/.cache}/nvim"
plugin_install_log="$state_directory/nvim-web-install.log"
backup_suffix=".backup-$(date +%Y%m%d-%H%M%S)"
minimum_neovim_version="0.11.2"
should_reset_plugin_data=false

print_usage() {
  cat <<USAGE
Usage: install.sh [--fresh]

Replaces the Neovim config at $config_directory with nvim-web.
The existing config is moved to a timestamped backup next to it first.

  --fresh   Also move Neovim's plugin data, state and cache into backups,
            so every plugin and tool is installed from scratch.
  --help    Show this message.
USAGE
}

fail() {
  printf 'install.sh: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required but was not found on PATH."
}

warn_when_missing() {
  local command_name="$1" purpose="$2"
  command -v "$command_name" >/dev/null 2>&1 || printf 'Optional: %s is missing (%s).\n' "$command_name" "$purpose"
}

require_supported_neovim() {
  local installed_version oldest_version
  installed_version="$(nvim --version | head -n 1 | sed -E 's/^NVIM v([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
  oldest_version="$(printf '%s\n%s\n' "$minimum_neovim_version" "$installed_version" | sort -t. -k1,1n -k2,2n -k3,3n | head -n 1)"
  [ "$oldest_version" = "$minimum_neovim_version" ] \
    || fail "Neovim $minimum_neovim_version or newer is required, found $installed_version."
}

unused_backup_path() {
  local original_path="$1" candidate_path attempt=1
  candidate_path="$original_path$backup_suffix"
  while [ -e "$candidate_path" ] || [ -L "$candidate_path" ]; do
    candidate_path="$original_path$backup_suffix-$attempt"
    attempt=$((attempt + 1))
  done
  printf '%s' "$candidate_path"
}

back_up() {
  local original_path="$1" backup_path
  if [ ! -e "$original_path" ] && [ ! -L "$original_path" ]; then
    return 0
  fi
  backup_path="$(unused_backup_path "$original_path")"
  mv "$original_path" "$backup_path"
  printf 'Backed up %s\n       to %s\n' "$original_path" "$backup_path"
}

install_plugins() {
  if [ -n "${NVIM_WEB_SKIP_PLUGIN_SYNC:-}" ]; then
    return 0
  fi
  mkdir -p "$state_directory"
  printf 'Installing plugins (this can take a minute)...\n'
  if nvim --headless "+Lazy! restore" +qa >"$plugin_install_log" 2>&1; then
    printf 'Plugins installed. Language servers and formatters install on the first launch.\n'
  else
    printf 'Plugin install did not finish cleanly. See %s, then open nvim and run :Lazy.\n' "$plugin_install_log"
  fi
}

for argument in "$@"; do
  case "$argument" in
    --fresh) should_reset_plugin_data=true ;;
    -h | --help)
      print_usage
      exit 0
      ;;
    *)
      print_usage >&2
      fail "unknown option: $argument"
      ;;
  esac
done

require_command git
require_command nvim
require_supported_neovim

back_up "$config_directory"
if [ "$should_reset_plugin_data" = true ]; then
  back_up "$data_directory"
  back_up "$state_directory"
  back_up "$cache_directory"
fi

mkdir -p "$(dirname "$config_directory")"
git clone --quiet --depth 1 "$repository_url" "$config_directory"
printf 'Installed nvim-web into %s\n' "$config_directory"

install_plugins

warn_when_missing node "language servers, oxlint and oxfmt run on Node.js"
warn_when_missing rg "project-wide search"
warn_when_missing fd "faster file finding"
warn_when_missing gh "pull request review with Octo"
warn_when_missing lazygit "the lazygit window on <leader>gg"
warn_when_missing tree-sitter "building syntax parsers"
warn_when_missing cc "building syntax parsers"

printf 'Done. Start Neovim with: nvim\n'
