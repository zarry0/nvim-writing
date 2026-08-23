// vim: set spell spelllang=es:
// nvim-writing: managed-ltex
// LTeX: language=es-ES

#import "template.typ": essay

#show: essay.with(
  title: "Título del ensayo",
  author: "Nombre del autor",
  course: none,
  date: "Fecha",
  language: "es",
)

= Introducción

Presenta aquí la tesis y el contexto del ensayo.

= Argumento

Desarrolla el argumento y usa citas como @ejemplo_ensayo_2024.

= Conclusión

Resume el argumento sin repetirlo literalmente.

#bibliography("references.bib", style: "apa")
