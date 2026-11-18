---
name: arrancar
description: Convierte el desafío de vault/ENUNCIADO.md en DIAGNOSTICO.md y PLAN.md. Úsala al empezar un desafío o cuando el enunciado cambia.
---

# Arrancar un desafío

Entrada: `vault/ENUNCIADO.md` con el texto original. Si está vacío, pedirlo y parar.
Salida: `vault/DIAGNOSTICO.md` y `vault/PLAN.md` llenos (plan en `estado: nueva-propuesta`) y
**un artefacto de revisión** publicado con la herramienta `Artifact`: diagnóstico, plan,
diagrama de la solución y, si el desafío tiene frontend, 2 opciones de UI. La responsable
revisa todo junto antes de la partida.
**No se escribe código de la aplicación en este skill.**

## Pasos

1. Leer `CLAUDE.md`, `vault/CLAUDE.md`, `vault/decisiones.md` y `vault/arquitectura.md` para
   partir de la base común (stack, deploy, reglas).
2. Leer el enunciado completo, incluidos adjuntos y enlaces. Si hay datos de ejemplo
   (CSV, PDF, Excel), abrirlos y describirlos.
3. Investigar el dominio lo justo (por ejemplo, conceptos contables o tributarios de Chile si
   el desafío es de Chipax) con fuentes citadas.
   **Búsqueda web acotada de mejores prácticas** (`WebSearch`, modo `standard`; `extended` solo
   si sale pobre): 3 a 5 búsquedas sobre cómo se resuelve este tipo de problema (enfoques
   comunes, errores típicos, alternativas, librerías o patrones recomendados, y si hay IA,
   cómo se evalúa). Quedarse con lo que cambia una decisión. Cada hallazgo entra al
   diagnóstico con su enlace y su efecto: "adoptamos X", "descartamos Y porque Z". No
   incluir datos del usuario ni del proyecto en las consultas.
4. Llenar `DIAGNOSTICO.md` siguiendo la plantilla:
   - requisitos explícitos numerados, citando el enunciado;
   - qué se evalúa (explícito e implícito para un Senior Product Engineer);
   - escenarios observables E1..En, cada uno comprobable en prod;
   - si la IA aporta o no, con argumento (no forzar un agente);
   - sección "Mejores prácticas y alternativas" con los hallazgos de la búsqueda web: fuente,
     qué dice, qué decisión mueve y qué se adopta o descarta;
   - riesgos, fuera de alcance y preguntas P1..Pn.
5. Llenar `PLAN.md`:
   - Fase 0 de bootstrap y camino a prod tal como viene en la plantilla;
   - una fase vertical por escenario o grupo chico de escenarios, ordenadas por valor y riesgo
     (lo más riesgoso primero);
   - en cada fase: el paso de `/opciones-ui` si toca front, los pasos de TDD, verificación y
     deploy; cómo se prueba en local, qué evidencia queda y qué necesita prod;
   - decisiones abiertas D1..Dn con recomendación;
   - fase final de entrega.
6. Si el desafío obliga a cambiar algo de la base (otra base de datos, otro stack, sin IA),
   proponerlo como decisión abierta y, si se aprueba, agregar un ADR desde ADR-100.
7. **Artefacto de revisión.** Es el Artifact nativo de Claude (herramienta `Artifact`, página
   HTML privada en claude.ai), no un documento ni un archivo local. Empezar con
   `Artifact` `action: "quickstart"` e `intent: "other"`. Cargar `artifact-design` (y `artifact-diagramming` para el
   diagrama; si el desafío tiene frontend, también `impeccable`). Un solo HTML publicado con
   `Artifact`, con pestañas:
   - **Diagnóstico**: resumen de `DIAGNOSTICO.md` (qué pide, evaluación, escenarios,
     mejores prácticas con enlaces, riesgos, preguntas).
   - **Plan**: fases, escenarios por fase, decisiones abiertas con recomendación.
   - **Solución**: diagrama que muestra el mecanismo real (componentes, flujo de datos,
     dónde actúa el agente y dónde se trazan las llamadas en LangSmith), legible en claro y
     oscuro. Debe coincidir con `vault/arquitectura.md`.
   - **UI** (solo si hay frontend): **2 opciones** realmente distintas de la pantalla o flujo
     principal, con contenido real del desafío, estados clave (vacío, cargando, error, con
     datos) y vistas desktop (1440 px) y móvil (390 px). Para cada una: idea central, para
     quién funciona, qué sacrifica, costo; y la recomendación propia. Sin código de `console/`.
   Revisarlo con el MCP de Chrome en ambos anchos (una pasada). Registrar la ronda en
   `vault/ui/opciones.md` con "Elegida" vacía; es la ronda 1 y la elección cuenta como la
   aprobación de UI exigida por las reglas duras. Las pantallas siguientes usan `/opciones-ui`.
8. Entrada en `BITACORA.md` (incluye el enlace al artefacto).
9. Rama `docs/diagnostico-plan` desde `main`, commit `:memo: Add challenge diagnosis and plan`,
   push, PR y merge a `main` (si el repo ya tiene remoto; si no, solo commit local y lo sube
   `/bootstrap`).
10. Responder a la responsable con: **enlace al artefacto**, resumen de 5 líneas, escenarios,
   fases, preguntas, decisiones abiertas y, si hay UI, la opción recomendada. Terminar pidiendo
   respuestas, la opción de UI y la partida ("parte"). No implementar nada antes.

## Criterio de calidad

- El diagnóstico cita al menos 3 fuentes web con enlace y dice qué decisión mueve cada una.
- El diagrama explica cómo funciona la solución, no solo qué cajas tiene.
- Un escenario que no se puede comprobar en prod no es escenario: reescribirlo.
- Una fase que solo deja una capa (solo backend, solo modelos) no es vertical: reagrupar.
- El plan tiene que caber en el plazo del enunciado. Si no cabe, recortar alcance de forma
  explícita en "Fuera de alcance", no comprimir calidad.
