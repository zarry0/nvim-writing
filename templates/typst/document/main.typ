// vim: set spell spelllang=es:
// nvim-writing: managed-ltex
// LTeX: language=es-ES

#import "template.typ": document

#show: document.with(
  title: "Título del documento",
  author: "Nombre del autor",
  date: "Fecha",
  language: "es",
)

= Introducción

Empieza a escribir aquí. La apariencia general se controla desde
`template.typ`, mientras este archivo conserva el contenido.

= Desarrollo

Puedes citar una fuente con @ejemplo_libro_2024.

= Referencias

#bibliography("references.bib", style: "apa")
