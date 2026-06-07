# snip — a tiny CLI snippet manager for zsh

`snip` keeps your frequently-used commands in a plain TSV file and lets you
fuzzy-pick one straight onto your command line, ready to edit and run. It also
generates a `snip-<name>` shortcut function for every snippet.

Selecting a snippet **loads it onto your next prompt** (via `print -z`) — it
never auto-runs, so you always get a chance to review/edit before pressing
Enter.

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

Add to your `~/.zshrc`:

```zsh
source ~/.zsh-snippets/snippets.zsh
```

Open a new shell (or `source ~/.zsh-snippets/snippets.zsh`). That's it.

By default the data file is `snippets.tsv` **next to the script**, so the
bundled sample works immediately. To keep your snippets elsewhere, set
`SNIP_TSV` before sourcing:

```zsh
export SNIP_TSV=~/dotfiles/snippets.tsv
source ~/.zsh-snippets/snippets.zsh
```

## Usage

```
snip                      pick from all snippets
snip -l cat               pick a category, then a snippet
snip -l context           pick a context, then a snippet
snip -f <expr>            pick from snippets matching <expr>
                          (matches name / category / context / command)
snip -f <expr> --show     as above, but show each command under its name
                          (lines prefixed with " > ")  [needs fzf >= 0.50]
snip -a <category> <context> <name> <command>   add a new snippet
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

## Data format

`snippets.tsv` is tab-separated with four columns:

```
category <TAB> context <TAB> name <TAB> command
```

- Lines beginning with `#` and blank lines are ignored.
- In the **command** column, use the literal escapes `\n` and `\t` for
  newlines and tabs so each snippet stays on a single line. `snip -a` writes
  these escapes for you automatically.

You can edit `snippets.tsv` by hand or use `snip -a`. Changes take effect the
next time the script is sourced (open a new shell or re-`source` it).

## License

[MIT](LICENSE)
