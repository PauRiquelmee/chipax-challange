---
name: opciones-ui
description: Antes de programar cualquier pantalla o flujo del front, crea un artefacto con 3 opciones de diseño distintas, lo publica y espera la elección de la responsable. Úsala siempre antes de tocar UI en console/.
---

# Tres opciones antes de programar

Regla dura del repo: **no se escribe código de interfaz sin una opción elegida**. Este skill
produce la elección; no implementa.

## Pasos

1. **Contexto**: leer el escenario del plan que toca, `DIAGNOSTICO.md` (usuarios, dominio) y,
   si existen, `console/PRODUCT.md` y `console/DESIGN.md`. Si ya hubo rondas anteriores en
   `vault/ui/opciones.md`, las opciones nuevas respetan lo ya elegido (mismo mundo visual) y
   varían lo que esta ronda decide.
2. **Cargar `impeccable`** y su referencia de trabajo nuevo; modo Operate salvo que la
   pantalla sea de persuasión o lectura.
3. **Diseñar 3 opciones realmente distintas**, no variaciones de color. Cada una con una idea
   central nombrada (por ejemplo: "tabla densa con panel lateral", "flujo guiado por pasos",
   "tablero con tarjetas de estado"), y para cada una:
   - la pantalla o flujo completo con **contenido real del desafío** (nada de lorem ipsum);
   - estados clave: vacío, cargando, error, con datos;
   - vista desktop (1440 px) y móvil (390 px);
   - en 3 o 4 líneas: para quién funciona mejor, qué sacrifica, costo de implementación.
4. **Un solo artefacto HTML** con las 3 opciones (pestañas o columnas), interactivo donde la
   interacción sea parte de la decisión. Antes de escribirlo, cargar el skill
   `artifact-design`; luego publicar con la herramienta `Artifact`.
5. Revisar el artefacto publicado con el MCP de Chrome en ambos anchos (una pasada, corregir
   en lote, no iterar sin fin).
6. **Registrar** la ronda en `vault/ui/opciones.md` (fecha, pantallas, enlace, nombres de las
   opciones; "Elegida" vacía).
7. **Parar y preguntar**: enlace al artefacto, una línea por opción y la recomendación propia
   con su porqué. No seguir hasta tener respuesta.

## Al recibir la elección

- Llenar "Elegida" y "Motivo y ajustes pedidos" en `vault/ui/opciones.md`; entrada en la
  bitácora.
- Primera ronda del proyecto: `/impeccable init` para dejar `console/PRODUCT.md` y
  `console/DESIGN.md` con el mundo visual elegido (tokens, tipografía, espaciado, tono).
  Rondas siguientes: actualizar `DESIGN.md` si la elección agrega componentes o patrones.
- Recién ahí se programa, con TDD, siguiendo `console/CLAUDE.md`: primero los envoltorios de
  Base UI que la opción necesita en `src/components/` (cada uno en su carpeta, leyendo su doc
  desde `console/base-ui-llms.txt`), después los componentes de la feature y la pantalla.
