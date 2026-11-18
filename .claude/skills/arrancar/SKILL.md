---
name: arrancar
description: Convierte el desafío de vault/ENUNCIADO.md en DIAGNOSTICO.md y PLAN.md. Úsala al empezar un desafío o cuando el enunciado cambia.
---

# Arrancar un desafío

Entrada: `vault/ENUNCIADO.md` con el texto original. Si está vacío, pedirlo y parar.
Salida: `vault/DIAGNOSTICO.md` y `vault/PLAN.md` llenos, plan en `estado: nueva-propuesta`.
**No se escribe código en este skill.**

## Pasos

1. Leer `CLAUDE.md`, `vault/CLAUDE.md`, `vault/decisiones.md` y `vault/arquitectura.md` para
   partir de la base común (stack, deploy, reglas).
2. Leer el enunciado completo, incluidos adjuntos y enlaces. Si hay datos de ejemplo
   (CSV, PDF, Excel), abrirlos y describirlos.
3. Investigar el dominio lo justo (por ejemplo, conceptos contables o tributarios de Chile si
   el desafío es de Chipax) con fuentes citadas.
4. Llenar `DIAGNOSTICO.md` siguiendo la plantilla:
   - requisitos explícitos numerados, citando el enunciado;
   - qué se evalúa (explícito e implícito para un Senior Product Engineer);
   - escenarios observables E1..En, cada uno comprobable en prod;
   - si la IA aporta o no, con argumento (no forzar un agente);
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
7. Entrada en `BITACORA.md`.
8. Rama `docs/diagnostico-plan` desde `main`, commit `:memo: Add challenge diagnosis and plan`,
   push, PR y merge a `main` (si el repo ya tiene remoto; si no, solo commit local y lo sube
   `/bootstrap`).
9. Responder a la responsable con: resumen de 5 líneas, escenarios, fases, preguntas y
   decisiones abiertas. Terminar pidiendo respuestas y la partida ("parte").

## Criterio de calidad

- Un escenario que no se puede comprobar en prod no es escenario: reescribirlo.
- Una fase que solo deja una capa (solo backend, solo modelos) no es vertical: reagrupar.
- El plan tiene que caber en el plazo del enunciado. Si no cabe, recortar alcance de forma
  explícita en "Fuera de alcance", no comprimir calidad.
