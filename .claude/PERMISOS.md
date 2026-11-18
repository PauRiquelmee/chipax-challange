# Permisos y preparación de Claude Code

Objetivo: que el flujo completo (TDD, Docker, AWS, Cloudflare, GitHub, PR y merge, MCP de
Chrome y LangSmith, artefactos) corra sin que Claude Code pregunte nada, salvo las dos
aprobaciones de producto que pide `CLAUDE.md` (partida del plan y opción de UI).

## 1. Permisos

El mismo `.claude/settings.json` fija `AWS_PROFILE=chipax-challenge` y `AWS_REGION=us-east-1`
para la sesión, así que cada comando `aws` y `cdk` del agente usa la cuenta correcta sin
prefijos. Si Paula usa otro nombre de perfil, se cambia ahí y en `core/infra/.env`.

Ya están en `.claude/settings.json` de este repo, así que **al abrir Claude Code dentro del
repo aplican solos** (la primera vez Claude Code pide confiar en la carpeta: aceptar).

Si Paula prefiere tenerlos también fuera del repo, copiar el bloque `permissions` de
`.claude/settings.json` a `~/.claude/settings.json` (o a `.claude/settings.local.json` del
repo si quiere ajustes solo suyos sin versionarlos).

Qué queda permitido sin preguntar:

| Grupo | Permisos |
|---|---|
| Archivos | `Read`, `Edit`, `Write`, `Glob`, `Grep`, modo `acceptEdits` |
| Web | `WebFetch`, `WebSearch` |
| Claude Code | `Skill` (los skills del repo e `impeccable`), `Artifact`, `ArtifactComments` (las 3 opciones de UI) |
| MCP | `mcp__claude-in-chrome` (todo el navegador), `mcp__langsmith` (trazas, prompts) |
| Git y GitHub | `git *`, `gh *` (ramas, commits, push de ramas, PR, merge, releases, variables del repo, protección de rama) |
| Node | `npm`, `npx`, `node`, `nvm`, `tsx`, `vitest`, `eslint`, `tsc`, `cdk`, `drizzle-kit` |
| Datos locales | `docker`, `docker compose`, `psql`, `pg_isready` |
| Nube y DNS | `aws *` (CDK, SSM, ACM, RDS, S3, CloudFront, Lambda, logs), `curl` (API de Cloudflare, smoke tests), `jq`, `openssl rand`, `dig`, `nslookup` |
| Shell | `ls`, `cat`, `head`, `tail`, `find`, `grep`, `rg`, `sed`, `awk`, `mkdir`, `cp`, `mv`, `rm`, `chmod`, `ps`, `lsof`, `kill`, etc. |

Qué queda **bloqueado** aunque se pida (red de seguridad):

| Bloqueo | Por qué |
|---|---|
| `git push --force`, `-f`, `--force-with-lease`, push directo a `main`, `git filter-branch` | `main` solo cambia por PR; la historia no se reescribe |
| `gh repo delete`, cambiar visibilidad del repo | Irreversible o expone el código |
| `aws rds delete-db-instance`, `aws s3 rb`, `aws cloudformation delete-stack`, `cdk destroy` | Borran datos o infraestructura; al cerrar el proceso se hace a mano |
| `aws iam create-access-key`, `aws iam delete-*`, `aws organizations` | Credenciales y cuenta: fuera del alcance del agente |
| `rm -rf /`, `rm -rf ~`, `rm -rf ..` | Obvio |

No se recomienda `--dangerously-skip-permissions`: con la lista de arriba no hace falta y se
conservan los bloqueos.

## 2. Cuentas y sesiones que Paula deja listas una vez

Sin esto, los permisos no alcanzan: el comando corre pero falla por credenciales.

| Qué | Cómo | Comprobación |
|---|---|---|
| Node 24 | `nvm install 24 && nvm alias default 24` | `node -v` |
| Docker sin sudo | Docker Desktop, o en Linux `sudo usermod -aG docker $USER` y volver a entrar | `docker ps` |
| GitHub | `gh auth login` (HTTPS, scopes `repo` y `workflow`) con la cuenta de Paula; crear el repo vacío | `gh auth status` |
| AWS CLI | Ya tiene la CLI con su usuario `paula` (perfil `woku-cdn`). Diego crea la cuenta `chipax-challenge` con `core/infra/scripts/account-setup.sh`, que imprime 5 líneas para pegar en `~/.aws/config` (perfil `chipax-challenge` que asume el rol `ChipaxChallengeAdmin` con sus llaves actuales). Anotar el id de la cuenta en `core/infra/.env` (`AWS_ACCOUNT_ID`). Es lo único de AWS que hace Paula: desde ahí el agente crea y opera todo | `aws sts get-caller-identity --profile chipax-challenge` muestra `assumed-role/ChipaxChallengeAdmin` |
| Cloudflare | API Token con `Zone > DNS > Edit` y `Zone > Zone > Read` solo sobre `woku.uk` (lo crea quien administra la zona). **Va en `core/infra/.env`, variable `CLOUDFLARE_API_TOKEN`**; el id de la zona lo busca el agente. Paso a paso en `core/docs/infra.md`, "Cloudflare" | `.result.status` = `active` en `https://api.cloudflare.com/client/v4/user/tokens/verify` |
| Claude Platform | API key en `core/.env` (`ANTHROPIC_API_KEY`) | primer turno del agente |
| LangSmith | API key en `core/.env` (`LANGSMITH_API_KEY`); MCP de LangSmith conectado con `/mcp` | traza visible en el proyecto `chipax-challenge-local` |
| Chrome | Extensión Claude in Chrome instalada y conectada | `/chrome` en Claude Code |
| Skill `impeccable` | Instalado en `~/.claude/skills/impeccable` | aparece en `/skills` |

### Dónde va cada llave

| Llave | Archivo | Variable |
|---|---|---|
| Cloudflare (DNS de `challenge.woku.uk`) | `core/infra/.env` | `CLOUDFLARE_API_TOKEN` |
| Id de la cuenta AWS, correo de alertas, repo de GitHub | `core/infra/.env` | `AWS_ACCOUNT_ID`, `ALERT_EMAIL`, `GITHUB_OWNER`, `GITHUB_REPO` |
| Claude Platform | `core/.env` | `ANTHROPIC_API_KEY` |
| LangSmith | `core/.env` | `LANGSMITH_API_KEY` |

Los `.env` no se versionan. En el bootstrap el agente copia todas a SSM
(`/chipax-challenge/prod/`), desde donde las leen la Lambda, el deploy de GitHub Actions y
cualquier sesión futura.

## 3. Primera sesión

```text
1. Abrir Claude Code en la carpeta del repo y aceptar la confianza de la carpeta.
2. Pegar el desafío en vault/ENUNCIADO.md.
3. Escribir: /arrancar
4. Revisar DIAGNOSTICO.md y PLAN.md, responder las decisiones abiertas y decir "parte".
```

Desde ahí el agente hace bootstrap, ramas, commits, PR, merge y deploy solo, y se detiene
únicamente para mostrar las 3 opciones de cada pantalla.
