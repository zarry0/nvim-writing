#!/usr/bin/env zsh

emulate -L zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

die() {
  print -u2 -r -- "install-links test: $*"
  exit 1
}

assert_link_to() {
  local link="$1"
  local expected="$2"
  [[ -L "$link" ]] || die "falta el symlink: $link"
  [[ -e "$link" ]] || die "el symlink está roto: $link"
  [[ "${link:A}" == "${expected:A}" ]] || die "el symlink apunta a otro lugar: $link"
}

expect_failure() {
  "$@" >/dev/null 2>&1 && die "la orden debía fallar: $*"
  return 0
}

inode_of() {
  local target_path="$1"
  if command stat -f '%i' "$target_path" >/dev/null 2>&1; then
    command stat -f '%i' "$target_path"
  else
    command stat -c '%i' "$target_path"
  fi
}

test_path="${0:A}"
repo_root="${test_path:h:h}"
installer="$repo_root/bin/install-links.zsh"

command zsh -n "$installer"
[[ -x "$installer" ]] || die "bin/install-links.zsh debe conservar el modo ejecutable"

test_root="$(command mktemp -d "${TMPDIR:-/tmp}/nvim-writing-links.XXXXXX")"
[[ -n "$test_root" && "$test_root" != "/" ]] || die "mktemp devolvió una ruta insegura"

cleanup() {
  [[ -n "${test_root:-}" && "$test_root" == */nvim-writing-links.* ]] || return
  command rm -rf "$test_root"
}
trap cleanup EXIT INT TERM

fixture_repo="$test_root/checkout con espacios"
command mkdir -p "$fixture_repo/bin"
command cp "$repo_root/init.lua" "$fixture_repo/init.lua"
command cp "$repo_root/bin/nvwrite" "$fixture_repo/bin/nvwrite"
command cp "$installer" "$fixture_repo/bin/install-links.zsh"
command chmod +x "$fixture_repo/bin/nvwrite" "$fixture_repo/bin/install-links.zsh"

home_dir="$test_root/home con espacios"
xdg_dir="$test_root/xdg config"
command mkdir -p "$home_dir/.config/nvim"
print -r -- "sentinel zshrc" > "$home_dir/.zshrc"
print -r -- "sentinel nvim de programación" > "$home_dir/.config/nvim/init.lua"
zshrc_before="$test_root/zshrc.before"
nvim_before="$test_root/nvim.before"
command cp "$home_dir/.zshrc" "$zshrc_before"
command cp "$home_dir/.config/nvim/init.lua" "$nvim_before"

HOME="$home_dir" XDG_CONFIG_HOME="$xdg_dir" \
  command zsh "$fixture_repo/bin/install-links.zsh" >/dev/null
[[ ! -e "$xdg_dir" ]] || die "el dry-run creó XDG_CONFIG_HOME"
[[ ! -e "$home_dir/.local" ]] || die "el dry-run creó .local"

HOME="$home_dir" XDG_CONFIG_HOME="$xdg_dir" \
  command zsh "$fixture_repo/bin/install-links.zsh" --apply >/dev/null
assert_link_to "$xdg_dir/nvim-writing" "$fixture_repo"
assert_link_to "$home_dir/.local/bin/nvwrite" "$fixture_repo/bin/nvwrite"
[[ ! -e "$home_dir/.config/nvim-writing" ]] || die "se ignoró XDG_CONFIG_HOME"
command cmp -s "$home_dir/.zshrc" "$zshrc_before" || die "se modificó .zshrc"
command cmp -s "$home_dir/.config/nvim/init.lua" "$nvim_before" || die "se modificó la config de programación"

# Sin XDG_CONFIG_HOME se usa ~/.config, sin tocar ~/.config/nvim.
default_home="$test_root/home default"
command mkdir -p "$default_home/.config/nvim"
print -r -- "default nvim" > "$default_home/.config/nvim/init.lua"
default_nvim_before="$test_root/default-nvim.before"
command cp "$default_home/.config/nvim/init.lua" "$default_nvim_before"
(
  unset XDG_CONFIG_HOME
  HOME="$default_home" command zsh "$fixture_repo/bin/install-links.zsh" --apply >/dev/null
)
assert_link_to "$default_home/.config/nvim-writing" "$fixture_repo"
assert_link_to "$default_home/.local/bin/nvwrite" "$fixture_repo/bin/nvwrite"
command cmp -s "$default_home/.config/nvim/init.lua" "$default_nvim_before" || \
  die "se modificó ~/.config/nvim al usar el fallback"

# Idempotencia: los enlaces correctos se reconocen y no cambian.
config_inode="$(inode_of "$xdg_dir/nvim-writing")"
launcher_inode="$(inode_of "$home_dir/.local/bin/nvwrite")"
HOME="$home_dir" XDG_CONFIG_HOME="$xdg_dir" \
  command zsh "$fixture_repo/bin/install-links.zsh" --apply >/dev/null
[[ "$config_inode" == "$(inode_of "$xdg_dir/nvim-writing")" ]] || \
  die "la segunda ejecución reemplazó el enlace de configuración"
[[ "$launcher_inode" == "$(inode_of "$home_dir/.local/bin/nvwrite")" ]] || \
  die "la segunda ejecución reemplazó el launcher"
command cmp -s "$home_dir/.zshrc" "$zshrc_before" || die "la segunda ejecución modificó .zshrc"
command cmp -s "$home_dir/.config/nvim/init.lua" "$nvim_before" || \
  die "la segunda ejecución modificó la config de programación"

# Un conflicto en el segundo destino debe impedir también la creación del primero.
conflict_home="$test_root/home conflicto"
conflict_xdg="$test_root/xdg conflicto"
command mkdir -p "$conflict_home/.local/bin"
print -r -- "no reemplazar" > "$conflict_home/.local/bin/nvwrite"
conflict_before="$test_root/conflict.before"
command cp "$conflict_home/.local/bin/nvwrite" "$conflict_before"
expect_failure env HOME="$conflict_home" XDG_CONFIG_HOME="$conflict_xdg" \
  zsh "$fixture_repo/bin/install-links.zsh" --apply
[[ ! -e "$conflict_xdg/nvim-writing" && ! -L "$conflict_xdg/nvim-writing" ]] || \
  die "el preflight dejó una instalación parcial"
command cmp -s "$conflict_home/.local/bin/nvwrite" "$conflict_before" || die "se sobrescribió un archivo"

directory_home="$test_root/home directorio existente"
directory_xdg="$test_root/xdg directorio existente"
command mkdir -p "$directory_home" "$directory_xdg/nvim-writing"
print -r -- "directorio no reemplazar" > "$directory_xdg/nvim-writing/sentinel"
directory_before="$test_root/directory.before"
command cp "$directory_xdg/nvim-writing/sentinel" "$directory_before"
expect_failure env HOME="$directory_home" XDG_CONFIG_HOME="$directory_xdg" \
  zsh "$fixture_repo/bin/install-links.zsh" --apply
[[ ! -e "$directory_home/.local/bin/nvwrite" && ! -L "$directory_home/.local/bin/nvwrite" ]] || \
  die "se instaló el launcher pese al conflicto de directorio"
command cmp -s "$directory_xdg/nvim-writing/sentinel" "$directory_before" || \
  die "se modificó un directorio existente"

# Symlinks incorrectos y rotos se conservan y provocan error.
wrong_home="$test_root/home symlink distinto"
wrong_xdg="$test_root/xdg symlink distinto"
other_target="$test_root/otro destino"
command mkdir -p "$wrong_home" "$wrong_xdg" "$other_target"
command ln -s "$other_target" "$wrong_xdg/nvim-writing"
wrong_before="$(command readlink "$wrong_xdg/nvim-writing")"
expect_failure env HOME="$wrong_home" XDG_CONFIG_HOME="$wrong_xdg" \
  zsh "$fixture_repo/bin/install-links.zsh" --apply
[[ "$(command readlink "$wrong_xdg/nvim-writing")" == "$wrong_before" ]] || die "se cambió un symlink incorrecto"

broken_home="$test_root/home symlink roto"
broken_xdg="$test_root/xdg symlink roto"
command mkdir -p "$broken_home" "$broken_xdg"
command ln -s "$test_root/no-existe" "$broken_xdg/nvim-writing"
broken_before="$(command readlink "$broken_xdg/nvim-writing")"
expect_failure env HOME="$broken_home" XDG_CONFIG_HOME="$broken_xdg" \
  zsh "$fixture_repo/bin/install-links.zsh" --apply
[[ "$(command readlink "$broken_xdg/nvim-writing")" == "$broken_before" ]] || die "se cambió un symlink roto"

# Las variantes textuales o symlinks que resuelven a / también se rechazan.
root_alias="$test_root/root alias"
command ln -s / "$root_alias"
expect_failure env HOME="$home_dir" XDG_CONFIG_HOME="$root_alias" \
  zsh "$fixture_repo/bin/install-links.zsh" --apply
expect_failure env HOME="$root_alias" \
  zsh "$fixture_repo/bin/install-links.zsh" --apply

print -r -- "install-links smoke: OK"
