# CLAUDE.md, challenge

Eres el agente de código de este repo. Tu trabajo es tomar un desafío técnico cualquiera
(hoy, el de Chipax para el cargo de Senior Product Engineer) y llevarlo de punta a punta
hasta producción en `https://challenge.woku.uk`, con proceso visible y verificable.

**Responsable**: Paula. Toda partida de plan, elección de UI y salida a prod la aprueba la
persona responsable. Si cambia quien opera el repo, se cambia solo esta línea.

Hablamos en español neutro latinoamericano (sin voseo ni modismos regionales). Código,
comentarios, nombres de rama y commits van en inglés. Documentos del vault en español,
sin em dashes (usar comas o puntos).

## Mapa del repo

| Carpeta | Qué es | Reglas |
|---|---|---|
| `vault/` | Definición del proyecto: enunciado, diagnóstico, plan, bitácora, decisiones, evidencia | `vault/CLAUDE.md` |
| `core/` | Backend: TypeScript + Express sobre AWS Lambda, PostgreSQL (RDS), S3, agentes LangGraph + Claude, trazas y prompts en LangSmith. Incluye la infraestructura (`core/infra/`, AWS CDK) | `core/CLAUDE.md` |
| `console/` | Frontend: Vite + React + React Router (data mode) + Tailwind + Base UI + Zustand + Zod + TanStack Query. Un componente por carpeta (`Button/{Button.tsx, Button.test.tsx, index.ts}`). Se sirve desde S3 + CloudFront | `console/CLAUDE.md` |
| `.claude/` | Skills del flujo (`/arrancar`, `/bootstrap`, `/opciones-ui`, `/verificar`, `/desplegar`), el agente `revisor-adversarial` y los permisos (`PERMISOS.md`) | Leer el skill antes de ejecutarlo |
| `docker-compose.yml`, `docker/` | Stack local: Postgres 18 (`challenge` y `challenge_test`) y MinIO | |
| `README.md` | Entrega para quien evalúa. Se completa en la fase final | |

Cada carpeta tiene su propio `CLAUDE.md`. Leerlo antes de trabajar en ella.

## El flujo, en orden

Con pocas instrucciones el repo va del enunciado a prod. Cada paso deja algo revisable.

| # | Paso | Cómo | Salida revisable |
|---|---|---|---|
| 1 | Enunciado | La responsable pega el desafío en `vault/ENUNCIADO.md` | El texto original, sin editar |
| 2 | Diagnóstico | `/arrancar` | `vault/DIAGNOSTICO.md`: qué pide, qué evalúan, escenarios observables, riesgos, preguntas abiertas |
| 3 | Plan | `/arrancar` (misma pasada) | `vault/PLAN.md` en fases verticales, con `estado: nueva-propuesta` |
| 4 | Partida | La responsable dice "parte" | `estado: en-curso`, anotado en `BITACORA.md` con sus palabras |
| 5 | Bootstrap | `/bootstrap` (solo la primera vez) | `core` y `console` compilan, testean y despliegan un "hola mundo" a `challenge.woku.uk` |
| 6 | UI | `/opciones-ui` antes de cualquier pantalla | Un artefacto con 3 opciones. **No se programa front hasta que la responsable elija** |
| 7 | Implementación | TDD por fase | Un commit por fase, plan y bitácora al día antes del commit |
| 8 | Verificación | `/verificar` | `vault/evidencia/pruebas.md` y `ux-review.md` con capturas del MCP de Chrome y enlaces a trazas de LangSmith |
| 9 | Prod | PR y merge a `main`, luego `/desplegar` | Escenarios comprobados en `challenge.woku.uk`; `README.md` de entrega listo para el evaluador |

El primer deploy (paso 5) va temprano a propósito: el camino a prod se resuelve el día uno,
no al final.

## Reglas duras

1. **TDD obligatorio.** Primero el test que especifica o reproduce, verlo fallar, después el
   código mínimo, después refactor. Sin test no hay código de producción. Esto aplica a
   bugs: el bug se reproduce con un test antes de arreglarlo.
2. **No se implementa un plan en `nueva-propuesta`.** Una respuesta a una decisión abierta no
   es una partida.
3. **Nada de front sin las 3 opciones aprobadas** (`/opciones-ui`). Todo trabajo de interfaz
   usa el skill `impeccable` (diseño, auditoría, pulido).
4. **Implementado no es terminado.** Algo está hecho cuando se probó de punta a punta: stack
   local con el MCP de Chrome (UI) y LangSmith (agentes), con evidencia en el vault. La suite
   en verde solo prueba que no se rompió nada.
5. **Gates antes de cada commit**: lint, typecheck y tests del paquete tocado, todo en verde.
6. **Document as you go**: `PLAN.md` y `BITACORA.md` se actualizan antes del commit, no después.
7. **Sin secretos en el repo.** Los `.env` están en `.gitignore`; solo se versionan los
   `.env.example`. En prod los secretos viven en SSM Parameter Store.
8. **Agentes con traza completa.** Desde que el agente recibe el input hasta que entrega el
   output, todo cuelga de una sola traza en LangSmith (ver `core/docs/agentes.md`). Los
   prompts viven en el repo y se publican al Hub de LangSmith con script.
9. **Regla sagrada de Git**: antes de abrir un PR se corren localmente lint, typecheck y tests
   de los paquetes tocados (los mismos comandos que la CI, después de `npm ci`) y todo debe
   pasar. Si algo falla, se arregla antes del PR. Detalle en "Git".

## AWS

El desafío vive en una **cuenta AWS propia, `chipax-challenge`, dentro de la organización de
woku**, aislada de woku prod (ADR-009). Paula entra con su usuario IAM de siempre asumiendo el
rol `ChipaxChallengeAdmin` (perfil `chipax-challenge`, `us-east-1`, fijado en
`.claude/settings.json`); no tiene llaves nuevas ni login aparte, y la CLI renueva la sesión
sola. Así **el agente opera AWS por su cuenta**: no se le pide a la responsable que haga nada
en la consola web ni que corra comandos.

- Al empezar cualquier trabajo con AWS: `aws sts get-caller-identity` para confirmar cuenta y
  perfil. Si la cuenta no es la de `core/infra/.env` (`AWS_ACCOUNT_ID`), parar y avisar.
- **Infraestructura por CDK** (`core/infra/`), en una rama y un PR como cualquier código: es
  revisable, reproducible y se desmonta con un comando. No se crean recursos permanentes a
  mano con la CLI ni en la consola.
- **Operación por CLI**: secretos en SSM, logs (`aws logs tail`), estado de RDS, CloudFront,
  ACM, invalidaciones, diagnósticos, smoke tests. Todo lo que se hace queda anotado en la
  bitácora (recurso, id o ARN, sin secretos).
- Secretos: el agente los genera (`openssl rand -hex 32`) o los toma de `core/.env` y los sube
  con `aws ssm put-parameter --type SecureString`. Nunca se imprimen en la salida ni se
  escriben en el vault.
- Costo acotado: alerta de presupuesto mensual (AWS Budgets, en CDK) al correo de Paula y
  concurrencia reservada en la Lambda.
- Lo destructivo (borrar stacks, la base o buckets) está bloqueado en los permisos y lo hace
  Paula a mano al cerrar el proceso.

## Cloudflare (DNS)

`challenge.woku.uk` se publica creando registros en la zona `woku.uk` de Cloudflare con su
API. **La llave está en `core/infra/.env` (`CLOUDFLARE_API_TOKEN`)**, con respaldo en SSM
(`/chipax-challenge/prod/CLOUDFLARE_API_TOKEN`). El agente la verifica, crea el CNAME de
validación del certificado y el CNAME `challenge` hacia CloudFront (solo DNS, sin proxy), y
comprueba con `dig` y `curl` que el dominio responde. Detalle en `core/docs/infra.md`,
"Cloudflare". Si el token falta o no está `active`, es lo único que se le pide a la
responsable.

## Git

El repo vive en GitHub, en la cuenta de Paula (remoto `origin`). `main` es producción: lo que
está en `main` es lo que corre en `challenge.woku.uk`.

- **Toda rama de trabajo nace de `main` y vuelve a `main` por PR.** No hay `develop`:

  ```
  main -> feature/<fase-o-tema>   trabajo nuevo, una por fase del plan   (feature/f1-invoice-upload)
  main -> hotfix/<tema>           arreglo urgente de algo que ya está en prod
  main -> fix/<tema>              corrección que no es urgente
  main -> chore/<tema>            configuración, dependencias, CI, infraestructura
  main -> docs/<tema>             solo vault o README
  ```

  Nombres en inglés, kebab-case. Antes de crear la rama: `git checkout main && git pull`.
- **Nunca push directo a `main` ni merge local a `main`.** Todo cambio va rama -> push -> PR ->
  checks verdes -> merge a `main` con merge commit (sin squash: se conserva la historia
  granular). Después del merge: borrar la rama remota y local, volver a `main` y `git pull`.
- **Commits granulares**: una responsabilidad por commit, mensaje en inglés con gitmoji.
  En TDD el ritmo natural es `:white_check_mark:` test en rojo, `:sparkles:` o `:bug:` el
  código que lo pone en verde, `:recycle:` el refactor. Plan y bitácora se actualizan en el
  mismo commit que cierra el paso (`:memo:` si es solo documentación).

  | Gitmoji | Uso |
  |---|---|
  | `:sparkles:` | Funcionalidad nueva |
  | `:bug:` | Corrección |
  | `:white_check_mark:` | Tests |
  | `:recycle:` | Refactor sin cambio de comportamiento |
  | `:lipstick:` | UI y estilos |
  | `:memo:` | Documentación y vault |
  | `:wrench:` | Configuración |
  | `:construction_worker:` | CI |
  | `:rocket:` | Deploy e infraestructura |
  | `:card_file_box:` | Migraciones de base de datos |
  | `:lock:` | Seguridad |
  | `:boom:` | Cambio incompatible |

- **PR por fase**: título en inglés con la fase (`F1: invoice upload`), descripción con
  escenario, cómo se probó y enlaces a la evidencia del vault. Se abre con `gh pr create`
  solo después de la regla sagrada.
- **El agente hace push, PR y merge por su cuenta** dentro de un plan `en-curso`, sin
  preguntar, siempre que se cumplan la regla sagrada y la verificación de la fase
  (`/verificar`). Se hace push de la rama al cerrar cada paso para no perder trabajo. El merge
  a `main` se hace con `gh pr merge --merge --delete-branch` cuando la CI está verde.
  Lo único que pide aprobación es lo de "Reglas duras": partida del plan y opción de UI.
- **Releases**: al mergear a `main` una fase que llega a prod, tag SemVer anotado y release
  (`gh release create vX.Y.Z --generate-notes`): `v0.1.0` el bootstrap, MINOR por fase con
  `:sparkles:`, PATCH por fixes y hotfixes.
- Permisos de Claude Code para que todo esto corra sin preguntas: `.claude/PERMISOS.md`.
- Sin secretos en commits: `.env` ignorado; si un secreto se filtra, se rota, no basta con
  borrarlo de la historia.

Estados que se pueden reportar, en este orden: **planificado**, **implementado**,
**verificado en local**, **aprobado**, **en prod verificado**. "Listo" solo se dice del último.

## Cómo trabajar

- **Piensa antes de programar.** Explicita supuestos. Si hay varias lecturas del enunciado,
  preséntalas; no elijas en silencio. Si algo no está claro, pregunta.
- **Simplicidad primero.** Es un desafío, no un producto maduro: el mínimo código que cumple
  el enunciado con calidad de producción. Nada especulativo, sin abstracciones de un solo uso.
  Pregunta de control: ¿un senior diría que esto está sobrediseñado?
- **Cambios quirúrgicos.** Cada línea cambiada se justifica por la tarea.
- **Calidad visible para quien evalúa.** Decisiones con su porqué en `vault/decisiones.md`,
  commits legibles, README de entrega claro. El evaluador lee el repo: el proceso también es
  parte de la entrega.

## Comandos (después del bootstrap)

```bash
docker compose up -d                 # Postgres 18 + MinIO (S3 local)
npm --prefix core run dev            # API en http://localhost:3000/api
npm --prefix console run dev         # Front en http://localhost:5173 (proxy /api -> 3000)
npm --prefix core run check          # lint + typecheck + tests (gate del backend)
npm --prefix console run check       # lint + typecheck + tests (gate del front)
```
