# Diseño de nvim-writing

Este documento registra la arquitectura y sus decisiones. Está escrito para que
una persona u otro LLM pueda modificar la configuración sin romper contratos
implícitos. Antes de un cambio estructural se deben leer este archivo,
`GETTING_STARTED.md`, `docs/UPDATING.md` y el diff actual de Git.

## Objetivo y límites

`nvim-writing` es un perfil separado del Neovim de programación, enfocado en:

- Notas TXT y Markdown.
- Ensayos y documentos con formato.
- Markdown y Typst con live preview en navegador.
- Typst con LSP y PDF.
- DOCX mediante Pandoc.
- Guiones mediante plantillas locales.
- Ortografía y gramática en español e inglés.
- Bibliografías BibLaTeX y citas.
- Git, LazyGit, Oil y búsquedas fuzzy.

No pretende ser una distribución general de programación ni un editor WYSIWYG.
Typst es la fuente canónica para PDF con maquetación precisa. Cuando DOCX editable
sea el entregable principal, Markdown + Pandoc es la ruta canónica. La conversión
Typst → DOCX es semántica y puede perder detalles visuales.

## Contrato de versión

La versión soportada y recomendada es **Neovim 0.12.4**. El lanzador fija esta
versión mediante `ASDF_NEOVIM_VERSION`, sin cambiar el Neovim que abre `nvim`.
Toda actualización debe seguir `docs/UPDATING.md`.

## Separación de responsabilidades

| Zona | Contenido | Git |
|---|---|---|
| Repositorio | Lua, lockfile, plantillas maestras y documentación | Sí |
| Runtime XDG | Plugins, Mason, caché, estado, ShaDa y undo | No |
| Proyectos | Fuentes, referencias, imágenes y `build/` | Decisión de cada proyecto |
| Temporales | Preview y archivos transitorios | No |

Instalación sugerida:

```text
$HOME/nvim-writing
  repositorio

$HOME/.config/nvim-writing
  symlink al repositorio

$HOME/.local/bin/nvwrite
  symlink al lanzador bin/nvwrite
```

`nvwrite` establece `NVIM_APPNAME=nvim-writing`. Por tanto `stdpath("config")`,
`data`, `state` y `cache` quedan aislados del perfil de programación.

## Invariantes

No se deben cambiar accidentalmente estas reglas:

1. `nvim` nunca carga este perfil; `nvwrite` nunca carga el perfil de programación.
2. Los documentos no se guardan dentro de la configuración automáticamente.
3. `:WriteNew` copia una plantilla a una ruta explícita y jamás crea symlinks.
4. Actualizar o borrar la configuración no cambia proyectos ya creados.
5. El output predeterminado está en `<root>/build/`.
6. `main`, `buildDir`, bibliografía y reference DOCX deben permanecer dentro del root.
7. Ningún comando cambia el `cwd` global como efecto secundario.
8. Ningún comando concatena rutas dentro de una orden de shell; se usa `vim.system(argv)`.
9. `.writing.json` y `.editorconfig` son datos; no se ejecuta `.nvim.lua` ni `exrc`.
10. Git nunca hace `init`, commit, push o reset automáticamente.
11. `lazy-lock.json` cambia únicamente durante mantenimiento deliberado.
12. Oil es el explorador; no se habilita Snacks Explorer.
13. fzf-lua es el finder; no se instala Telescope o Snacks Picker en paralelo.
14. Cada tab visible es una tabpage nativa, no un buffer disfrazado.
15. El nombre de la tab es `parent/file.ext`, derivado de su ventana activa.
16. PDF es la salida canónica de Typst; DOCX no promete fidelidad pixel-perfect.
17. El historial visual usa `nvim.undotree`, incluido en Neovim 0.12; no se
    reinstala `mbbill/undotree`.
18. El servidor Markdown escucha sólo en `127.0.0.1`, usa un puerto efímero,
    confina rutas/symlinks al webroot, valida el `Origin` del WebSocket, cierra
    todos sus clientes al detenerse y aplica una CSP sin scripts inline ni red
    externa.

## Modelo de documentos y raíz

Un archivo puede abrirse directamente en cualquier ruta:

```sh
nvwrite ~/Documents/notas/idea.md
nvwrite /Volumes/Trabajo/guion/main.typ
```

Un proyecto generado se parece a:

```text
mi-ensayo/
├── .writing.json
├── main.typ
├── template.typ
├── references.bib
├── assets/
└── build/
```

Manifest v1:

```json
{
  "schemaVersion": 1,
  "main": "main.typ",
  "buildDir": "build",
  "bibliography": "references.bib",
  "referenceDoc": "reference.docx"
}
```

La raíz se resuelve por prioridad, no solamente por cercanía:

1. `.writing.json`.
2. `typst.toml`.
3. `.git`.
4. Directorio del archivo.
5. `cwd` para buffers sin nombre.

`lua/writing/core/project.lua` es la única fuente de verdad. Preview, build,
Pandoc, citas, fzf y LazyGit consumen el mismo contexto. Un manifest inválido
bloquea operaciones que escriben, pero `:WriteRoot` todavía muestra el error.
Las rutas se comprueban tanto léxicamente como mediante el `realpath` del
ancestro existente más cercano; un symlink intermedio no puede sacar main,
build, bibliografía o reference DOCX de la raíz.

## Comandos públicos

| Comando | Contrato |
|---|---|
| `:WriteNew` | Copia una plantilla a un destino nuevo |
| `:WriteRoot` | Muestra root, main, build y bibliografía |
| `:WritePreview` | Inicia preview Markdown o Typst según el main |
| `:WritePreviewStop` | Detiene el preview del formato actual |
| `:WriteBuild[!]` | Genera la salida PDF; `!` guarda buffers del proyecto |
| `:WriteExport[!] pdf\|docx` | Exporta al `build/` validado |
| `:WriteLanguage[!]` | Cambia idioma; `!` persiste metadata |
| `:WriteCitation` | Inserta una clave desde `references.bib` |
| `:WriteFocus` | Alterna Snacks Zen |
| `:WriteHealth` | Ejecuta el provider `checkhealth writing` |

Son API pública. Si se renombran, se deben actualizar mappings y ambos docs.

## Keybindings públicos

`<leader>` es espacio y `<localleader>` es `\`.

| Binding | Acción |
|---|---|
| `<leader>wn/wp/wP/wb` | New, iniciar preview, detener preview, build |
| `<leader>wep/wed` | PDF, DOCX |
| `<leader>wl/wc/wr/wf/wh` | Idioma, cita, root, focus, health |
| `<leader>ff/fs/fc/fo` | Archivos, grep, config, outline |
| `<leader>/` | Buscar en el buffer |
| `<leader><leader>` | Buffers abiertos |
| `<leader>e` y `-` | Oil |
| `<leader>lg/gl` | LazyGit y log |
| `<leader>h/v` | Splits |
| `<leader>u` | Undo tree nativo |
| `<C-h/j/k/l>` | Foco entre ventanas |
| `<C-t>t/c/n/p` | Crear, cerrar, siguiente, anterior tabpage |

## Tabs y Oil

Tabby solamente renderiza la tabline. Las operaciones son `:tabnew`, `:tabclose`,
`:tabnext` y `:tabprevious`; `gt`, `gT` y layouts de múltiples ventanas siguen
siendo nativos. La etiqueta consulta el buffer de la ventana activa y muestra
`parent/file.ext`. No sustituir Tabby por un bufferline sin cambiar y documentar
explícitamente esta invariante.

Oil representa directorios como buffers editables. Sus operaciones se aplican al
guardar y conservan confirmaciones. No añadir un segundo explorador por defecto.

## Undo

Neovim conserva el árbol de undo de forma nativa y `options.lua` habilita
`undofile` bajo `stdpath("state")/undo`, aislado por `NVIM_APPNAME`. La interfaz
visual es el paquete opcional `nvim.undotree` distribuido con Neovim 0.12.4.
`<leader>u` ejecuta `:packadd nvim.undotree` bajo demanda y después `:Undotree`.
No añadir otro plugin de undo sin retirar o justificar esta interfaz.

## Idioma y corrección

Hay dos capas:

- Spell nativo: inmediato, offline y con diccionarios `es`/`en_us`.
- LTeX+: gramática y estilo; idioma principal español.

Prioridad: default → `.editorconfig` → modeline/magic comment → comando manual.
`both` combina diccionarios nativos; LTeX+ necesita un idioma principal. En TXT,
una selección persistida produce una modeline visible porque no hay comentario
neutral. En Markdown la modeline se coloca al final para permanecer dentro de
`modelines=5` sin romper el front matter YAML. Las listas `.add` versionadas son
fuente; sus índices `.add.spl` se regeneran localmente y están ignorados por Git.
`WriteLanguage!` sólo reemplaza el comentario LTeX precedido por el sentinel
`nvim-writing: managed-ltex`; los magic comments manuales dentro de secciones
son contenido del usuario y deben preservarse.

## Typst, Markdown, exportación y citas

- Tinymist: LSP, formato, diagnósticos, referencias y símbolos.
- typst-preview.nvim: preview bajo demanda usando el mismo main/root.
- live-preview.nvim: preview Markdown en el navegador, actualización mientras
  se escribe y scroll sincronizado. Usa el padre de `main.md` como webroot para
  no cambiar el `cwd` global. `writing.core.live_preview` endurece el servidor
  de la versión fijada: liga a localhost y a un puerto efímero, canonicaliza
  cada ruta contra su raíz real y exige el `Origin` local exacto antes de aceptar
  un WebSocket. También cierra y elimina todos los clientes HTTP/WebSocket en su
  ciclo de vida y añade una CSP que permite sólo scripts locales del plugin,
  impide scripts inline y restringe recursos/red al mismo origen. Las pruebas
  deben impedir que una actualización pierda estas garantías.
- Typst CLI: PDF exacto.
- Pandoc: Markdown → DOCX/PDF y Typst → DOCX de mejor esfuerzo. Su lector Typst
  es parcial y puede rechazar imports o macros; no es una ruta de entrega fiable
  para las plantillas Typst complejas.
- `references.bib`: fuente compartida BibLaTeX.
- `reference.docx`: estilos Word opcionales por proyecto.

Las plantillas maestras bajo `templates/` se copian completas. Un proyecto nunca
queda enlazado a ellas. La plantilla de guion es local para evitar cambios
inesperados de paquetes externos; sus márgenes deben revisarse según el destino.

## Organización interna

```text
lua/writing/
├── settings.lua
├── config/
│   ├── options.lua
│   ├── keymaps.lua
│   ├── autocmds.lua
│   └── lazy.lua
├── core/
│   ├── project.lua
│   ├── process.lua
│   ├── templates.lua
│   ├── language.lua
│   ├── live_preview.lua
│   └── commands.lua
├── health.lua
└── plugins/
    ├── ui.lua
    ├── search.lua
    ├── git.lua
    ├── markdown.lua
    ├── writing.lua
    ├── lsp.lua
    └── typst.lua
```

`settings.lua` contiene las preferencias sencillas. La lógica de seguridad no
debe moverse a specs de plugins.

## Protocolo para cambios futuros

Antes de modificar:

1. Leer estos tres documentos y `git status`.
2. Identificar la invariante afectada.
3. Preservar cambios ajenos y hacer el cambio mínimo.
4. No actualizar plugins incidentalmente.
5. Probar un archivo suelto y un proyecto generado fuera del repo.
6. Probar rutas con espacios y caracteres de shell.
7. Actualizar docs si cambia la API pública.
8. Ejecutar `tests/smoke.lua`, `:WriteHealth` y la matriz de `docs/UPDATING.md`.

Para añadir un idioma, extiende únicamente el mapa de `language.lua`, el
completado y las pruebas. Para añadir una plantilla, crea una carpeta autocontenida,
regístrala en `templates.lua` y compila una copia externa. Para añadir un plugin,
demuestra que cubre una capacidad ausente y revisa conflictos de mappings.
