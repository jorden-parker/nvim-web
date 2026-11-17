# nvim-web

A Neovim config for front-end work, built on [LazyVim](https://www.lazyvim.org).
It sets up TypeScript, HTML, CSS, JSON, YAML and Markdown tooling, uses
[Oxc](https://oxc.rs) (`oxlint` and `oxfmt`) for linting and formatting, and
adds pull request review and [Claude Code](https://claude.com/claude-code)
inside the editor.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/jorden-parker/nvim-web/main/install.sh | bash
```

The installer replaces `~/.config/nvim` with this config. Before it does, it
moves your current config to `~/.config/nvim.backup-<date>-<time>`, for example
`~/.config/nvim.backup-20261111-130653`. Nothing is deleted.

Then start `nvim`. Plugins are already installed; language servers, formatters
and syntax parsers install themselves in the background on the first launch.
Run `:Mason` to watch them.

### Install from a clone

If you have cloned the repository, run the installer from its root:

```sh
git clone https://github.com/jorden-parker/nvim-web.git
cd nvim-web
bash install.sh
```

This does the same as the `curl` command: it backs up your current config, then
installs the latest version from GitHub into `~/.config/nvim`. It does not link
or copy your clone.

To install the commits in your clone instead, for example to try your own
changes, point the installer at it:

```sh
NVIM_WEB_REPOSITORY="file://$PWD" bash install.sh
```

Only committed changes are installed.

### Options

| Option | What it does |
| --- | --- |
| `--fresh` | Also moves Neovim's plugin data, state and cache to backups, so everything installs from scratch |
| `--help` | Shows the usage text and exits |

```sh
bash install.sh --fresh
curl -fsSL https://raw.githubusercontent.com/jorden-parker/nvim-web/main/install.sh | bash -s -- --fresh
```

If `XDG_CONFIG_HOME` is set, the installer uses `$XDG_CONFIG_HOME/nvim` in
place of `~/.config/nvim`.

### Go back

To restore your old config:

```sh
rm -rf ~/.config/nvim
mv ~/.config/nvim.backup-<date>-<time> ~/.config/nvim
```

### Requirements

| Tool | Why |
| --- | --- |
| Neovim 0.11.2 or newer, Git | Required |
| Node.js | Runs the language servers, `oxlint` and `oxfmt` |
| `tree-sitter` CLI and a C compiler | Build syntax parsers |
| [ripgrep](https://github.com/BurntSushi/ripgrep), [fd](https://github.com/sharkdp/fd) | Search and file finding |
| [GitHub CLI](https://cli.github.com) (`gh auth login`) | Pull request review |
| [Claude Code](https://claude.com/claude-code) CLI (`claude`) | Claude Code window |
| [lazygit](https://github.com/jesseduffield/lazygit), a [Nerd Font](https://www.nerdfonts.com) | Git window and icons |

On macOS: `brew install neovim node tree-sitter-cli ripgrep fd gh lazygit`.

## What is set up

| Area | Tools |
| --- | --- |
| TypeScript and JavaScript | `vtsls` language server, `oxlint`, `oxfmt` |
| HTML and CSS | `html` and `cssls` language servers, Emmet, Tailwind CSS, inline colour previews |
| JSON and YAML | `jsonls` and `yamlls` with SchemaStore schemas |
| Markdown | `marksman`, `markdownlint-cli2`, in-buffer rendering, browser preview |
| Other linters and formatters | ESLint, Prettier and Biome, used only in projects configured for them |
| Syntax parsers | TypeScript, TSX, JavaScript, JSDoc, HTML, CSS, SCSS, JSON, JSON5, YAML, TOML, Markdown, GraphQL and more |
| Git and GitHub | gitsigns, lazygit, Octo, Diffview |
| AI | Claude Code |

Mason installs every tool. A project's own `node_modules/.bin/oxlint` and
`node_modules/.bin/oxfmt` are used when they exist, so the editor matches the
version your project pins.

## Oxc

### Formatting with oxfmt

Files are formatted on save and with `<leader>cf`.

One formatter runs per file. The config looks for formatter settings in the
file's folder, then each parent folder, and the nearest match wins:

| Found | Formatter |
| --- | --- |
| `.oxfmtrc.json`, `.oxfmtrc.jsonc`, `oxfmt.config.ts`, or `oxfmt` in `package.json` | oxfmt |
| `biome.json` or `biome.jsonc` | Biome |
| A Prettier config file, or `prettier` in `package.json` | Prettier |
| Nothing | oxfmt |

When one folder matches more than one row, the higher row wins.

oxfmt formats JavaScript, TypeScript, JSX, TSX, JSON, JSON5, CSS, SCSS, Less,
HTML, Vue, Svelte, Astro, Markdown, MDX, YAML, TOML, GraphQL and Handlebars.

### Linting with oxlint

`oxlint` runs as a language server, so problems show as you type and quick
fixes appear under `<leader>ca`.

It starts in projects that have `.oxlintrc.json`, `.oxlintrc.jsonc` or
`oxlint.config.ts`, or that list `oxlint` in `package.json`. In a monorepo the
config at the repository root is used, and nested configs still apply.

| Key | Action |
| --- | --- |
| `<leader>cx` | Apply every safe oxlint fix in the file |
| `<leader>cX` | Apply every oxlint fix in the file, including ones that can change behaviour |
| `<leader>ca` | Pick a fix for the problem under the cursor |
| `]d` / `[d` | Next / previous problem |
| `<leader>xx` | List all problems |

Type-aware rules turn on by themselves when `tsgolint` is installed and
`.oxlintrc.json` mentions `typescript`.

ESLint starts as well in projects that have an ESLint config.

## Pull request review

Two plugins cover review. [Octo](https://github.com/pwntester/octo.nvim) talks
to GitHub: it lists pull requests, shows the diff, and posts comments and
reviews. [Diffview](https://github.com/sindrets/diffview.nvim) shows local
diffs, which is useful for reading a branch you have checked out.

`<leader>` is `<Space>`. `<localleader>` is `\`.

### Find and open

| Key | Action |
| --- | --- |
| `<leader>pl` | List open pull requests |
| `<leader>ps` | Search pull requests |
| `<leader>pm` | Pull requests waiting for my review |
| `<leader>pa` | My open pull requests |
| `<leader>pp` | Open the pull request of the current branch |
| `<leader>pn` | Create a pull request from the current branch |

### Inside a pull request

| Key | Action |
| --- | --- |
| `<leader>pr` | Start a review |
| `<leader>pR` | Resume a pending review |
| `<leader>pt` | Show my pending review comments |
| `<leader>pS` | Submit the review (then `<C-a>` approve, `<C-m>` comment, `<C-r>` request changes) |
| `<leader>pD` | Discard the pending review |
| `<leader>po` | Check out the pull request branch |
| `<leader>pk` | Show CI checks |
| `<leader>pb` | Open in the browser |

### Inside the review diff

These are Octo's own keys.

| Key | Action |
| --- | --- |
| `]q` / `[q` | Next / previous changed file |
| `]u` / `[u` | Next / previous unviewed file |
| `]c` / `[c` | Next / previous comment |
| `<localleader>ca` | Add a comment (works on a visual selection) |
| `<localleader>sa` | Add a suggestion |
| `<localleader>cr` | Reply to a comment |
| `<localleader>rt` | Resolve a thread |
| `<C-c>` | Close the review |

### Local diffs

| Key | Action |
| --- | --- |
| `<leader>pv` | Diff the current branch against the base branch |
| `<leader>ph` | Commits on the current branch |
| `<leader>pf` | History of the current file |
| `<leader>pq` | Close Diffview |
| `]h` / `[h` | Next / previous changed hunk in a normal buffer |
| `<leader>gg` | lazygit |

LazyVim's Octo keys work too: `<leader>gp` lists pull requests and
`<leader>gi` lists issues.

## Claude Code

[claudecode.nvim](https://github.com/coder/claudecode.nvim) runs the `claude`
CLI in a window beside your code and connects it to the editor, so Claude sees
the file and selection you are working on and shows its edits as diffs you
accept or deny. It is LazyVim's `ai.claudecode` extra, with LazyVim's keys.

| Key | Action |
| --- | --- |
| `<leader>ac` | Show or hide Claude |
| `<leader>af` | Focus the Claude window |
| `<leader>ar` | Resume an earlier conversation |
| `<leader>aC` | Continue the last conversation |
| `<leader>ab` | Add the current file to the conversation |
| `<leader>as` (visual) | Send the selection to Claude |
| `<leader>aa` | Accept the diff Claude proposes |
| `<leader>ad` | Deny the diff |

## Everyday keys

Press `<Space>` and wait: a menu shows every key that can follow. `<leader>sk`
searches all keys.

### Added by this config

| Key | Action |
| --- | --- |
| `jj` or `jk` (insert mode) | Leave insert mode |
| `<leader>fy` | Copy the file path, relative to the project |
| `<leader>fY` | Copy the absolute file path |
| `<leader>fj` | Open the nearest `package.json` |
| `<leader>cw` | Replace the word under the cursor everywhere in the file |
| `<leader>cx` / `<leader>cX` | Apply safe / all oxlint fixes in the file |

### Files and search

| Key | Action |
| --- | --- |
| `<leader><space>` | Find a file |
| `<leader>/` | Search text in the project |
| `<leader>sw` | Search the word under the cursor |
| `<leader>fr` | Recent files |
| `<leader>e` | File explorer |
| `<leader>sr` | Search and replace across files |

### Code

| Key | Action |
| --- | --- |
| `gd` / `gr` | Go to definition / references |
| `K` | Show documentation |
| `<leader>cr` | Rename symbol |
| `<leader>ca` | Code action |
| `<leader>cf` | Format |
| `<leader>ss` | Symbols in this file |

### Editing

| Key | Action |
| --- | --- |
| `<A-j>` / `<A-k>` | Move the line or selection down / up |
| `gcc`, `gc` (visual) | Toggle comment |
| `gsa`, `gsd`, `gsr` | Add, delete, replace surrounding quotes, brackets or tags |
| `s` | Jump anywhere on screen |
| `P` (visual) | Paste over a selection and keep what you copied |
| `vag` | Select the whole file |

### Buffers, windows and terminal

| Key | Action |
| --- | --- |
| `H` / `L` | Previous / next buffer |
| `<leader>bd` | Close buffer |
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | Move between windows |
| `<leader>-`, `<leader>\|` | Split below, split right |
| `<C-/>` | Toggle terminal |
| `<C-s>` | Save |

The full LazyVim list is at <https://www.lazyvim.org/keymaps>.

## Changing things

| To | Do |
| --- | --- |
| Add Vue, Svelte, Astro or another language | Run `:LazyExtras` and press `x` on the extra |
| Try the native TypeScript 7 server | Enable the `lang.typescript.tsc` extra in `:LazyExtras` |
| Add a key | Edit `lua/config/keymaps.lua` |
| Add or change a plugin | Add a file in `lua/plugins/` |
| Update plugins | Run `:Lazy update` |

Layout:

```text
init.lua                            entry point
lazyvim.json                        enabled LazyVim extras, including Claude Code
lua/config/                         options, keys, plugin manager bootstrap
lua/plugins/oxc.lua                 oxlint and oxfmt
lua/plugins/web.lua                 HTML, CSS, Emmet, extra parsers
lua/plugins/pull-request-review.lua Octo and Diffview
lua/plugins/diagnostics.lua         how problems are displayed
lua/project_tooling.lua             picks the formatter and oxlint root per project
```

## Tests

```sh
tests/run.sh
```

The tests start a real Neovim with this config in an isolated folder
(`.test-environment/`), so they never touch `~/.config/nvim`. They check that
the config starts without errors, that plugins and tools install, that oxlint
and oxfmt work on a sample project, that the keys are mapped, that the Claude
Code plugin loads, and that the install script backs up before it replaces.
The first run downloads everything and takes a few minutes.

## Licence

Apache-2.0. The plugin manager bootstrap comes from the
[LazyVim starter](https://github.com/LazyVim/starter).
