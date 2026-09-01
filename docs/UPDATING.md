# Protocolo de actualización

El principio central es actualizar una sola capa por vez: Neovim, plugins,
Mason, herramientas CLI o plantillas. No se mezclan salvo dependencia explícita.

## Estado conocido antes de empezar

```sh
git status --short
git branch --show-current
NVWRITE_NEOVIM_VERSION=0.12.4 nvwrite --version
typst --version
pandoc --version
tree-sitter --version
```

Dentro de Neovim:

```vim
:WriteHealth
:checkhealth
:LspInfo
```

El lockfile debe estar versionado y los cambios ajenos identificados. Crea una
rama `maintenance/update-YYYY-MM-DD`; opcionalmente etiqueta el último estado
bueno.

## Actualizar Neovim sin romper el perfil

1. Lee las release notes oficiales y revisa LSP, Treesitter y APIs eliminadas.
2. Instala el candidato sin cambiar la versión global:

   ```sh
   asdf install neovim X.Y.Z
   asdf where neovim X.Y.Z
   ```

3. Pruébalo mediante el override del launcher:

   ```sh
   NVWRITE_NEOVIM_VERSION=X.Y.Z nvwrite --version
   NVWRITE_NEOVIM_VERSION=X.Y.Z nvwrite
   ```

4. Para no tocar el runtime estable, usa XDG temporal:

   ```sh
   trial_root="$(mktemp -d)"
   mkdir -p "$trial_root/config"
   ln -s "$PWD" "$trial_root/config/nvim-writing"
   XDG_CONFIG_HOME="$trial_root/config" \
   XDG_DATA_HOME="$trial_root/data" \
   XDG_STATE_HOME="$trial_root/state" \
   XDG_CACHE_HOME="$trial_root/cache" \
   NVIM_APPNAME=nvim-writing \
   ASDF_NEOVIM_VERSION=X.Y.Z \
   nvim
   ```

5. Ejecuta la matriz de pruebas de abajo.
6. Si pasa, actualiza juntos `bin/nvwrite`, `.tool-versions`, `settings.lua`,
   `README.md`, `DESIGN.md` y `GETTING_STARTED.md`.
7. No desinstales la versión anterior hasta haber usado la nueva.

Rollback: ejecuta `NVWRITE_NEOVIM_VERSION=VERSION_ANTERIOR nvwrite` y revierte el
commit de actualización. No es necesario cambiar el Neovim global.

## Plugins

`lazy-lock.json` es la fuente de verdad. Actualiza un plugin individual siempre
que sea posible, reinicia, prueba y revisa:

```sh
git diff -- lazy-lock.json
```

Una actualización completa sólo se hace en rama con `:Lazy update`. Para volver:
restaura/revierte `lazy-lock.json` y ejecuta `:Lazy restore`. No uses
`git reset --hard`.

Cuando cambie nvim-treesitter, ejecuta `:TSUpdate` en la misma actualización del
plugin porque sus parsers y queries deben coincidir. Registra también la versión
mínima requerida de `tree-sitter-cli`. Verifica capturas calificadas en los cinco
parsers declarados: Markdown, Markdown inline, Typst, LaTeX y BibTeX. Una captura
genérica nueva no debe introducir acentos fuera de Markdown/Typst/LaTeX.

`live-preview.nvim` requiere atención especial: `writing.core.live_preview`
envuelve las APIs internas `Server:routes`, `handler.serve_file` y
`websocket.handshake` para aplicar las garantías de seguridad documentadas. No
muevas su commit fijado sin revisar esas APIs y ejecutar el smoke completo. Si
upstream incorpora protecciones equivalentes, retira el wrapper sólo después de
conservar y pasar las pruebas de traversal, symlinks, `Origin`, CSP y cierre de
clientes al detener el servidor.

## Mason, Typst y Pandoc

Actualiza Tinymist y LTeX+ por separado desde `:Mason`. Después reinicia, revisa
`:LspInfo` y prueba Typst y ambos idiomas.

Al actualizar Typst, compila copias de document, essay y screenplay, abre el
preview y revisa visualmente márgenes, fuentes y saltos. No actualices a la vez
paquetes de una plantilla.

Al actualizar Pandoc, genera Markdown → DOCX y prueba Typst → DOCX; abre los
resultados en Word o LibreOffice. Registra si el lector parcial sigue rechazando
imports o macros conocidos. Exit code 0 no sustituye la inspección visual.

Pandoc también alimenta el contador semántico mediante
`scripts/pandoc-prose.lua`. Antes de aceptar una actualización, ejecuta los
fixtures exactos del smoke y confirma que metadata técnica, código, math, URLs,
alt text inline, claves de cita y bibliografía generada siguen excluidos, y que
los pies de figura visibles sí cuentan. Prueba stdin
sin guardar, imports relativos y un error de parse: debe conservarse `~N`, no
reemplazarse por un conteo bruto del source.

## Matriz mínima

1. Validar el instalador con `zsh -n bin/install-links.zsh` y
   `zsh tests/install-links.zsh`: dry-run, aplicación, idempotencia, paths con
   espacios, `XDG_CONFIG_HOME` y conflictos deben conservarse no destructivos.
2. `nvim` abre la configuración de programación y `nvwrite` esta configuración.
3. Abrir una nota externa y probar spell español/inglés: `<leader>ws`, alta y
   baja ES/EN con `<leader>wa/wA`, y excepción local con `<leader>wi/wI`. La
   excepción sólo debe afectar su archivo; JSON inválido o symlink no debe
   sobrescribirse. Verificar también que LTeX+ respete diccionarios y excepción.
4. Abrir Oil y un directorio externo.
5. Crear/cambiar/cerrar tabpages; verificar `parent/file.ext` y múltiples splits.
   La barra no debe mostrar número o branding y debe conservar `×` con dos o más
   tabs.
6. Probar archivos, grep, buffer y outline con fzf.
7. Abrir LazyGit en un repositorio de prueba.
8. Crear con `<leader>wn` un proyecto Typst fuera del repo y en una ruta con
   espacios. Debe abrir `main.typ` sin `E523`, aplicar `spelllang=es` y seleccionar
   únicamente el `spellfile` ES.
9. En una línea lógica larga con wrap, comprobar que `j/k` sin conteo recorren
   renglones visuales; desde la línea lógica 5, `4j` debe llegar a la 9 y `4k`
   debe regresar a la 5, en concordancia con los números relativos.
10. Preview y PDF desde Typst; preview y DOCX desde Markdown. En Markdown,
   confirmar que el servidor usa `127.0.0.1`, un puerto efímero, bloquea path
   traversal y symlinks, rechaza WebSockets cross-origin, envía la CSP esperada
   y no conserva clientes al ejecutar `:WritePreviewStop`.
11. Abrir `<leader>u`, recorrer una rama del undo tree nativo y cerrarlo.
12. Ejecutar `:WriteTheme light`, `dark` y `toggle`: texto y UI deben permanecer
    monocromáticos, syntax documental usar los seis acentos, spell conservar
    undercurl `#E17373` oscuro/`#D05858` claro, cursor/números relativos seguir
    visibles e iconos de Oil/fzf conservar glifo sin color propio.
13. Verificar Lualine: modo, `parent/file.ext [+]`, conteo, idioma y progreso;
    no branch, diff, diagnósticos, LSP, filetype o location.
14. Probar conteos exactos TXT/Markdown/Typst/LaTeX y la invalidación `~N` con
    cambios sin guardar.
15. Con `vim.ui.open` simulado, probar `<leader>wg/wd` en normal/visual, UTF-8 y
    caracteres reservados. Una prueba manual puede abrir Google/RAE/Merriam,
    usando sólo texto no sensible.
16. Registrar aparte Typst → DOCX como capacidad de mejor esfuerzo.
17. Insertar una cita.
18. Ejecutar `:WriteRoot`, `:WriteHealth`, `:checkhealth`,
    `:checkhealth livepreview` y `tests/smoke.lua`.

## Rollback por capa

| Capa | Acción |
|---|---|
| Lua/docs | `git revert` del commit |
| Neovim | Override `NVWRITE_NEOVIM_VERSION` anterior |
| Plugins | Lockfile anterior + `:Lazy restore` |
| Mason | Reinstalar la versión registrada |
| Typst/Pandoc | Seleccionar paquete anterior |
| Plantilla | Revertir maestra; proyectos creados no cambian |

Una actualización termina sólo cuando las pruebas pasan, el diff es intencional,
la documentación coincide y la versión anterior sigue disponible.
