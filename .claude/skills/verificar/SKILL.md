---
name: verificar
description: Verifica una fase de punta a punta. Gates de core y console, escenarios en el navegador con el MCP de Chrome (desktop y móvil), trazas de agentes en LangSmith y auditoría de UX con impeccable, dejando evidencia en vault/evidencia. Úsala antes de abrir el PR de una fase y después de cada deploy.
---

# Verificación de punta a punta

"Implementado" pasa a "verificado en local" (o "en prod verificado") solo con este skill y su
evidencia escrita.

## 1. Gates

En cada paquete tocado, con los mismos comandos que la CI:

```bash
docker compose up -d
(cd core && npm ci && npm run check)
(cd console && npm ci && npm run check)
```

Todo verde o no se sigue. Anotar fecha, commit y resultado en `vault/evidencia/pruebas.md`.

## 2. Escenarios en el navegador (MCP de Chrome)

Local: `npm run dev` en core y console. Prod: `https://challenge.woku.uk`.

1. Cargar las herramientas del MCP de Chrome en una sola búsqueda y abrir una pestaña nueva.
2. Por cada escenario de la fase: ejecutarlo como lo haría la persona usuaria, de principio a
   fin, con datos realistas.
3. En cada pantalla: leer la consola (`read_console_messages`, filtrando errores) y las
   requests (`read_network_requests`, sin 4xx/5xx inesperados).
4. Repetir en 390 px de ancho (`resize_window`).
5. Captura de cada estado relevante en `vault/evidencia/capturas/<fase>-<escenario>-<estado>.png`.
   Para flujos de varios pasos, un GIF con `gif_creator`.
6. Si algo falla: test que lo reproduce, arreglo, y volver a correr el escenario.

## 3. Agentes (LangSmith)

Por cada escenario que pasa por un agente:

- Encontrar la traza del turno (MCP de LangSmith o UI) en el proyecto que corresponde
  (`-local` o `-prod`).
- Comprobar: una sola traza raíz por turno; adentro, persistencia, pull del prompt, llamadas
  al modelo y herramientas; tokens y latencia razonables; sin errores ni trazas huérfanas;
  prompt leído del Hub en prod.
- Anotar la URL de la traza en `pruebas.md`.

## 4. UX/UI

- `/impeccable audit` sobre las pantallas de la fase.
- Hallazgos en `vault/evidencia/ux-review.md` con severidad. Los críticos y altos se arreglan
  en esta fase (con test cuando aplique); los menores quedan anotados.

## 5. Cierre

- `PLAN.md`: marcar los pasos y actualizar la línea "Estado" de la fase.
- Commit `:memo: Add F<n> verification evidence` en la rama de la fase.
- Si todo está verde y verificado: seguir con el PR (ver "Git" en `CLAUDE.md`).
