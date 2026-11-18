---
name: desplegar
description: Lleva una fase verificada a producción. PR a main, merge con CI verde, seguimiento del deploy automático, verificación en challenge.woku.uk y release. Úsala al cerrar cada fase.
---

# Camino a prod de una fase

Precondición: la fase está "verificada en local" con evidencia (`/verificar`).

## Pasos

1. **Prerrequisitos de prod** de la fase, según el plan: variables nuevas en SSM y en CDK,
   migraciones compatibles con la versión anterior del código, prompts nuevos registrados en
   `prompt-registry.ts`. Anotar en la bitácora lo que se agregó.
2. **Regla sagrada**: `npm ci && npm run check` en core y console. Todo verde.
3. **PR**: `git push -u origin <rama>` y
   `gh pr create --base main --title "F<n>: <escenario>" --body "<escenario, cómo se probó, evidencia del vault>"`.
4. **CI**: `gh pr checks --watch`. Si falla: arreglar en la rama, push, esperar de nuevo.
5. **Merge**: `gh pr merge --merge --delete-branch`. Luego `git checkout main && git pull`.
6. **Deploy**: `gh run watch` sobre el workflow `deploy` disparado por el merge. Si falla, leer
   el log (`gh run view --log-failed`), arreglar en una rama `hotfix/<tema>` desde `main` y
   repetir desde el paso 2.
7. **Verificación en prod**: `/verificar` contra `https://challenge.woku.uk` (escenarios de la
   fase y un repaso rápido de los anteriores), trazas en el proyecto `-prod`, logs de la
   Lambda sin errores (`aws logs tail /aws/lambda/<función> --since 15m`).
8. **Release**: `gh release create vX.Y.Z --generate-notes --title "vX.Y.Z"` (MINOR por fase
   nueva, PATCH por fixes).
9. **Cierre**: `PLAN.md` con la fase "en prod verificado"; entrada en la bitácora con versión,
   URL del run y evidencia. Si era la última fase, `estado: produccion` y README de entrega.

## Si prod falla

- Revertir con PR: rama `hotfix/revert-<tema>` desde `main`, `git revert -m 1 <merge>`, PR,
  merge. No se arregla a mano en la consola de AWS.
- Anotar el incidente en la bitácora: qué pasó, cómo se detectó, qué test faltaba.
