# Bitácora

Registro fechado del proyecto. Lo más nuevo arriba. Una entrada por hecho relevante:
partida, decisión, discrepancia con el plan, bloqueo, aprendizaje, deploy.

Formato:

```
## AAAA-MM-DD, título corto
Qué pasó, por qué importa, qué sigue. Referencias: commit, archivo:línea, URL de traza.
```

---

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
