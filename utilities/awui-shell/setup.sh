# Sourced by install.sh. Uses its DRY, run and note; $DIR is this folder.
# Builds omarchy-awui from crate/ and installs it as ~/.local/bin/omarchy-awui,
# rebuilding only when the source is newer than the installed binary.

AWUI_BIN=$HOME/.local/bin/omarchy-awui
AWUI_TARGET=${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-awui/target
newest_src=$(find "$DIR/crate/src" "$DIR/crate/Cargo.toml" "$DIR/crate/Cargo.lock" -type f -newer "$AWUI_BIN" 2>/dev/null | head -1)
if [[ -x $AWUI_BIN && -z $newest_src ]]; then
  note "omarchy-awui up to date"
else
  run env CARGO_TARGET_DIR="$AWUI_TARGET" cargo build --release --locked --manifest-path "$DIR/crate/Cargo.toml"
  run install -D -m 755 "$AWUI_TARGET/release/omarchy-awui" "$AWUI_BIN"
  run systemctl --user restart omarchy-awui.service
fi
