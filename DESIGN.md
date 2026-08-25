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

${XDG_CONFIG_HOME:-$HOME/.config}/nvim-writing
  symlink al repositorio

$HOME/.local/bin/nvwrite
  symlink al lanzador bin/nvwrite
```

`nvwrite` establece `NVIM_APPNAME=nvim-writing`. Por tanto `stdpath("config")`,
`data`, `state` y `cache` quedan aislados del perfil de programación.

`bin/install-links.zsh` implementa esa separación. Descubre el checkout desde su
propia ruta, funciona aunque el repositorio esté en otro lugar y hace un dry-run
por defecto. Antes de cambiar el filesystem inspecciona ambos destinos. Sólo
crea los directorios padre ausentes y symlinks absolutos cuando se invoca con
`--apply`; nunca elimina, mueve, renombra, sobrescribe o edita archivos del
shell. Un destino ocupado, un symlink diferente o uno roto cancela toda la
operación antes de crear enlaces. También rechaza un `HOME` o
`XDG_CONFIG_HOME` que sea `/` o que resuelva ahí mediante symlinks.

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
19. El instalador de enlaces es no destructivo, idempotente y hace preflight de
    todos los destinos; no toca la configuración de programación ni `.zshrc`.
20. El tema claro/oscuro es local a este repositorio; no depende de un
    colorscheme externo ni modifica el perfil de programación.
21. UI, statusline, terminal e iconos son monocromáticos. Los acentos se aplican
    sólo a capturas de estructura/sintaxis calificadas para Markdown, Typst y
    LaTeX; spell conserva exclusivamente un undercurl rojo.
22. Tabby no añade número, icono o branding a las tabs: muestra
    `parent/file.ext` y el botón `×` sobre tabpages nativas.
23. El contador de la barra mide prosa semántica del buffer actual sin guardar;
    nunca usa `wordcount()` bruto para Markdown, Typst o LaTeX, ni cuenta código,
    fórmulas, URLs, claves de cita o bibliografía generada.
24. Las consultas externas abren URLs mediante `vim.ui.open`; nunca interpolan
    la selección en un shell. Sólo la consulta elegida sale al proveedor.

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
| `:WriteTheme [dark\|light\|toggle]` | Cambia el tema de la sesión |
| `:WriteGoogle [consulta]` | Abre Google con argumento, palabra o selección |
| `:WriteDictionary [es\|en] [consulta]` | Abre RAE/Merriam-Webster o selector |
| `:WriteSpellAdd [palabra]` | Añade al diccionario personal del idioma elegido |
| `:WriteSpellRemove [palabra]` | Retira del diccionario personal elegido |
| `:WriteSpellIgnore [palabra]` | Ignora la palabra sólo en el archivo actual |
| `:WriteSpellUnignore [palabra]` | Retira la excepción del archivo actual |
| `:WriteFocus` | Alterna Snacks Zen |
| `:WriteHealth` | Ejecuta el provider `checkhealth writing` |

Son API pública. Si se renombran, se deben actualizar mappings y ambos docs.

## Keybindings públicos

`<leader>` es espacio y `<localleader>` es `\`.

| Binding | Acción |
|---|---|
| `<leader>wn/wp/wP/wb` | New, iniciar preview, detener preview, build |
| `<leader>wep/wed` | PDF, DOCX |
| `<leader>wl/wc/wr/wf/wh/wt` | Idioma, cita, root, focus, health, theme |
| `<leader>wg/wd` | Google y diccionario; normal o selección visual |
| `<leader>ws/wa/wA` | Sugerencias, añadir y retirar del diccionario personal |
| `<leader>wi/wI` | Ignorar y volver a comprobar sólo en el archivo actual |
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

## Tema y UI

`lua/writing/core/theme.lua` implementa dos variantes del tema local
`writing-monochrome`; `:WriteTheme` no llama a un colorscheme de terceros. La
variante inicial está en `settings.theme_variant`.

Paleta oscura, inspirada en GitHub Monochrome:

```text
bg #0D1117  panel #161B22/#21262D  border #30363D
fg #F0F0F0  muted #8B949E          faint #484F58
```

Paleta clara basada en la referencia proporcionada:

```text
bg #FAFAFA  panel #EEF1F4/#E8EBF0  border #DDE2E7
fg #20232A  muted #8790A0          faint #BAC3CB
```

Ambas comparten los acentos `#D05858`, `#BE7E05`, `#608E32`, `#3A8B84`,
`#5079BE` y `#B05CCC`. Spell usa un rojo más visible: `#E17373` en oscuro y
`#D05858` en claro. La base neutraliza
grupos genéricos de UI y código; los acentos documentales se definen con sufijo
`.markdown`, `.markdown_inline`, `.typst` o `.latex`. No crear highlights para
`@spell` o `@nospell`: son capturas de control y un `fg` allí puede ocultar las
capturas estructurales superpuestas. Tinymist también requiere overrides
`@lsp.type.*.typst`, pero no se define `@lsp.type.text.typst`: ese token de alta
prioridad taparía headings y otras capturas Treesitter. El override
`@lsp.type.heading.typst` conserva el acento estructural.

El cursor tiene forma explícita y `CursorLine` visible; `number` y
`relativenumber` permanecen activos. Devicons conserva los glifos con
`color_icons=false`. Oil, fzf, diagnósticos, Git, búsquedas y terminal usan sólo
neutros. El quote body, strong e italic conservan el color de la prosa; sólo sus
marcadores/atributos estructurales reciben estilo o acento.

Lualine es plana y no usa extensiones, porque las extensiones de Lazy, Mason,
Oil y quickfix reintroducen contenido. Su contrato es:

```text
a: modo | b: vacío | c: parent/file.ext [+]
x: conteo semántico + idioma | y: progreso | z: vacío
```

El listener de `theme.on_change` vuelve a aplicar sólo el tema plano de Lualine.

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

`writing.core.spell` ordena `spellfile` según los tokens efectivos de
`spelllang`. `WriteSpellAdd/Remove` usa explícitamente la entrada ES o EN; si
ambas están activas muestra un selector, y después sincroniza esas listas con
`ltex.dictionary`. Esto evita la semántica nativa de `zg`, que sin count siempre
escribe en la primera entrada.

LTeX+ asigna `MORFOLOGIK_RULE_ES` y `MORFOLOGIK_RULE_EN_US` a severidad error,
y `DiagnosticUnderlineError` usa el mismo rojo de `SpellBad`. El resto de reglas
permanece en severidad information y con underline neutral; amarillo/azul no se
asignan hasta definir una taxonomía editorial explícita por rule ID.

Una excepción de archivo no usa `zG`: la lista interna de Neovim alcanzaría
otros buffers y se perdería al salir. Se persiste en
`<writing-root>/.nvim-writing-spell.json`, schema 1, como mapa de ruta relativa a
palabras. Extmarks buffer-locales con `spell=false` cubren cada ocurrencia exacta
y se recalculan tras editar; el handler de diagnósticos omite únicamente rangos
LTeX+ cuyo texto coincide exactamente. El sidecar sólo se crea al solicitar una
excepción, tiene límite de 64 KiB/1024 palabras por archivo y se publica mediante
temporal adyacente. Los términos formados por caracteres de palabra se buscan en
una sola pasada por línea; los que incluyen puntuación se limitan a 32 por
archivo. Antes de publicar se compara otra vez el contenido leído, evitando
pisar una actualización concurrente detectada. Rutas inseguras, JSON/schema
inválido, archivos grandes, directorios y symlinks bloquean la operación sin ser
reemplazados. `FocusGained` recarga cambios externos y resincroniza LTeX+ cuando
la lista efectiva cambia.

## Conteo semántico de prosa

`lua/writing/core/word_count.lua` mantiene caché por buffer y `changedtick`, con
debounce de 450 ms. TXT se procesa en memoria. Markdown, Typst y LaTeX se envían
sin guardar por stdin a un proceso local:

```text
pandoc --from=<reader> --to=json --standalone --wrap=none
       --lua-filter=scripts/pandoc-prose.lua
```

Se usa `vim.system` con argv y `cwd` igual al directorio del archivo; no hay
shell ni red. Esto permite resolver imports/includes relativos sin cambiar el
`cwd` global. El filtro conserva prosa visible y metadata `title`, `subtitle`,
`author`, `date` y `abstract`; elimina Code/CodeBlock, Math, Raw, Image, URLs,
claves de cita y el bloque `refs` generado. En Cite sólo conserva prefijos o
sufijos escritos alrededor de la clave. Lua recorre después únicamente nodos
AST `Str`: números de listas, marcadores de notas y demás estructura del writer
no existen como palabras. Dentro de cada `Str`, la clase Vim
`\%#=2[^[:lower:][:upper:][:digit:]]\+` fuerza el motor Unicode y separa
corridas en tiempo lineal sin depender de `iskeyword` del buffer activo. No usa
tokens separados únicamente por espacios ni substrings sucesivos de costo
cuadrático. No usar
`\\W`: separa de forma inconsistente algunas letras acentuadas.

El reader Markdown conserva `implicit_figures`. `Figure` se reemplaza por su
contenido visible más su caption e `Image` se elimina; así un pie de figura
aislado cuenta, pero el alt text de una imagen inline no. Conservar el contenido
es necesario para figuras Typst cuyo cuerpo puede ser texto o tablas. Las tres
rutas tienen fixtures separados.

El resultado es del buffer actual, no del proyecto entero. La fuente del buffer
puede estar sin guardar; imports abiertos en otros buffers se leen del disco.
Tiempo máximo: 2.5 s. Tamaño máximo: 2 MiB. Durante una invalidación o tras un
error se conserva el último éxito como `~N palabras`; sin éxito previo se muestra
`… palabras`. Pandoc es una aproximación semántica para Typst avanzado, no el
motor de layout; `typst-essay` y fixtures representativos de Markdown, Typst y
LaTeX están cubiertos por conteos exactos en el smoke.

## Consultas externas

`lua/writing/core/lookup.lua` toma `<cword>` o una selección mediante
`getregion`, sin yank ni modificación de registros. Un encoder RFC3986 byte a
byte deja sin escapar únicamente `[A-Za-z0-9._~-]`; así `&`, `/`, `?`, `#`, `%`
y UTF-8 no pueden cambiar la estructura de la URL.

- Google: `https://www.google.com/search?q=...`.
- Español: `https://dle.rae.es/...`.
- Inglés: `https://www.merriam-webster.com/dictionary/...`.

El diccionario infiere tokens reales de `spelllang`; una combinación bilingüe,
`off` o idioma desconocido abre selector. `vim.ui.open` delega al navegador del
sistema. El documento nunca se envía completo, pero la palabra/frase consultada
sí se comparte con el proveedor y esta frontera de privacidad debe permanecer
documentada.

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
queda enlazado a ellas. La plantilla de guion es una implementación local del
repositorio, bajo su licencia MIT; no importa un paquete de Typst Universe. Su
API pública actual es `screenplay`, `scene`, `action`, `dialogue` y `transition`.
Se mantiene local para evitar cambios inesperados de paquetes externos, pero no
se presenta como estándar profesional: sus márgenes y capacidades deben
revisarse según el destino.

## Organización interna

```text
bin/
├── nvwrite
└── install-links.zsh
scripts/
└── pandoc-prose.lua
tests/
├── smoke.lua
└── install-links.zsh

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
│   ├── spell.lua
│   ├── live_preview.lua
│   ├── theme.lua
│   ├── word_count.lua
│   ├── lookup.lua
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
8. Si cambia tema/TS, probar ambas variantes y Markdown/Typst/LaTeX.
9. Si cambia el contador, probar fixtures con markup, código, math, URLs, citas y
   bibliografía, además de contenido sin guardar y estado `~`.
10. Ejecutar `tests/smoke.lua`, `:WriteHealth` y la matriz de `docs/UPDATING.md`.

Para añadir un idioma, extiende únicamente el mapa de `language.lua`, el
completado y las pruebas. Para añadir una plantilla, crea una carpeta autocontenida,
regístrala en `templates.lua` y compila una copia externa. Para añadir un plugin,
demuestra que cubre una capacidad ausente y revisa conflictos de mappings.
