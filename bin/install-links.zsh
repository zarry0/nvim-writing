#!/usr/bin/env zsh

emulate -L zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL

usage() {
  print -r -- "Uso: ${0:t} [--dry-run|--apply]"
  print -r -- ""
  print -r -- "  --dry-run  Valida y muestra el plan sin cambiar nada (default)."
  print -r -- "  --apply    Crea únicamente los directorios padre y enlaces ausentes."
}

die() {
  print -u2 -r -- "Error: $*"
  exit 1
}

(( $# <= 1 )) || {
  usage >&2
  exit 2
}

mode="dry-run"
case "${1:-}" in
  ""|--dry-run)
    ;;
  --apply)
    mode="apply"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

[[ -n "${HOME:-}" ]] || die "HOME no está definido."
[[ "$HOME" == /* ]] || die "HOME debe ser una ruta absoluta: $HOME"
[[ "$HOME" != "/" ]] || die "HOME no puede ser el directorio raíz."
[[ -d "$HOME" ]] || die "HOME no existe o no es un directorio: $HOME"
[[ "${HOME:A}" != "/" ]] || die "HOME no puede resolver al directorio raíz."

script_path="${0:A}"
script_dir="${script_path:h}"
repo_dir="${script_dir:h}"
launcher_source="$repo_dir/bin/nvwrite"

[[ -f "$repo_dir/init.lua" ]] || die "No se encontró init.lua en el checkout: $repo_dir"
[[ -f "$launcher_source" ]] || die "No se encontró el launcher: $launcher_source"
[[ -x "$launcher_source" ]] || die "El launcher no es ejecutable: $launcher_source"

config_parent="${XDG_CONFIG_HOME:-$HOME/.config}"
bin_parent="$HOME/.local/bin"

[[ "$config_parent" == /* ]] || die "XDG_CONFIG_HOME debe ser absoluto: $config_parent"
[[ "$config_parent" != "/" ]] || die "XDG_CONFIG_HOME no puede ser el directorio raíz."
[[ "${config_parent:A}" != "/" ]] || die "XDG_CONFIG_HOME no puede resolver al directorio raíz."

typeset -a labels sources destinations parents states
labels=("configuración" "launcher")
sources=("$repo_dir" "$launcher_source")
destinations=("$config_parent/nvim-writing" "$bin_parent/nvwrite")
parents=("$config_parent" "$bin_parent")

validate_parent() {
  local parent="$1"
  local ancestor="$parent"

  while [[ ! -e "$ancestor" && ! -L "$ancestor" ]]; do
    local next="${ancestor:h}"
    [[ "$next" != "$ancestor" ]] || break
    ancestor="$next"
  done

  [[ -e "$ancestor" ]] || die "No existe un ancestro utilizable para: $parent"
  [[ -d "$ancestor" ]] || die "Un componente del directorio padre no es un directorio: $ancestor"
}

inspect_destination() {
  local source="$1"
  local destination="$2"

  if [[ -L "$destination" ]]; then
    [[ -e "$destination" ]] || die "Symlink roto; no se modificó: $destination"
    [[ "${destination:A}" == "${source:A}" ]] || \
      die "El symlink ya apunta a otro lugar; no se modificó: $destination"
    REPLY="present"
    return
  fi

  if [[ -e "$destination" ]]; then
    [[ "${destination:A}" == "${source:A}" ]] || \
      die "El destino ya existe; no se modificó: $destination"
    REPLY="present"
    return
  fi

  REPLY="create"
}

# Preflight completo: no se crea ningún directorio o enlace hasta validar ambos
# destinos y sus padres.
for index in {1..2}; do
  validate_parent "${parents[$index]}"
  inspect_destination "${sources[$index]}" "${destinations[$index]}"
  states[$index]="$REPLY"
done

print -r -- "Checkout: $repo_dir"
print -r -- "Plan:"
for index in {1..2}; do
  if [[ "${states[$index]}" == "present" ]]; then
    print -r -- "  OK     ${labels[$index]}: ${destinations[$index]}"
  else
    print -r -- "  CREAR  ${labels[$index]}: ${destinations[$index]} -> ${sources[$index]}"
  fi
done

if [[ "$mode" == "dry-run" ]]; then
  print -r -- ""
  print -r -- "Dry-run terminado: no se cambió nada."
  print -r -- "Ejecuta: ${(q)0} --apply"
  exit 0
fi

for index in {1..2}; do
  [[ "${states[$index]}" == "create" ]] || continue

  command mkdir -p "${parents[$index]}"

  # Revalidación inmediatamente antes de enlazar: ln nunca recibe -f.
  if [[ -e "${destinations[$index]}" || -L "${destinations[$index]}" ]]; then
    die "El destino apareció después del preflight; no se sobrescribió: ${destinations[$index]}"
  fi

  command ln -s "${sources[$index]}" "${destinations[$index]}"
done

print -r -- ""
print -r -- "Instalación de enlaces terminada."

if (( ! ${path[(Ie)$bin_parent]} )); then
  print -r -- "Aviso: $bin_parent no está en PATH."
  print -r -- 'Añade manualmente a ~/.zshrc: export PATH="$HOME/.local/bin:$PATH"'
fi
