# Sourced by install.sh and capture.sh: which machine this is, and the folders
# that make up its setup. Sets MACHINE and PARTS (repo root, each utility the
# machine lists, then the machine's own folder).

MACHINE_FILE=~/.local/state/omarchy-setup/machine

machines_list() {
  local d
  for d in "$REPO"/machines/*/; do basename "$d"; done | tr '\n' ' '
}

# $1: the machine name given on the command line, or empty.
resolve_machine() {
  MACHINE=${1:-}
  if [[ -z $MACHINE && -f $MACHINE_FILE ]]; then
    MACHINE=$(<"$MACHINE_FILE")
  fi
  if [[ -z $MACHINE ]]; then
    echo "Which machine is this? Run: $0 <machine>   (one of: $(machines_list))" >&2
    echo "New machine: see AGENTS.md." >&2
    exit 2
  fi
  if [[ ! -f $REPO/machines/$MACHINE/utilities.txt ]]; then
    echo "No machines/$MACHINE/utilities.txt (machines: $(machines_list))" >&2
    exit 2
  fi

  PARTS=("$REPO")
  local name
  while read -r name _; do
    [[ -z $name || $name == \#* ]] && continue
    if [[ ! -d $REPO/utilities/$name ]]; then
      echo "machines/$MACHINE/utilities.txt: no utility named $name" >&2
      exit 2
    fi
    PARTS+=("$REPO/utilities/$name")
  done <"$REPO/machines/$MACHINE/utilities.txt"
  PARTS+=("$REPO/machines/$MACHINE")
}

# $1: comma-separated utility names. Sets PARTS to just those utilities, for
# installing one thing on its own (install.sh --only). MACHINE stays empty.
resolve_only() {
  MACHINE=
  PARTS=()
  local name
  IFS=, read -ra names <<<"$1"
  for name in "${names[@]}"; do
    if [[ ! -d $REPO/utilities/$name ]]; then
      echo "No utility named $name (utilities: $(cd "$REPO/utilities" && echo *))" >&2
      exit 2
    fi
    PARTS+=("$REPO/utilities/$name")
  done
}
