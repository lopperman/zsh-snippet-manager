#!/usr/bin/env zsh
# install.zsh — make `snip` available in every new zsh session by sourcing
# snippets.zsh from your ~/.zshrc.
#
# Usage:
#   ./install.zsh [path/to/snippets.tsv]
#
# The optional argument sets where your snippets live. Default:
#   ~/zsh-snippets/snippets.tsv   (seeded from the bundled sample on first run)
#
# Re-running is safe: it replaces its own block in ~/.zshrc rather than
# appending a duplicate.
set -e

src_dir=${0:A:h}
script=$src_dir/snippets.zsh
[[ -r $script ]] || { print -u2 -- "install: can't find snippets.zsh next to this script"; exit 1; }

# Data-file location (absolute). Default to ~/zsh-snippets/snippets.tsv.
tsv=${1:-$HOME/zsh-snippets/snippets.tsv}
tsv=${tsv:A}

# Seed the data file from the bundled sample the first time.
if [[ ! -e $tsv ]]; then
  mkdir -p "${tsv:h}"
  cp "$src_dir/snippets.tsv" "$tsv"
  print -- "install: created $tsv (from bundled sample)"
fi

rc=$HOME/.zshrc
start='# >>> zsh-snippet-manager >>>'
end='# <<< zsh-snippet-manager <<<'
block="$start
export SNIP_TSV=\"$tsv\"
source \"$script\"
$end"

# Drop any previous block so re-running updates in place instead of stacking.
if [[ -e $rc ]] && grep -qF -- "$start" "$rc"; then
  tmp=$(mktemp)
  awk -v s="$start" -v e="$end" '
    $0==s {skip=1}
    !skip {print}
    $0==e {skip=0}
  ' "$rc" > "$tmp"
  mv "$tmp" "$rc"
fi

# Append, keeping the file newline-terminated.
[[ -s $rc && -n "$(tail -c1 "$rc")" ]] && print >> "$rc"
print -r -- "$block" >> "$rc"

print -- "install: wired snip into $rc"
print -- "install: data file = $tsv"
print -- "Run:  source $rc   (or open a new shell)"
