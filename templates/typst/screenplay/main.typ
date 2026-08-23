// vim: set spell spelllang=es:
// nvim-writing: managed-ltex
// LTeX: language=es-ES

#import "screenplay.typ": screenplay, scene, action, dialogue, transition

#show: screenplay.with(
  title: "TÍTULO DEL GUION",
  author: "Nombre del autor",
  contact: "correo@example.com",
)

#scene("INT. HABITACIÓN - NOCHE")

#action[Una habitación apenas iluminada. ANA observa una carta sobre la mesa.]

#dialogue("ANA")[
  No pensé que fueras a responder.
]

#transition("CORTE A:")

#scene("EXT. CALLE - AMANECER")

#action[La ciudad empieza a despertar.]
