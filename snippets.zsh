# snip — CLI snippet manager.
# Data file: set $SNIP_TSV to override; defaults to snippets.tsv next to this
# script (so it works out of the box after cloning).
: ${SNIP_TSV:=${0:A:h}/snippets.tsv}

# Lowercase, collapse non-alphanumeric runs to single hyphens, trim hyphens.
_snip_slugify() {
  local s=${(L)1}            # lowercase
  s=${s//[^a-z0-9]/ }        # non-alnum -> space
  local -a parts=(${=s})     # word-split, drops empties
  print -r -- "${(j:-:)parts}"
}

# Emit non-comment, non-blank lines from the data file.
_snip_rows() {
  [[ -r $SNIP_TSV ]] || return 1
  local line
  while IFS= read -r line; do
    [[ -z $line || $line == \#* ]] && continue
    print -r -- "$line"
  done < $SNIP_TSV
}

# Split a TSV line into the global array `reply` (1=cat 2=ctx 3=name 4=cmd).
_snip_fields() { reply=("${(@ps:\t:)1}"); }

_snip_categories() {
  local line
  _snip_rows | while IFS= read -r line; do _snip_fields "$line"; print -r -- "$reply[1]"; done | sort -u
}

_snip_contexts() {
  local line
  _snip_rows | while IFS= read -r line; do _snip_fields "$line"; print -r -- "$reply[2]"; done | sort -u
}

# Convert literal \n and \t escapes to real newline/tab.
_snip_unescape() {
  local s=${1//\\n/$'\n'}
  s=${s//\\t/$'\t'}
  print -r -- "$s"
}

# Inverse of _snip_unescape: real tab/newline -> literal \t and \n so a row
# stays on a single TSV line.
_snip_escape() {
  local s=${1//$'\t'/\\t}
  s=${s//$'\n'/\\n}
  print -r -- "$s"
}

# Print the unescaped command for the snippet whose name slugifies to $1.
_snip_resolve_by_slug() {
  local want=$1 line; local -a reply
  local -a rows=("${(@f)$(_snip_rows)}")
  for line in $rows; do
    _snip_fields "$line"
    if [[ "$(_snip_slugify "$reply[3]")" == "$want" ]]; then
      _snip_unescape "$reply[4]"
      return 0
    fi
  done
  return 1
}

# Rows containing $1 (literal, case-insensitive) in any column.
_snip_filter() { _snip_rows | grep -iF -- "$1" || true; }

# Push a command onto the next prompt for editing (interactive shells only).
# Strip trailing newline(s) so selecting a snippet never auto-runs; internal
# newlines are kept so multi-line commands still load in full.
_snip_insert() {
  [[ -n $1 ]] || return 0
  local s=$1
  while [[ $s == *$'\n' ]]; do s=${s%$'\n'}; done
  print -z -- "$s"
}

# Define the snip-<slug> function for $1 (resolves its command from the file).
# Slug chars are [a-z0-9-], so they are safe inside the eval'd name/lookup key.
_snip_define() {
  local slug=$1
  eval "snip-${slug}() {
    _snip_insert \"\$(_snip_resolve_by_slug '${slug}')\"
  }"
}

# Define one snip-<slug> function per data row.
_snip_generate() {
  local line slug; local -a reply
  local -a rows=("${(@f)$(_snip_rows)}")
  for line in $rows; do
    _snip_fields "$line"
    slug=$(_snip_slugify "$reply[3]")
    [[ -z $slug ]] && continue
    (( ${+functions[snip-${slug}]} )) && { print -r -- "snip: duplicate slug '$slug', skipping" >&2; continue; }
    _snip_define "$slug"
  done
}
_snip_generate

_snip_usage() {
  cat <<'EOF'
snip — CLI snippet manager
  snip               pick from all snippets
  snip -l cat        pick a category, then a snippet
  snip -l context    pick a context, then a snippet
  snip -f <expr>     pick from snippets matching <expr> (name/category/context/command)
  snip -f <expr> --show   as above, but show each command under its name (lines prefixed " > ")
  snip -a <category> <context> <name> <command>   add a new snippet
  snip -h            this help
Selecting a snippet loads it onto your next prompt to edit, then press Enter.

Add examples:
  # simple command — run `brew list`
  snip -a brew general 'brew list' 'brew list'

  # multi-line command — put \n between lines
  snip -a wire runlocal 'start wire backend' 'cd ~/projects/the-wire\nnvm use 22\nnpm run dev'

If a snippet function (snip-<slug>) already exists you'll be asked to confirm overwrite.
EOF
}

# True if fzf is present and new enough (>= 0.50) for multi-line items
# (--read0/--gap), which the --show view relies on.
_snip_fzf_multiline() {
  command -v fzf >/dev/null 2>&1 || return 1
  local v=${${(s: :)$(fzf --version)}[1]}   # e.g. 0.73.1
  local -a p=(${(s:.:)v})
  (( ${p[1]:-0} > 0 || ${p[2]:-0} >= 50 ))
}

# stdin: TSV rows. Let the user pick one; insert its command. fzf if present,
# else a numbered `select` menu on snippet names.
# $1: show flag (1 = render each command's lines under its name, " > "-prefixed).
_snip_pick_rows() {
  local show=${1:-0}
  local rows; rows=$(cat)
  [[ -z $rows ]] && { print -r -- "no snippets" >&2; return 1; }
  local choice line cl; local -a reply lines=("${(@f)rows}")

  if command -v fzf >/dev/null 2>&1; then
    if (( show )) && _snip_fzf_multiline; then
      # One multi-line block per snippet, mapped back to its TSV row so the
      # exact command is recovered regardless of what the display contains.
      local block records=""; local -A blockrow
      for line in $lines; do
        _snip_fields "$line"
        block=$reply[3]
        for cl in "${(@f)$(_snip_unescape "$reply[4]")}"; do block+=$'\n'" > $cl"; done
        blockrow[$block]=$line
        records+=$block$'\0'
      done
      choice=$(print -rn -- "$records" | fzf --read0 --gap --highlight-line --prompt='snip> ') || return 1
      [[ -z $choice ]] && return 1
      choice=$blockrow[$choice]
    else
      (( show )) && print -r -- "snip: --show needs fzf >= 0.50; showing names only." >&2
      choice=$(print -r -- "$rows" | fzf --delimiter=$'\t' --with-nth=3 --prompt='snip> ') || return 1
    fi
  else
    local -a names=()
    for line in $lines; do _snip_fields "$line"; names+=("$reply[3]"); done
    if (( show )); then
      local i=1
      print -r -- "snippets:" >&2
      for line in $lines; do
        _snip_fields "$line"
        print -r -- "  [$i] $reply[3]" >&2
        for cl in "${(@f)$(_snip_unescape "$reply[4]")}"; do print -r -- "       > $cl" >&2; done
        (( i++ ))
      done
    fi
    local PS3='snip# ' name
    select name in $names; do
      [[ -n $name ]] && { choice=$lines[$REPLY]; break; }
    done
  fi
  [[ -z $choice ]] && return 1
  _snip_fields "$choice"
  _snip_insert "$(_snip_unescape "$reply[4]")"
}

# stdin: candidate values (categories or contexts). Echo the chosen value.
_snip_pick_value() {
  local vals; vals=$(cat)
  [[ -z $vals ]] && return 1
  if command -v fzf >/dev/null 2>&1; then
    print -r -- "$vals" | fzf --prompt='pick> '
  else
    local -a list=("${(@f)vals}"); local PS3='pick# ' v
    select v in $list; do [[ -n $v ]] && { print -r -- "$v"; break; }; done
    [[ -n $v ]] || return 1
  fi
}

# Rewrite the data file, replacing the first data row whose name slugifies to
# $1 with the row $2. Appends $2 if no matching row is found.
_snip_replace_row() {
  local target=$1 newrow=$2
  local tmp=${SNIP_TSV}.tmp.$$
  local line replaced=0; local -a reply
  {
    while IFS= read -r line; do
      if (( ! replaced )) && [[ -n $line && $line != \#* ]]; then
        _snip_fields "$line"
        if [[ "$(_snip_slugify "$reply[3]")" == "$target" ]]; then
          print -r -- "$newrow"; replaced=1; continue
        fi
      fi
      print -r -- "$line"
    done < $SNIP_TSV
    (( replaced )) || print -r -- "$newrow"
  } > $tmp || { rm -f $tmp; return 1; }
  mv $tmp $SNIP_TSV
}

# Add a snippet. Args: category context name command...
# Everything after the third arg is joined with spaces to form the command.
_snip_add() {
  local cat=$1 ctx=$2 name=$3
  (( $# >= 3 )) && shift 3 || shift $#
  local cmd="$*"
  if [[ -z $cat || -z $ctx || -z $name || -z $cmd ]]; then
    print -r -- "snip -a: need <category> <context> <name> <command>" >&2
    _snip_usage >&2
    return 1
  fi
  local slug=$(_snip_slugify "$name")
  [[ -z $slug ]] && { print -r -- "snip -a: name '$name' produces an empty slug" >&2; return 1; }

  local row="$(_snip_escape "$cat")"$'\t'"$(_snip_escape "$ctx")"$'\t'"$(_snip_escape "$name")"$'\t'"$(_snip_escape "$cmd")"

  if (( ${+functions[snip-${slug}]} )); then
    print -rn -- "snip: 'snip-${slug}' already exists. Overwrite? [y/N] " >&2
    local ans; read -r ans
    [[ $ans == [yY]* ]] || { print -r -- "snip: aborted." >&2; return 1; }
    _snip_replace_row "$slug" "$row" || { print -r -- "snip: failed to write $SNIP_TSV" >&2; return 1; }
    print -r -- "snip: overwrote 'snip-${slug}'."
  else
    [[ ! -e $SNIP_TSV || -w $SNIP_TSV ]] || { print -r -- "snip: $SNIP_TSV not writable" >&2; return 1; }
    # Ensure the file ends in a newline so we don't merge onto the last row.
    [[ -s $SNIP_TSV && -n "$(tail -c1 $SNIP_TSV)" ]] && print >> $SNIP_TSV
    print -r -- "$row" >> $SNIP_TSV || { print -r -- "snip: failed to write $SNIP_TSV" >&2; return 1; }
    _snip_define "$slug"
    print -r -- "snip: added 'snip-${slug}'."
  fi
}

snip() {
  case $1 in
    -h|--help) _snip_usage ;;
    -a|--add) shift; _snip_add "$@" ;;
    -f) shift
        local show=0 expr=
        while (( $# )); do
          case $1 in
            --show) show=1 ;;
            *) expr=$1 ;;
          esac
          shift
        done
        [[ -z $expr ]] && { _snip_usage; return 1; }
        _snip_filter "$expr" | _snip_pick_rows $show ;;
    -l)
      local pick
      case $2 in
        cat|category) pick=$(_snip_categories | _snip_pick_value) || return 1
                      _snip_filter "$pick" | awk -F'\t' -v c="$pick" '$1==c' | _snip_pick_rows ;;
        context|ctx)  pick=$(_snip_contexts | _snip_pick_value) || return 1
                      _snip_filter "$pick" | awk -F'\t' -v c="$pick" '$2==c' | _snip_pick_rows ;;
        *) _snip_usage; return 1 ;;
      esac ;;
    "") _snip_rows | _snip_pick_rows ;;
    *) _snip_usage; return 1 ;;
  esac
}
