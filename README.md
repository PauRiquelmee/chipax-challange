# Chipax Challenge

> README de entrega para quien evalúa. Se completa en la fase final del plan; hasta entonces
> es la plantilla.

**En producción**: https://challenge.woku.uk

## Qué es

(Una frase: el problema que resuelve y para quién.)

## Cómo probarlo

1. Abrir https://challenge.woku.uk
2. (Credenciales de demo, si aplica.)
3. (Recorrido sugerido: los escenarios principales en 3 a 5 pasos.)

## Qué se construyó

| Escenario | Estado | Evidencia |
|---|---|---|
| E1 | en prod verificado | `vault/evidencia/pruebas.md#e1` |

## Arquitectura

React (Vite) servido por CloudFront; API Express en AWS Lambda detrás del mismo dominio;
PostgreSQL en RDS; archivos en S3 con URLs prefirmadas; agentes LangGraph con Claude,
trazados de punta a punta en LangSmith. Detalle en `vault/arquitectura.md` y decisiones con su
porqué en `vault/decisiones.md`.

## Cómo se trabajó

El proceso está en `vault/`: diagnóstico del desafío, plan por fases verticales, bitácora
fechada, opciones de UI evaluadas y evidencia de cada verificación. Desarrollo en TDD, una
rama y un PR por fase, CI en cada PR y deploy automático en cada merge a `main`.

## Correr en local

```bash
nvm use                        # Node 24
docker compose up -d           # Postgres + MinIO
cp core/.env.example core/.env && cp console/.env.example console/.env   # llenar llaves
npm --prefix core ci && npm --prefix core run db:migrate && npm --prefix core run dev
npm --prefix console ci && npm --prefix console run dev
# http://localhost:5173
```

Tests: `npm --prefix core run check` y `npm --prefix console run check`.

## Qué haría con más tiempo

(Lista honesta y priorizada.)
