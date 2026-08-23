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
   `DESIGN.md` y `GETTING_STARTED.md`.
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
mínima requerida de `tree-sitter-cli`.

## Mason, Typst y Pandoc

Actualiza Tinymist y LTeX+ por separado desde `:Mason`. Después reinicia, revisa
`:LspInfo` y prueba Typst y ambos idiomas.

Al actualizar Typst, compila copias de document, essay y screenplay, abre el
preview y revisa visualmente márgenes, fuentes y saltos. No actualices a la vez
paquetes de una plantilla.

Al actualizar Pandoc, genera Markdown → DOCX y prueba Typst → DOCX; abre los
resultados en Word o LibreOffice. Registra si el lector parcial sigue rechazando
imports o macros conocidos. Exit code 0 no sustituye la inspección visual.

## Matriz mínima

1. `nvim` abre la configuración de programación y `nvwrite` esta configuración.
2. Abrir una nota externa y probar spell español/inglés.
3. Abrir Oil y un directorio externo.
4. Crear/cambiar/cerrar tabpages; verificar `parent/file.ext` y múltiples splits.
5. Probar archivos, grep, buffer y outline con fzf.
6. Abrir LazyGit en un repositorio de prueba.
7. Crear un proyecto Typst fuera del repo con `:WriteNew`.
8. Preview y PDF desde Typst; DOCX desde Markdown. Registrar aparte el resultado
   de Typst → DOCX como capacidad de mejor esfuerzo.
9. Insertar una cita.
10. Ejecutar `:WriteRoot`, `:WriteHealth`, `:checkhealth` y `tests/smoke.lua`.

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
