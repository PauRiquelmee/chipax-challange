# CLAUDE.md, vault/

El vault define el proyecto y deja el rastro del proceso. Es documentación, no código: el
código vive en `core/` y `console/`, y desde aquí se referencia (archivo, commit), nunca se copia.

## Contenido

| Archivo | Qué es | Quién lo escribe |
|---|---|---|
| `ENUNCIADO.md` | El desafío tal como llegó. No se edita: si hay aclaraciones, van abajo en "Aclaraciones" con fecha y fuente | La responsable |
| `DIAGNOSTICO.md` | Qué pide el desafío, qué evalúan, escenarios observables, restricciones, riesgos y preguntas. Se escribe antes de proponer nada | Claude, con `/arrancar` |
| `PLAN.md` | Frontmatter de estado y checklist por fases verticales. Fuente de verdad del avance. Se marca durante la implementación | Claude |
| `BITACORA.md` | Registro fechado de lo que pasó: partidas, decisiones, discrepancias, bloqueos, aprendizajes. Lo más nuevo arriba | Claude |
| `decisiones.md` | Decisiones de arquitectura (ADR cortos): contexto, decisión, alternativas, consecuencias | Claude, aprobadas por la responsable |
| `arquitectura.md` | Cómo se ve el sistema en prod y cómo viaja un request | Claude |
| `ui/opciones.md` | Registro de cada ronda de `/opciones-ui`: enlace al artefacto, opciones, elección y motivo | Claude |
| `evidencia/pruebas.md` | Escenario por escenario: cómo se probó, resultado, enlace a traza de LangSmith o captura | Claude, con `/verificar` |
| `evidencia/ux-review.md` | Revisión de UX/UI con el MCP de Chrome (desktop y móvil) y hallazgos de `impeccable` | Claude, con `/verificar` |
| `evidencia/capturas/` | Capturas referenciadas desde los dos anteriores | Claude |

## Estado de un plan

`PLAN.md` empieza con este frontmatter:

```yaml
---
estado: nueva-propuesta   # nueva-propuesta | en-curso | produccion | descartado
actualizado: AAAA-MM-DD
---
```

- `nueva-propuesta`: plan escrito, esperando la partida. Puede tener decisiones abiertas.
- `en-curso`: la responsable dio la partida ("parte", "implementa"). Se anota en la bitácora
  con fecha y sus palabras.
- `produccion`: lo que el plan prometió funciona en `challenge.woku.uk` y se verificó allí.
- `descartado`: se abandonó; el motivo va en la bitácora.

La línea "Estado" del plan dice la verdad por fase: planificado, implementado, verificado en
local, aprobado, en prod verificado.

## Reglas

- Si el desafío cambia de alcance de forma grande (otra iteración), se archiva la versión
  vigente en `vault/archivo/vN/` y se empieza un diagnóstico nuevo. En un desafío normal no
  hace falta.
- Evidencia con referencias concretas: `core/src/...:línea`, hash de commit, URL de traza.
- Sin secretos ni credenciales, tampoco en capturas.
- Español neutro, sin em dashes.
