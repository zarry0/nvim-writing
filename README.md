# nvim-writing

Perfil de Neovim independiente y portable para notas, ensayos, documentos Typst,
guiones, citas y exportación PDF/DOCX.

- Versión soportada: Neovim 0.12.4.
- Lanzador: `nvwrite` (`NVIM_APPNAME=nvim-writing`).
- Explorador: Oil.
- Tabs: tabpages nativas dibujadas por Tabby.
- Tema: monocromático local, claro/oscuro con `:WriteTheme`.
- Statusline: modo, archivo, prosa escrita, idioma y progreso.
- Preview live: Markdown en navegador y Typst.
- Undo: árbol nativo incluido en Neovim 0.12.4.
- Ortografía: español/inglés, listas personales portables y excepciones por archivo.
- Consultas: Google, RAE y Merriam-Webster desde palabra o selección.
- Documentos: siempre fuera de este repositorio, salvo elección explícita.

## Instalación en otra computadora (macOS/Linux, zsh)

La instalación recomendada conserva tres zonas separadas:

```text
checkout Git                  $HOME/nvim-writing (o cualquier otra ruta)
configuración de Neovim       ${XDG_CONFIG_HOME:-$HOME/.config}/nvim-writing
lanzador                      $HOME/.local/bin/nvwrite
```

Los dos últimos paths serán symlinks al checkout. Los plugins, LSP, caché y undo
se reconstruyen fuera del repositorio; tus documentos tampoco viven dentro de
él.

### 1. Instala los requisitos externos

Necesitas `zsh`, `git`, `asdf`, `typst`, `pandoc >= 3.10`, `fzf`, `rg`, `fd` y
`lazygit`, además de un navegador. En macOS, por ejemplo:

```zsh
brew install git asdf typst pandoc fzf ripgrep fd lazygit
```

En Linux instala los mismos ejecutables con el gestor de tu distribución o sus
instaladores oficiales. En Debian/Ubuntu comprueba que exista el comando `fd`:
algunas versiones del paquete lo publican como `fdfind`. Confirma también que
`asdf` funciona desde zsh antes de seguir. El navegador debe tener un opener
registrado (`xdg-open` o `gio` en Linux) para que preview, Google y diccionarios
se abran automáticamente.

### 2. Clona el repositorio

El destino debe ser nuevo; `git clone` no debe reutilizar un directorio con
archivos:

```zsh
git clone https://github.com/zarry0/nvim-writing.git "$HOME/nvim-writing"
cd "$HOME/nvim-writing"
```

Puedes escoger otra ruta, incluso una con espacios. El instalador descubre la
ubicación a partir de sí mismo y no presupone `$HOME/nvim-writing`.

### 3. Instala las versiones fijadas por ASDF

Añade los plugins sólo si todavía no están registrados y deja que
`.tool-versions` seleccione las versiones soportadas:

```zsh
asdf plugin list | grep -qx neovim || \
  asdf plugin add neovim https://github.com/richin13/asdf-neovim.git
asdf plugin list | grep -qx tree-sitter || \
  asdf plugin add tree-sitter https://github.com/ivanvc/asdf-tree-sitter.git
asdf install
```

Actualmente el perfil fija Neovim 0.12.4 y tree-sitter-cli 0.26.1.

### 4. Previsualiza y crea los enlaces

El instalador es un dry-run por defecto:

```zsh
./bin/install-links.zsh
```

Revisa el plan y aplícalo explícitamente:

```zsh
./bin/install-links.zsh --apply
```

El script valida ambos destinos antes de crear nada. Nunca borra, mueve,
sobrescribe ni edita `.zshrc`; tampoco toca `~/.config/nvim`. Si encuentra un
archivo, directorio, symlink incorrecto o symlink roto, se detiene y te muestra
el conflicto. Ejecutarlo otra vez sobre los enlaces correctos es seguro.

Respeta `XDG_CONFIG_HOME` si está definido. En caso contrario usa
`$HOME/.config`.

### 5. Asegura el launcher en el PATH

Si el instalador avisa que falta `$HOME/.local/bin`, añade manualmente esta línea
a `~/.zshrc`:

```zsh
export PATH="$HOME/.local/bin:$PATH"
```

Abre una terminal nueva o ejecuta `exec zsh`. El instalador no modifica archivos
de inicio del shell.

### 6. Primer arranque

```zsh
nvwrite
```

Después ejecuta dentro de Neovim:

```vim
:Lazy sync
:Mason
:TSUpdate
:WriteHealth
```

Lazy instala los plugins fijados en `lazy-lock.json`; Mason instala Tinymist y
LTeX+. El primer arranque requiere Internet. Si falta el diccionario español,
ejecuta `:set spell spelllang=es` y acepta la descarga que ofrece Neovim.

Reinicia `nvwrite` después de que Mason termine y valida el conjunto desde el
checkout:

```zsh
nvwrite --headless "+luafile tests/smoke.lua" +qa
```

Luego abre la guía de uso:

```zsh
nvwrite GETTING_STARTED.md
```

Dentro de la guía, empieza con `<Space>?` para descubrir bindings. Los accesos
nuevos más importantes son `<Space>wt` para alternar claro/oscuro,
`<Space>wg` para buscar en Google, `<Space>wd` para consultar el diccionario y
`<Space>ws/wa/wi` para sugerir, aceptar o ignorar una palabra localmente.
La barra inferior cuenta prosa semántica de TXT, Markdown, Typst y LaTeX sin
sumar código, fórmulas, URLs, claves de cita ni bibliografía generada.

## Documentación

- [GETTING_STARTED.md](GETTING_STARTED.md): uso diario, comandos y bindings.
- [DESIGN.md](DESIGN.md): estructura, contratos e invariantes.
- [docs/UPDATING.md](docs/UPDATING.md): protocolo para actualizar sin romper el perfil.
