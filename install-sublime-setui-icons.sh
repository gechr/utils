#!/bin/sh

set -e

info() {
	printf '\033[1;34m==>\033[1;37m %s\033[m\n' "$1"
}

SUBLIME_THEME="Aprosopo Dark@st3.sublime-theme"
SUBLIME_USER_DIR="$HOME/Library/Application Support/Sublime Text 3/Packages/User"
ICON_INSTALL_DIR="$SUBLIME_USER_DIR/Icons"
LANG_INSTALL_DIR="$SUBLIME_USER_DIR/Langs"
GIT_REPO="https://github.com/ctf0/Seti_ST3"

info "Cloning Git repository into temporary directory"
TMPDIR=$(mktemp -d)
git clone --depth=1 "$GIT_REPO" "$TMPDIR"
cd "$TMPDIR"

info "Cleaning up old languages"
rm -rf -- "$LANG_INSTALL_DIR"
info "Installing new languages"
mv "icons/Langs" "$LANG_INSTALL_DIR"

info "Cleaning up old icons"
rm -rf -- "$ICON_INSTALL_DIR"
mkdir -p "$ICON_INSTALL_DIR/icons"

info "Installing new preferences"
mv "icons/Prefs/"* "$ICON_INSTALL_DIR/"
info "Installing new icons"
mv "icons/file_type_"* "$ICON_INSTALL_DIR/icons/"
info "Creating blank '$SUBLIME_THEME' file"
touch "$ICON_INSTALL_DIR/$SUBLIME_THEME"

info "Cleaning up temporary directory"
rm -rf -- "$TMPDIR"
