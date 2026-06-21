# snip — a tiny CLI snippet manager for zsh

`snip` keeps your frequently-used commands in a plain TSV file and lets you
fuzzy-pick one straight onto your command line, ready to edit and run. It also
generates a `snip-<name>` shortcut function for every snippet.

Selecting a snippet **loads it onto your next prompt** (via `print -z`) — by
default it never auto-runs, so you always get a chance to review/edit before
pressing Enter. Snippets added with `--autorun` are the exception: they
**execute immediately** on selection (see [Autorun](#autorun)).

## Requirements

- **zsh** (uses zsh-only features; it will not work under bash).
- **[fzf](https://github.com/junegunn/fzf)** — *optional*. With fzf you get a
  fuzzy picker; without it, `snip` falls back to a numbered `select` menu.
  - The `--show` view (commands rendered under each name) needs **fzf ≥ 0.50**.
    On older fzf it degrades to a names-only picker.
- Standard `grep`, `awk`, `sort`, `tail` (POSIX flags only — works on macOS and
  Linux).

## Install

```sh
git clone git@github.com:lopperman/zsh-snippets.git ~/.zsh-snippets
```

### Quick install (recommended)

Run the installer once. It adds a small block to your `~/.zshrc` so `snip`
loads in every new shell:

```zsh
~/.zsh-snippets/install.zsh
```

By default your snippets live in `~/zsh-snippets/snippets.tsv` (seeded from the
bundled sample on first run). To keep them elsewhere, pass a path:

```zsh
~/.zsh-snippets/install.zsh ~/dotfiles/snippets.tsv
```

Then `source ~/.zshrc` (or open a new shell). Re-running the installer is safe —
it updates its own block instead of adding a duplicate. To uninstall, delete the
`# >>> zsh-snippet-manager >>>` … `# <<< zsh-snippet-manager <<<` block from
`~/.zshrc`.

### Manual install

If you'd rather wire it up yourself, add to your `~/.zshrc`:

```zsh
export SNIP_TSV=~/zsh-snippets/snippets.tsv   # optional; see below
source ~/.zsh-snippets/snippets.zsh
```

If you skip `SNIP_TSV`, the data file defaults to `snippets.tsv` **next to the
script**, so the bundled sample works immediately. Open a new shell (or
re-`source`) and you're set.

## Usage

```
snip                      pick from all snippets
snip -l cat               pick a category, then a snippet
snip -l context           pick a context, then a snippet
snip -f <expr>            pick from snippets matching <expr>
                          (matches name / category / context / command)
snip -f <expr> --show     as above, but show each command under its name
                          (lines prefixed with " > ")  [needs fzf >= 0.50]
snip -a [--autorun] <category> <context> <name> <command>   add a new snippet
snip -h                   help
```

Every snippet also gets a function named `snip-<slugified-name>`. For example a
snippet named `brew list` becomes `snip-brew-list`, which loads `brew list`
onto your prompt.

### Adding snippets

```zsh
# simple command
snip -a brew general 'brew list' 'brew list'

# multi-line command — put \n between lines
snip -a node dev 'project setup' 'cd ~/projects/app\nnvm use 22\nnpm install\nnpm run dev'
```

If a `snip-<name>` function already exists you'll be asked to confirm before
overwriting it.

### Autorun

Pass `--autorun` (as the **first** argument, before the positional args) to
mark a snippet to **run immediately** when selected, instead of loading onto
the prompt:

```zsh
snip -a --autorun system info today 'date'
```

Notes:

- `--autorun` must come before `<category>` — a trailing `--autorun` is treated
  as part of the command.
- Multi-line autorun snippets run each line in order.
- State changes (`cd`, `export`, `nvm use`) persist in your current shell, so a
  `cd` snippet actually moves your shell.
- Autorun runs the stored command with `eval` — only mark snippets you trust
  (it's your own data file).

## Data format

`snippets.tsv` is tab-separated with four columns, plus an optional fifth:

```
category <TAB> context <TAB> name <TAB> command [<TAB> autorun]
```

- Lines beginning with `#` and blank lines are ignored.
- In the **command** column, use the literal escapes `\n` and `\t` for
  newlines and tabs so each snippet stays on a single line. `snip -a` writes
  these escapes for you automatically.
- The optional **autorun** column is `1` to run the snippet on selection;
  absent (or empty) means load-to-prompt as usual. Existing four-column rows
  keep working unchanged.

You can edit `snippets.tsv` by hand or use `snip -a`. Changes take effect the
next time the script is sourced (open a new shell or re-`source` it).

## License

[MIT](LICENSE)
