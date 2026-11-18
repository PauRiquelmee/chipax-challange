---
name: bootstrap
description: Fase 0. Inicializa git y GitHub, core y console con su tooling y tests, docker compose, infraestructura AWS, DNS en Cloudflare, CI/CD y un primer deploy a challenge.woku.uk. Se corre una sola vez, después de la partida del plan.
---

# Bootstrap (Fase 0)

Resultado: `https://challenge.woku.uk` muestra la app vacía, `GET /api/health` responde
`{ "status": "ok", "db": "ok" }`, existe una traza completa en LangSmith desde prod, la CI
corre en cada PR y cada merge a `main` despliega.

Leer antes: `CLAUDE.md`, `core/CLAUDE.md`, `core/docs/infra.md`, `core/docs/agentes.md`,
`console/CLAUDE.md`, `.claude/PERMISOS.md` (sección 2: verificar que las sesiones estén listas
y, si falta alguna, pedirla a la responsable antes de empezar).

Versiones: siempre la última estable al momento de instalar (`npm view <pkg> version`),
fijadas en `package.json` sin `^` en dependencias críticas (langchain, langgraph,
@langchain/anthropic, langsmith, drizzle, react-router). Node 24 (`.nvmrc`).

## 1. Git y GitHub

- `git init -b main`, `.gitignore` ya existe. Primer commit en `main`:
  `:tada: Initial structure` (es el único commit directo a `main`).
- `gh repo create <GITHUB_OWNER>/<GITHUB_REPO> --private --source . --push`.
- Desde aquí, todo en ramas. Rama `chore/bootstrap`.

## 2. core (TDD desde el primer archivo)

- `npm init`, TypeScript strict, ESLint (flat config, typescript-eslint), Prettier, Vitest
  con dos proyectos (`unit` y `int`), `tsx` para dev, `esbuild` para el bundle de Lambda.
- Dependencias: `express@5`, `zod`, `pino`, `pg`, `drizzle-orm`, `drizzle-kit`,
  `@aws-sdk/client-s3`, `@aws-sdk/s3-request-presigner`, `@aws-sdk/client-ssm`,
  `@aws-sdk/client-lambda`, `serverless-http`, `langchain`, `@langchain/core`,
  `@langchain/langgraph`, `@langchain/anthropic`, `langsmith`; dev: `supertest`, tipos.
- Primer ciclo TDD, ya con las capas de `core/CLAUDE.md`: módulo `health` con
  `health.contract.ts` (esquema de respuesta), `health.service.ts` (consulta la base),
  `health.controller.ts` y `health.routes.ts`; tests del service y del controller (supertest,
  service falso) en rojo, implementación, verde. Luego `shared/http/validate.ts` y el
  middleware de errores (ZodError -> 400, AppError -> su status) con tests, `config/env.ts`
  con test de validación, `db/client.ts` con test de integración (`select 1` contra
  `challenge_test`) y el middleware de `X-Origin-Verify`. Este módulo queda como plantilla
  de los siguientes.
- Agente mínimo `ping` siguiendo `core/docs/agentes.md` (prompt registrado, traza raíz,
  flush) con test de modelo falso, y endpoint `POST /api/agents/ping` para probar la traza.
- Scripts de `package.json` tal como lista `core/CLAUDE.md` (`check` incluye `test:int`).

## 3. console

- `npm create vite@latest console -- --template react-ts` (sobre la carpeta existente, sin
  pisar `CLAUDE.md` ni los `.env`).
- Tailwind v4 (`@tailwindcss/vite`), `@base-ui/react`, `react-router`,
  `@tanstack/react-query`, `zustand`, `zod`; dev: `vitest`, `jsdom`, `@testing-library/react`, `@testing-library/user-event`,
  `@testing-library/jest-dom`, `msw`.
- Alias `@/` -> `src/` y `@contracts` -> `../core/src/contracts` en `vite.config.ts` y `tsconfig`.
- ESLint `no-restricted-imports` con un patrón regex que rechace imports que repiten el
  nombre de la carpeta (`.../Nombre/Nombre`), con un test de lint que lo demuestre.
- Proxy `/api` -> `VITE_API_PROXY_TARGET` en `server.proxy` y `preview.proxy`.
- Primer ciclo TDD: ruta `features/health/routes/HealthStatus/` (carpeta con
  `HealthStatus.tsx`, test e `index.ts`) que consulta `/api/health` vía loader y muestra el
  estado (test con MSW en rojo, implementación, verde). Sin diseño todavía: el diseño llega
  con `/opciones-ui`, y los envoltorios de Base UI (`Button`, `Input`...) se crean recién
  después de la elección, con los tokens de `DESIGN.md`.

## 4. Local

- `docker compose up -d`, `db:migrate`, `npm run dev` en ambos, abrir
  `http://localhost:5173` con el MCP de Chrome y comprobar el estado de salud.
- Llamar `POST /api/agents/ping` y revisar la traza en LangSmith (proyecto `-local`): un solo
  árbol con `pull_prompt`, el modelo y la persistencia.

## 5. Infraestructura (core/infra)

El agente hace todo con la AWS CLI y CDK (perfil de Paula fijado en `.claude/settings.json`),
sin pedir pasos manuales. Primero `aws sts get-caller-identity`: si la cuenta no coincide con
`AWS_ACCOUNT_ID` o el ARN no es `assumed-role/ChipaxChallengeAdmin/...`, parar y avisar. Si
el perfil no existe, la cuenta todavía no se creó: ver `core/docs/infra.md`, "Cuenta AWS".

- App CDK en TypeScript con los tres stacks de `core/docs/infra.md` y tests de CDK
  (`Template.fromStack` + aserciones: TLS forzado en RDS, bucket privado, encabezado de
  origen en CloudFront, concurrencia reservada).
- Scripts `cert.ts`, `secrets.ts`, `dns.ts`, `sync-console.ts` con tests de la parte pura
  (armado de registros, idempotencia).
- Cloudflare: leer `CLOUDFLARE_API_TOKEN` de `core/infra/.env` (o de SSM si el `.env` no lo
  tiene), verificar que esté `active`, resolver y guardar `CLOUDFLARE_ZONE_ID`, y al final
  respaldar el token en SSM. Registros y comprobaciones según `core/docs/infra.md`, "Cloudflare".
- Seguir "Primer deploy" de `core/docs/infra.md` paso a paso; cada recurso creado se anota en
  la bitácora (ARN o id, sin secretos).

## 6. CI/CD

- `.github/workflows/ci.yml` y `deploy.yml` como describe `core/docs/infra.md`.
- `gh variable set AWS_ROLE_ARN` y `AWS_REGION`.
- Protección de `main` con `gh api`: PR obligatorio y check `ci` requerido, sin push forzado.

## 7. Cierre de la fase

- `/verificar` sobre local y prod: health en `https://challenge.woku.uk`, traza desde prod.
- PR `F0: bootstrap and production path` con la evidencia, merge a `main` cuando la CI
  está verde, confirmar que `deploy.yml` corrió bien, tag `v0.1.0`.
- `PLAN.md`: F0 marcada, línea "Estado" al día. Entrada en la bitácora.
