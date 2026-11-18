---
estado: nueva-propuesta   # nueva-propuesta | en-curso | produccion | descartado
actualizado: AAAA-MM-DD
---

# Plan

> Plantilla. `/arrancar` la llena desde `DIAGNOSTICO.md`. Fases verticales: cada fase deja un
> escenario funcionando de punta a punta (API + UI + datos + deploy), no una capa suelta.

**Estado**: planificado. (Actualizar por fase: planificado, implementado, verificado en local,
aprobado, en prod verificado.)

## Objetivo

> Una frase con lo que queda en `https://challenge.woku.uk` al terminar.

## Decisiones abiertas

> Se preguntan antes de programar. Cerradas se mueven a `decisiones.md`.

| # | Decisión | Opciones | Recomendación |
|---|---|---|---|
| D1 | | | |

## Fase 0. Bootstrap y camino a prod

Escenario: cualquiera abre `https://challenge.woku.uk` y ve la app vacía; `GET /api/health`
responde `ok` con la base conectada.

- [ ] F0.01 `/bootstrap`: core (Express + Vitest + Drizzle) y console (Vite + Vitest) compilan y testean
- [ ] F0.02 Docker compose local (Postgres + MinIO) y migración inicial
- [ ] F0.03 Secretos en SSM (`/chipax-challenge/prod/*`) y certificado ACM validado vía Cloudflare
- [ ] F0.04 CDK: RDS, bucket de archivos, Lambda + Function URL, bucket del front, CloudFront
- [ ] F0.05 DNS `challenge.woku.uk` en Cloudflare apuntando a CloudFront
- [ ] F0.06 Prompt de prueba en el Hub y una traza completa visible en LangSmith desde prod
- [ ] F0.07 Evidencia en `evidencia/pruebas.md`

## Fase 1. (nombre del escenario E1)

Escenario: E1.

- [ ] F1.01 `/opciones-ui` para las pantallas de esta fase y elección de la responsable
- [ ] F1.02 Contrato zod en `core/src/contracts/` (request y response, tests de contrato)
- [ ] F1.03 Service: test en rojo, implementación, verde
- [ ] F1.04 Repository con test de integración contra `challenge_test`
- [ ] F1.05 Controller + routes con `validate` y test HTTP (supertest)
- [ ] F1.06 UI con tests (Testing Library + MSW)
- [ ] F1.07 `/verificar`: E2E con el MCP de Chrome, desktop y móvil
- [ ] F1.08 Deploy y verificación en prod

Cómo se prueba en local:
Evidencia que queda:
Qué necesita prod (secretos, prompts, datos, migraciones):

## Fase N. Entrega

- [ ] README de entrega (qué es, URL, credenciales demo si aplica, cómo correr, decisiones, qué haría con más tiempo)
- [ ] `/verificar` completo sobre prod
- [ ] Revisión adversarial (`revisor-adversarial`) y hallazgos resueltos o anotados
- [ ] Plan en `estado: produccion`

## Bitácora del plan

> Discrepancias entre plan y realidad, con fecha. Lo general va en `BITACORA.md`.
