# Infraestructura y deploy

Todo en `us-east-1` (CloudFront exige el certificado ahí y simplifica tener una sola región).
Nombre base de recursos: `chipax-challenge` (`APP_NAME`). Decisiones en `vault/decisiones.md`
(ADR-002 a ADR-005).

## Cuenta AWS

Cuenta propia `chipax-challenge` dentro de la organización de woku (ADR-009). Se crea una vez
con `core/infra/scripts/account-setup.sh <correo-raíz-único>`, que corre Diego desde la cuenta
administradora de la organización. El script:

1. Comprueba que el perfil usado sea la cuenta administradora de la organización (si no, aborta sin crear nada).
2. Crea la cuenta miembro `chipax-challenge` (o la reutiliza si ya existe).
3. Entra con `OrganizationAccountAccessRole` y crea el rol `ChipaxChallengeAdmin`
   (`AdministratorAccess`, sesiones de hasta 12 h) que confía en los usuarios `paula` y `diego`
   de la cuenta de woku.
4. En la cuenta de woku agrega al usuario `paula` una sola política: `sts:AssumeRole` sobre ese
   rol. No cambia nada más en woku prod.
5. Imprime el perfil para `~/.aws/config` de Paula:

```ini
[profile chipax-challenge]
source_profile = woku-cdn
role_arn = arn:aws:iam::<ID>:role/ChipaxChallengeAdmin
role_session_name = paula-chipax-challenge
duration_seconds = 43200
region = us-east-1
```

La CLI asume el rol con las llaves de siempre de Paula y renueva la sesión sola; no hay login
nuevo. En CloudTrail cada acción queda como `paula-chipax-challenge`.

## Qué se crea

`core/infra/` es una app de AWS CDK en TypeScript con tres stacks. El agente corre todo con
la AWS CLI y CDK usando el perfil de Paula (`AWS_PROFILE`, fijado en `.claude/settings.json`);
Paula no entra a la consola web.

| Stack | Recursos |
|---|---|
| `ChipaxChallengeBase` | Presupuesto mensual de AWS Budgets (`BUDGET_MONTHLY_USD`) con avisos al 50 %, 80 % y 100 % a `ALERT_EMAIL` |
| `ChipaxChallengeData` | RDS PostgreSQL 18 `db.t4g.micro` (TLS forzado, backups 7 días, cifrado), secreto del usuario maestro y del usuario de app en Secrets Manager, bucket S3 privado de uploads (CORS para `PUT` desde `https://challenge.woku.uk` y `http://localhost:5173`, ciclo de vida para `uploads/tmp/`) |
| `ChipaxChallengeApp` | Lambda `api` (Node 24, arm64, 1024 MB, timeout 60 s, concurrencia reservada 10) con Function URL, rol con lectura de `SSM_PREFIX` y acceso al bucket; bucket del front; CloudFront con OAC al bucket, origen Function URL para `/api/*` con encabezado `X-Origin-Verify`, CloudFront Function para rutas del SPA, certificado de `CERT_ARN`, alias `challenge.woku.uk`; rol OIDC para GitHub Actions del repo de Paula |

Fuera de CDK, con scripts idempotentes en `core/infra/scripts/`:

| Script | Qué hace |
|---|---|
| `cert.ts` | Pide el certificado ACM de `challenge.woku.uk` en `us-east-1`, crea el CNAME de validación en Cloudflare, espera `ISSUED` y guarda el ARN en SSM (`$SSM_PREFIX/cert-arn`) |
| `dns.ts` | Crea o actualiza el CNAME `challenge` -> dominio de CloudFront en Cloudflare (DNS only) |
| `secrets.ts` | Sube a SSM (SecureString) las llaves de Claude y LangSmith tomadas de `core/.env`, genera los secretos propios (`ORIGIN_VERIFY_SECRET`, `AUTH_JWT_SECRET`) si no existen y arma `DATABASE_URL` desde Secrets Manager. Idempotente, no imprime valores |

## Cloudflare

La zona `woku.uk` está en Cloudflare; el agente crea los registros con la API, sin que nadie
entre al panel.

**Dónde va la llave**: `core/infra/.env`, variable `CLOUDFLARE_API_TOKEN` (archivo no
versionado, permisos 600). Es lo único que hace falta: `scripts/dns.ts` busca el id de la
zona con el token (`GET /zones?name=woku.uk`) y lo deja en `CLOUDFLARE_ZONE_ID`. Al terminar
el bootstrap, el agente también guarda el token en SSM (`$SSM_PREFIX/CLOUDFLARE_API_TOKEN`)
como respaldo, para que una sesión nueva o un clon limpio del repo lo recupere con
`aws ssm get-parameter --with-decryption` sin pedírselo a nadie.

**Cómo se crea el token** (quien administra `woku.uk` en Cloudflare, una vez):

1. Cloudflare > Mi perfil > API Tokens > Create Token > plantilla "Edit zone DNS".
2. Permisos: `Zone > DNS > Edit` y `Zone > Zone > Read`.
3. Recursos: `Include > Specific zone > woku.uk`.
4. Opcional: expiración al final del proceso de evaluación.
5. Copiar el token en `core/infra/.env`. No pegarlo en el chat.

El agente lo verifica antes de usarlo:

```bash
curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  https://api.cloudflare.com/client/v4/user/tokens/verify | jq '.result.status'   # "active"
```

**Registros que crea** (todos `proxied: false`, TTL automático; idempotente: si existe, lo actualiza):

| Cuándo | Tipo | Nombre | Valor | Script |
|---|---|---|---|---|
| Antes del deploy | CNAME | `_<hash>.challenge.woku.uk` | `_<hash>.acm-validations.aws` (lo da ACM) | `cert.ts` |
| Después de `ChipaxChallengeApp` | CNAME | `challenge.woku.uk` | `dxxxx.cloudfront.net` (output del stack) | `dns.ts` |

Van en modo solo DNS (nube gris) porque CloudFront ya es la CDN y termina TLS con el
certificado de ACM; con el proxy naranja habría dos CDN encadenadas y la validación de ACM
fallaría. Comprobación: `dig +short challenge.woku.uk` devuelve el dominio de CloudFront y
`curl -sI https://challenge.woku.uk` responde 200 con `via: ... cloudfront`.

## Secretos en SSM (`/chipax-challenge/prod/`)

| Parámetro | Origen |
|---|---|
| `ANTHROPIC_API_KEY` | Claude Platform |
| `LANGSMITH_API_KEY` | LangSmith |
| `DATABASE_URL` | Armado desde el secreto del usuario de app de RDS (`sslmode=require`) |
| `ORIGIN_VERIFY_SECRET` | Generado (`openssl rand -hex 32`) |
| `AUTH_JWT_SECRET` | Generado, si el desafío tiene login |
| `CLOUDFLARE_API_TOKEN` | Respaldo del de `core/infra/.env` (no lo lee la Lambda) |
| `cert-arn` | Lo escribe `cert.ts` |

Los no secretos (`APP_ENV`, `LLM_MODEL`, `LANGSMITH_PROJECT`, `S3_BUCKET_UPLOADS`, etc.) van
como variables de entorno de la Lambda desde CDK.

## Primer deploy (bootstrap, una vez, desde local)

Lo corre el agente de principio a fin. Requisitos (sección 2 de `.claude/PERMISOS.md`): perfil
de AWS CLI de Paula, `gh` autenticado con su cuenta, token de Cloudflare en `core/infra/.env`.

```bash
aws sts get-caller-identity               # cuenta = AWS_ACCOUNT_ID de core/infra/.env
cd core/infra
npx cdk bootstrap                         # una vez por cuenta y región
npx cdk deploy ChipaxChallengeBase        # alerta de presupuesto (confirmar el correo de suscripción)
npx tsx scripts/cert.ts                   # certificado validado vía Cloudflare
npx tsx scripts/secrets.ts                # secretos a SSM
npx cdk deploy ChipaxChallengeData        # RDS + bucket de uploads
npm --prefix .. run db:migrate:prod       # migraciones contra RDS (usuario de migraciones)
npm --prefix .. run build && npx cdk deploy ChipaxChallengeApp
npm --prefix ../../console run build && npx tsx scripts/sync-console.ts   # s3 sync + invalidación
npx tsx scripts/dns.ts                    # challenge.woku.uk -> CloudFront
curl -s https://challenge.woku.uk/api/health
```

## Deploy continuo (después del bootstrap)

Con GitHub Actions y el rol OIDC (sin llaves de AWS guardadas en GitHub):

- `.github/workflows/ci.yml`: en cada PR a `main`, `npm ci` + `check` de core (con servicio
  Postgres) y de console. Es el check requerido para mergear.
- `.github/workflows/deploy.yml`: en cada push a `main` (merge de PR): migraciones,
  `prompts:push`, build y `cdk deploy ChipaxChallengeApp`, build del front, sync a S3 e
  invalidación de CloudFront, y un smoke test a `/api/health`.

Variables del repo en GitHub (no secretas): `AWS_ROLE_ARN`, `AWS_REGION`. Los secretos de
runtime se leen de SSM dentro del workflow cuando hacen falta (por ejemplo, la llave de
LangSmith para `prompts:push`).

## Rollback

- App: revertir el merge en `main` con un PR (`git revert -m 1 <merge>`) y dejar que corra el
  deploy. Para urgencias, `cdk deploy` local desde el tag anterior.
- Base: migraciones solo hacia adelante y compatibles con la versión anterior del código
  (expandir, migrar, contraer). Snapshot manual de RDS antes de una migración riesgosa.

## Costo esperado (orden de magnitud)

RDS `db.t4g.micro` ~USD 12 al mes (o capa gratuita si aplica), Lambda, S3 y CloudFront casi
cero con tráfico de evaluación, más el uso de Claude. Al terminar el proceso de evaluación
Paula corre a mano `cdk destroy` de los stacks (está bloqueado para el agente) y el agente
borra el CNAME y lo anota en la bitácora.
