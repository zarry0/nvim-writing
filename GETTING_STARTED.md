# Getting started

## Instalación

Versión soportada y recomendada:

```text
Neovim 0.12.4
```

Ubicación sugerida —no obligatoria— del repositorio:

```text
$HOME/nvim-writing
```

La instalación usa:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/nvim-writing  -> repositorio
$HOME/.local/bin/nvwrite                          -> bin/nvwrite
```

El lanzador solicita Neovim 0.12.4 mediante las variables de ASDF cuando el
comando `asdf` está disponible. Eso afecta solamente a este perfil. `nvim`
continúa cargando la configuración de programación y su versión habitual;
dentro del repositorio, `.tool-versions` también selecciona 0.12.4.

La guía completa para una computadora nueva está en el
[README](README.md#instalación-en-otra-computadora-macoslinux-zsh). Después de
clonar e instalar las versiones de ASDF, ejecuta desde el checkout:

```zsh
./bin/install-links.zsh
./bin/install-links.zsh --apply
```

La primera orden sólo muestra el plan. La segunda crea los enlaces si ambos
destinos están libres. El instalador nunca borra, mueve o sobrescribe contenido,
no edita `.zshrc` y se detiene ante cualquier conflicto. También respeta
`XDG_CONFIG_HOME`.

Si `$HOME/.local/bin` no está en tu `PATH`, añade manualmente a `~/.zshrc`:

```zsh
export PATH="$HOME/.local/bin:$PATH"
```

Dependencias externas:

```text
git, typst, pandoc >= 3.10, fzf, rg, fd, lazygit, tree-sitter >= 0.26.1
navegador + opener del sistema (xdg-open/gio en Linux)
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
:TSUpdate
:WriteHealth
```

Si Mason acaba de instalar Tinymist, reinicia `nvwrite` antes del primer preview.
Pulsa `<Space>?` para ver bindings. `<leader>` es espacio.

## Tema y barra inferior

El tema propio `writing-monochrome` arranca oscuro. Alterna cuando quieras:

| Acción | Binding | Comando |
|---|---|---|
| Alternar claro/oscuro | `<Space>wt` | `:WriteTheme toggle` |
| Usar oscuro | — | `:WriteTheme dark` |
| Usar claro | — | `:WriteTheme light` |

El cambio afecta sólo la sesión. Para cambiar el arranque, edita
`theme_variant = "dark"` o `"light"` en `lua/writing/settings.lua`.

La UI, los iconos de Oil/fzf y la barra son monocromáticos. El texto normal es
claro sobre fondo oscuro o casi negro sobre fondo claro. Los seis acentos de la
paleta se reservan para estructura/sintaxis de Markdown, Typst y LaTeX. Los
errores ortográficos usan únicamente un subrayado ondulado rojo; el cursor y la
línea actual permanecen visibles, y los números relativos siguen activos.

La barra inferior contiene, de izquierda a derecha:

```text
MODO  parent/file.ext [+]        N palabras  ES|EN|ES+EN|OFF  progreso
```

`[+]` significa que el buffer tiene cambios sin guardar. El contador usa el
contenido actual del buffer, incluso antes de `:w`, y calcula prosa semántica:

- incluye títulos, autor, headings, párrafos, listas, citas, pies de figura
  visibles y texto enfatizado;
- excluye markup, comandos, código, fórmulas, URLs, alt text de imágenes inline
  que no se renderiza, claves de cita, metadata técnica y bibliografía generada;
- en TXT excluye la modeline administrada por el perfil.

Para Markdown, Typst y LaTeX el cálculo se hace localmente con Pandoc por stdin,
con 450 ms de debounce; no envía el documento a Internet. Cuenta el buffer
actual, no todos los archivos del proyecto. Imports/includes se resuelven desde
el directorio del archivo y sus cambios en otros buffers deben guardarse para
participar. `~120 palabras` indica que ves el último resultado válido mientras
se recalcula o después de un error; `… palabras` indica que aún no existe un
resultado. La lectura de Typst de Pandoc es parcial, de modo que macros muy
avanzadas pueden dejar el último conteo marcado con `~`.

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

Esta plantilla es código local de este repositorio, no un paquete de Typst
Universe. `templates/typst/screenplay/main.typ` es el ejemplo de uso y
`templates/typst/screenplay/screenplay.typ` es su API completa: `screenplay`,
`scene`, `action`, `dialogue` y `transition`. Cada `:WriteNew` copia ambos
archivos, por lo que el proyecto queda independiente de futuras modificaciones
de la plantilla maestra. El formato actual cubre US Letter, márgenes, portada,
Courier a 12 pt y numeración del cuerpo; no implementa todavía parentheticals,
diálogo dual, `MORE`/`CONT'D` automático, escenas numeradas ni validación de
personajes. Revísalo contra los requisitos concretos de la producción antes de
considerarlo un formato profesional de entrega.

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

### Sugerencias, diccionario personal y excepciones

Coloca el cursor sobre una palabra o selecciona exactamente una palabra:

| Acción | Binding | Comando |
|---|---|---|
| Mostrar correcciones (`z=` nativo) | `<Space>ws` | — |
| Añadir al diccionario personal | `<Space>wa` | `:WriteSpellAdd [palabra]` |
| Retirar del diccionario personal | `<Space>wA` | `:WriteSpellRemove [palabra]` |
| Ignorar sólo en este archivo | `<Space>wi` | `:WriteSpellIgnore [palabra]` |
| Volver a comprobar en este archivo | `<Space>wI` | `:WriteSpellUnignore [palabra]` |

Los bindings funcionan en modo normal y visual. Con `both`, añadir o retirar
abre un selector ES/EN para evitar que una palabra termine en la primera lista
por accidente. Las listas `wordlists/es.utf-8.add` y
`wordlists/en.utf-8.add` viven en este repositorio, son portables y también se
sincronizan con el diccionario de LTeX+. Los comandos nativos `zg`/`zug` siguen
disponibles, pero escriben en la primera entrada de `spellfile` salvo que se les
dé un count; por eso se recomiendan los bindings `Write` cuando hay dos idiomas.

`<Space>wi` no añade la palabra a ningún diccionario. Crea, sólo cuando se usa,
`.nvim-writing-spell.json` en la raíz lógica del documento y guarda la excepción
bajo la ruta relativa del archivo. La configuración desactiva spell únicamente
en esas ocurrencias y filtra el diagnóstico ortográfico exacto de LTeX+ para ese
buffer. Puedes versionar el sidecar junto con el proyecto si quieres compartir
las decisiones editoriales; para un archivo suelto queda junto a ese archivo.
Un sidecar inválido, demasiado grande, symlink o directorio se rechaza sin
sobrescribirlo.

Las palabras marcadas usan un undercurl rojo más visible: `#E17373` en oscuro y
`#D05858` en claro. Las reglas ortográficas española e inglesa de LTeX+ se
clasifican como error para que no superpongan un subrayado gris al rojo nativo;
las demás reglas siguen como información neutral. Neovim solicita el estilo
undercurl, pero la forma y grosor final dependen del emulador de terminal; un
terminal sin soporte puede mostrar una línea recta.

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

## Google y diccionarios

Coloca el cursor sobre una palabra o selecciona una frase y usa:

| Acción | Binding | Comando |
|---|---|---|
| Buscar en Google | `<Space>wg` | `:WriteGoogle [consulta]` |
| Consultar definición | `<Space>wd` | `:WriteDictionary [es\|en] [consulta]` |

En español se abre el Diccionario de la lengua española de la RAE; en inglés,
Merriam-Webster. El idioma se infiere de `spelllang`. Si el documento usa ambos,
está en `off` o no se reconoce, aparece un selector ES/EN. El texto se codifica
como un componente URL y se abre mediante el navegador predeterminado, sin pasar
por un shell ni cambiar el portapapeles.

Estas acciones sí envían la palabra o selección al proveedor externo elegido.
No las uses sobre texto sensible que no quieras compartir con Google, RAE o
Merriam-Webster.

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
ventanas y muestra el buffer activo como `parent/file.ext`. No muestra número ni
branding; conserva `×` como botón de cierre cuando hay más de una tabpage.

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
| `<Space>wt` | Alternar tema claro/oscuro |
| `<Space>wg` | Buscar palabra/selección en Google |
| `<Space>wd` | Consultar palabra/selección en diccionario |
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

Deben mostrar `nvim-writing` y el path de configuración efectivo:
`$XDG_CONFIG_HOME/nvim-writing` si definiste esa variable, o
`$HOME/.config/nvim-writing` en caso contrario. Para problemas de actualización
o rollback, sigue `docs/UPDATING.md`.

Desde el repositorio puedes repetir la prueba automatizada con:

```sh
nvwrite --headless "+luafile tests/smoke.lua" +qa
```
