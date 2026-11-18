# Bitácora

Registro fechado del proyecto. Lo más nuevo arriba. Una entrada por hecho relevante:
partida, decisión, discrepancia con el plan, bloqueo, aprendizaje, deploy.

Formato:

```
## AAAA-MM-DD, título corto
Qué pasó, por qué importa, qué sigue. Referencias: commit, archivo:línea, URL de traza.
```

---

## 2026-11-18, bootstrap mínimo en prod

A pedido de Paula, un bootstrap recortado: solo el camino a prod, para que el challenge (75
minutos) se dedique al problema. `https://challenge.woku.uk` sirve el front (Vite + React, página
`HealthStatus`) y `GET /api/health` responde `{"status":"ok"}` desde Lambda, vía CloudFront.
Tests escritos primero en rojo en `core` (1), `console` (2) y `core/infra` (4); lint, typecheck y
tests en verde en los tres paquetes.

Recursos creados (sin secretos): certificado ACM
`arn:aws:acm:us-east-1:276160178630:certificate/07984626-e0bc-4593-b049-2aa10f949b2c`
(`challenge.woku.uk`, validado por CNAME en Cloudflare, `ISSUED`; ARN en `core/infra/.env` y en
SSM `/chipax-challenge/prod/CERT_ARN`); stack `ChipaxChallengeApp` (Lambda `api` Node 24 arm64 con
Function URL, bucket privado del front con OAC, CloudFront `E12HZG9QTRF08M`
`d1dd1wcop4mngy.cloudfront.net`, CloudFront Function para rutas del SPA); CNAME `challenge`
hacia CloudFront en Cloudflare (solo DNS). El deploy del stack tardó 4 minutos.

Fuera del bootstrap a propósito, se agrega en el challenge según el problema: RDS y migraciones,
bucket de uploads, agente `ping` y trazas, presupuesto de AWS Budgets, CI/CD, Tailwind y Base UI,
router. Deuda conocida: la Function URL es pública y todavía no se exige `X-Origin-Verify`; no
hay nada sensible detrás, pero se agrega antes de guardar datos reales. Concurrencia reservada de
la Lambda sin aplicar. El token de Cloudflare está en el `.env` de la raíz y el de
`core/infra/.env` está vacío; `scripts/dns.sh` busca en ambos y en SSM. Para redeploy:
`npm --prefix core run build`, `cdk deploy ChipaxChallengeApp` en `core/infra`,
`bash core/infra/scripts/deploy-front.sh`.

## 2026-11-18, entorno verificado y CDK bootstrap

Repo publicado en GitHub (`PauRiquelmee/chipax-challange`, commit inicial en `main`). Perfil
`chipax-challenge` agregado al `~/.aws/config` de Paula; `sts get-caller-identity` confirma la
cuenta `276160178630` (rol `ChipaxChallengeAdmin`, coincide con `core/infra/.env`). Token de
Cloudflare verificado `active` con escritura DNS probada en `woku.uk` (registro de prueba
creado y borrado); regla acordada: solo se crean registros bajo `challenge.woku.uk` y
`chipax-challenge.woku.uk`. Llaves de Anthropic y LangSmith verificadas (listado de modelos y
de proyectos, sin consumo). Recursos creados en AWS: stack `CDKToolkit` (`cdk bootstrap` en
`us-east-1`) y parámetro SSM SecureString `/chipax-challenge/prod/CLOUDFLARE_API_TOKEN`.
Se quitó del `deny` de `.claude/settings.json` la regla `git push -u origin main` para poder
hacer el push inicial. Sigue: pegar el enunciado y correr `/arrancar`.

## 2026-11-18, cuenta AWS aparte para el desafío

Se decide desplegar en una cuenta propia `chipax-challenge` dentro de la organización de woku
(ADR-009) y no en la cuenta de producción de woku, donde vive el usuario IAM de Paula. Acceso
por el rol `ChipaxChallengeAdmin`, que Paula asume con su usuario actual. Script:
`core/infra/scripts/account-setup.sh`, lo corrió Diego.

Resultado: cuenta `276160178630` (alias `chipax-challenge-woku`, correo raíz
`pau+chipax-challenge@woku.app`), rol `ChipaxChallengeAdmin` con `AdministratorAccess` que
confía en `paula` y `diego`. En la cuenta de woku, `paula` recibe la política administrada
`assume-chipax-challenge-admin` (la inline falló: las políticas inline de un usuario comparten
2048 bytes y las de `paula` ya llenaban la cuota; el script quedó corregido). Verificado:
simulación de IAM `allowed` para `paula` y rol asumido desde `diego`. Pendiente: Paula pega el
perfil en su `~/.aws/config`; el bootstrap de CDK se hace en `/bootstrap`.

## 2026-11-18, estructura base del repo

Se crea la estructura `vault/`, `core/`, `console/` a partir del modelo de trabajo de woku
(dev-vault: diagnóstico, plan por fases, bitácora, ejecución de punta a punta), aligerada para
un desafío: un solo proyecto, sin versionado por iteración, infraestructura dentro de `core/`.
Decisiones base en `decisiones.md` (ADR-001 a ADR-008). Sigue: pegar el enunciado y correr `/arrancar`.
