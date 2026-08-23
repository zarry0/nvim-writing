# Getting started

## Instalación actual

Versión soportada y recomendada:

```text
Neovim 0.12.4
```

El repositorio está en:

```text
/Users/roweller/nvim-writing
```

La instalación usa:

```text
~/.config/nvim-writing  -> repositorio
~/.local/bin/nvwrite    -> bin/nvwrite
```

El lanzador fija Neovim 0.12.4 con ASDF solamente para este perfil. `nvim`
continúa cargando la configuración de programación. Fuera de este repositorio
también conserva la versión ASDF global; dentro del repositorio, `.tool-versions`
selecciona 0.12.4 como es normal en ASDF.

Instalación manual equivalente:

```sh
asdf install neovim 0.12.4
asdf install tree-sitter 0.26.1
ln -s /ruta/al/repo ~/.config/nvim-writing
ln -s /ruta/al/repo/bin/nvwrite ~/.local/bin/nvwrite
```

Dependencias externas:

```text
git, typst, pandoc >= 3.10, fzf, rg, fd, lazygit, tree-sitter >= 0.26.1
```

Mason gestiona Tinymist y LTeX+. El primer arranque necesita Internet para Lazy,
Mason, parsers y componentes de los previews.

## Primer arranque

```sh
nvwrite
```

Después ejecuta:

```vim
:Lazy sync
:Mason
:WriteHealth
```

Si Mason acaba de instalar Tinymist, reinicia `nvwrite` antes del primer preview.
Pulsa `<Space>?` para ver bindings. `<leader>` es espacio.

## Archivos en cualquier ruta

```sh
nvwrite ~/Documents/notas/idea.md
nvwrite ~/Desktop/borrador.txt
nvwrite /Volumes/Trabajo/guion/main.typ
```

Guarda con `:w`. Nada se copia al repositorio de configuración.

## Crear un proyecto

Interactivo:

```vim
:WriteNew
```

Explícito:

```vim
:WriteNew typst-essay ~/Documents/Ensayos/el-tiempo
:WriteNew typst-screenplay ~/Documents/Guiones/corto
:WriteNew markdown-document ~/Documents/Informes/informe
```

También existen los alias breves `essay`, `document` y `screenplay`, que crean
la variante Typst correspondiente.

Plantillas disponibles:

```text
typst-document
typst-essay
typst-screenplay
markdown-document
markdown-essay
```

El destino debe ser nuevo. La copia es independiente y no se hace `git init`.
Usa `<Space>wn` para el selector y `<Space>wr` para ver root/main/build.

## Preview live

| Acción | Binding | Comando |
|---|---|---|
| Iniciar o abrir preview | `<Space>wp` | `:WritePreview` |
| Detener preview | `<Space>wP` | `:WritePreviewStop` |

El mismo binding selecciona el motor según el documento principal:

- Markdown usa `live-preview.nvim` y abre el navegador predeterminado. Actualiza
  el contenido mientras escribes, sincroniza el scroll y sirve únicamente en
  `127.0.0.1`, en un puerto efímero elegido para esa sesión.
- Typst usa `typst-preview.nvim` y respeta el `main` y el root resueltos por el
  proyecto.

Los comandos directos de Markdown son `:LivePreview start` y
`:LivePreview close`; normalmente conviene usar los comandos `Write` para que
ambos formatos conserven la misma interfaz.

Para Markdown, el webroot es el directorio de `main.md`. Esto funciona con las
plantillas incluidas, donde `main.md` vive en la raíz. Conserva imágenes y otros
recursos dentro de ese árbol para que el navegador pueda servirlos. La capa de
configuración rechaza rutas y symlinks que escapen de esa raíz, y sólo acepta el
WebSocket procedente de la URL local exacta que abrió el preview. Una política
CSP bloquea scripts inline y conexiones externas dentro del Markdown; por eso
las imágenes y demás recursos del preview deben guardarse localmente en el
proyecto en vez de depender de URLs remotas.

## Typst y exportación

| Acción | Binding | Comando |
|---|---|---|
| Compilar PDF | `<Space>wb` | `:WriteBuild` |
| Exportar PDF | `<Space>wep` | `:WriteExport pdf` |
| Exportar DOCX | `<Space>wed` | `:WriteExport docx` |

La salida se guarda en `build/`. Si hay cambios sin guardar, el build se detiene;
`:WriteBuild!` guarda solamente buffers del proyecto.

Typst → DOCX es sólo una conversión de mejor esfuerzo. El lector Typst de Pandoc
es parcial: puede rechazar imports, funciones o macros de maquetación, y aunque
termine no conserva el aspecto exacto. Esto afecta especialmente plantillas
complejas como la de guion. PDF es la salida canónica de esas plantillas.

Para un DOCX editable confiable, parte de una plantilla Markdown y añade un
`reference.docx` en la raíz. Pandoc lo utilizará automáticamente.

La plantilla de guion prefiere Courier Prime y usa fallbacks si no está
instalada. Instala esa fuente si necesitas métricas tipográficas de guion más
predecibles entre equipos.

## Idiomas

```vim
:WriteLanguage es
:WriteLanguage en
:WriteLanguage both
:WriteLanguage off
```

Sin `!`, afecta la sesión. Con `!`, inserta metadata persistente:

```vim
:WriteLanguage! en
```

Selector: `<Space>wl`. Para un directorio completo usa `.editorconfig`:

```ini
root = true

[*.{txt,md,typ}]
spelling_language = es

[english/**]
spelling_language = en-US
```

`both` activa ambos diccionarios nativos; LTeX+ conserva español como idioma
principal y puede cambiarse por sección mediante magic comments. `off`
desconecta LTeX+ del buffer además de apagar el corrector nativo; seleccionar
otro idioma vuelve a conectarlo.

Sobre una palabra, `zg` la añade a la lista personal portable del idioma actual;
`zug` deshace esa adición. Esas listas viven en `wordlists/` y sí forman parte
del repositorio Git de la configuración.

## Citas

Añade entradas a `references.bib`:

```bibtex
@book{borges_ficciones_1944,
  author = {Jorge Luis Borges},
  title = {Ficciones},
  year = {1944}
}
```

Pulsa `<Space>wc` o ejecuta `:WriteCitation`. La inserción será `@clave` en
Typst, `[@clave]` en Markdown y `\cite{clave}` en LaTeX.

## Oil

`<Space>e` o `-` abre Oil. Dentro de Oil:

| Tecla | Acción |
|---|---|
| `<CR>` | Abrir entrada |
| `-` | Directorio padre |
| `g?` | Ayuda |
| `:w` | Aplicar operaciones pendientes |

Editar líneas prepara operaciones reales de archivos; revisa la confirmación al
guardar.

## Tabs nativas

La barra superior representa tabpages reales. Cada tab conserva su layout de
ventanas y muestra el buffer activo como `parent/file.ext`.

| Binding | Acción |
|---|---|
| `<C-t>t` | Nueva tabpage |
| `<C-t>c` | Cerrar tabpage |
| `<C-t>n` | Siguiente |
| `<C-t>p` | Anterior |

También funcionan `gt`, `gT`, `:tabmove` y los comandos nativos de Neovim.

## Undo tree nativo

`<Space>u` carga bajo demanda el paquete `nvim.undotree` incluido en Neovim
0.12.4 y abre o cierra `:Undotree`. No se instala `mbbill/undotree`.

Al mover el cursor por el árbol, el documento cambia al estado seleccionado.
El historial sigue siendo el undo nativo de Neovim y se conserva entre sesiones
en el directorio de estado aislado de `nvim-writing`.

## Ventanas, búsquedas y Git

| Binding | Acción |
|---|---|
| `<Space>h/v` | Split horizontal/vertical |
| `<C-h/j/k/l>` | Mover foco |
| `<Space>ff` | Archivos desde el root |
| `<Space>fs` | Buscar texto desde el root |
| `<Space>/` | Buscar en el buffer |
| `<Space><Space>` | Buffers |
| `<Space>fo` | Outline Tinymist/LSP |
| `<Space>lg` | LazyGit en el root Git |
| `<Space>gl` | Log de Git |
| `<Space>wf` | Modo concentración |
| `<Space>u` | Undo tree nativo |

Gitsigns usa `]h`/`[h` para navegar hunks y el grupo `<Space>g` para acciones.

## Diagnóstico rápido

```vim
:WriteHealth
:checkhealth
:checkhealth livepreview
:LspInfo
:Mason
:Lazy
```

Verifica el aislamiento:

```vim
:lua print(vim.env.NVIM_APPNAME)
:lua print(vim.fn.stdpath("config"))
```

Deben mostrar `nvim-writing` y `~/.config/nvim-writing`. Para problemas de
actualización o rollback, sigue `docs/UPDATING.md`.

Desde el repositorio puedes repetir la prueba automatizada con:

```sh
nvwrite --headless "+luafile tests/smoke.lua" +qa
```
