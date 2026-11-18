# CLAUDE.md, console/

Frontend del desafío: Vite + React + TypeScript, React Router v7 en data mode
(`createBrowserRouter` + loaders), Tailwind CSS v4, Base UI (`@base-ui/react`) como base de
los componentes de bajo nivel, TanStack Query para el estado del servidor, Zustand para el
estado de UI, Zod para validar todo lo que llega de la API.
Se sirve como estático desde S3 + CloudFront en `https://challenge.woku.uk`.

## Antes de cualquier pantalla

1. **`/opciones-ui`**: un artefacto con 3 opciones para la pantalla o flujo. Se espera la
   elección de la responsable, que queda en `vault/ui/opciones.md`. Sin elección, no hay código.
2. **`impeccable`** para todo trabajo de interfaz. La primera vez, después de la elección,
   `/impeccable init` deja `PRODUCT.md` y `DESIGN.md` en `console/` (tokens, tipografía,
   tono). Esos dos archivos mandan sobre el gusto personal.
3. Modo de `impeccable`: casi siempre **Operate** (la persona completa una tarea:
   escaneabilidad, consistencia, estados claros).

## Estructura

```
console/
  src/
    main.tsx                   QueryClientProvider + RouterProvider
    router.tsx                 createBrowserRouter: rutas, loaders, errorElement por ruta
    lib/
      api.ts                   apiFetch(path, schema): fetch a /api + parse con zod + ApiError
      query-client.ts          QueryClient único (staleTime, retry sensatos)
    components/                compartidos entre features (se importan desde cualquier módulo)
      Button/
        Button.tsx             envuelve Base UI, estilos con los tokens de DESIGN.md
        Button.test.tsx
        index.ts               export { default } from './Button'; export type { ButtonProps } from './Button';
      Dialog/  Input/  Field/  Select/  Toast/  EmptyState/  PageHeader/ ...
    features/<feature>/
      routes/
        InvoiceList/
          InvoiceList.tsx      componente de ruta (default) + loader (export nombrado)
          InvoiceList.test.tsx
          index.ts             export { default, loader } from './InvoiceList';
      components/
        InvoiceTable/
          InvoiceTable.tsx
          InvoiceTable.test.tsx
          index.ts
      api.ts                   queryOptions(...) y mutations de la feature
      store.ts                 Zustand, solo si hay estado de UI que compartir
    styles/index.css           @import "tailwindcss" + @theme con los tokens de DESIGN.md
    test/
      setup.ts                 jest-dom, MSW server, limpieza
      msw/handlers.ts          handlers que responden con datos que cumplen los contratos
  base-ui-llms.txt             índice de la documentación de Base UI (leer antes de envolver un componente)
  PRODUCT.md, DESIGN.md        los crea impeccable
```

Alias: `@/` -> `src/` y `@contracts/*` -> `../core/src/contracts/*` (los mismos esquemas zod
que valida el backend), configurados en Vite y tsconfig.

## Componentes

**Regla de carpeta, para todos los componentes** (bajo nivel, de feature y de ruta):

- Cada componente vive en una carpeta con su nombre en PascalCase, con exactamente:
  `Nombre.tsx` (el componente como `export default`, y sus tipos de props exportados),
  `Nombre.test.tsx` y `index.ts` que reexporta el default (`export { default } from './Nombre';`
  más los tipos y, en rutas, el `loader`).
- Se importa por la carpeta, nunca por el archivo, para no repetir el nombre:

  ```ts
  import Button from '@/components/Button';                 // bien
  import InvoiceTable from '../components/InvoiceTable';     // bien
  import Button from '@/components/Button/Button';          // mal: nombre repetido
  ```

  ESLint lo hace cumplir con `no-restricted-imports` (patrón por regex que rechaza
  `.../Nombre/Nombre`). Sin barrel global en `components/index.ts`: cada import apunta a su
  carpeta (evita ciclos y mantiene el tree-shaking).
- Subcomponentes privados de uno mayor van en su propia carpeta dentro de la carpeta del
  padre (`InvoiceTable/InvoiceRow/`), con la misma regla.

**Dónde va cada uno**:

| Tipo | Carpeta | Ejemplo |
|---|---|---|
| Bajo nivel, envuelve Base UI | `src/components/` | `Button`, `Input`, `Field`, `Dialog`, `Select`, `Menu`, `Tabs`, `Toast`, `Tooltip` |
| Compuesto reutilizable entre features | `src/components/` | `EmptyState`, `PageHeader`, `FileDropzone`, `DataTable` |
| Propio de una feature | `src/features/<feature>/components/` | `InvoiceTable`, `UploadSummary` |
| Pantalla | `src/features/<feature>/routes/` | `InvoiceList`, `InvoiceDetail` |

Una feature no importa componentes de otra feature: si dos lo necesitan, se mueve a
`src/components/`.

**Base UI**:

- Todo componente interactivo de bajo nivel (botón, input, select, diálogo, menú, tabs,
  tooltip, toast, checkbox, switch, etc.) se construye sobre `@base-ui/react`, no desde cero
  ni con otra librería. Base UI trae accesibilidad y teclado; nosotros ponemos el estilo.
- Antes de crear o cambiar un envoltorio, abrir en `base-ui-llms.txt` el `.md` del componente
  (y el de Styling o Composition si aplica) y seguir su API real. No adivinar props.
- Estilos con Tailwind usando los tokens de `DESIGN.md`; estados con los atributos que expone
  Base UI (`data-disabled`, `data-pressed`, `data-open`, `data-highlighted`...) en vez de
  estado propio.
- Las features usan los envoltorios de `src/components/`, nunca `@base-ui/react` directo.
- Variantes por props tipadas (`variant`, `size`), pocas y las que pida `DESIGN.md`.

```tsx
// src/components/Button/Button.tsx (forma de referencia; verificar API en la doc de Base UI)
import { Button as BaseButton } from '@base-ui/react/button';
import type { ComponentProps } from 'react';

export type ButtonProps = ComponentProps<typeof BaseButton> & {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
};

export default function Button({ variant = 'primary', className, ...props }: ButtonProps) {
  return <BaseButton {...props} className={cn(buttonStyles[variant], className)} />;
}

// src/components/Button/index.ts
export { default } from './Button';
export type { ButtonProps } from './Button';
```

## Reglas

1. **Estado del servidor solo en TanStack Query.** Nunca copiar datos de la API a Zustand ni
   a `useState`. Zustand es para UI: filtros en edición, paneles abiertos, borradores.
2. **Loaders precargan, componentes leen**: el loader hace
   `queryClient.ensureQueryData(invoiceQuery(id))` y el componente usa
   `useSuspenseQuery(invoiceQuery(id))`. Una sola definición de `queryOptions` por recurso.
3. **Mutaciones** con `useMutation` + `invalidateQueries` (o `setQueryData` si la respuesta ya
   trae el recurso). Estados de carga y error visibles en el botón o formulario.
4. **Toda respuesta pasa por zod** (`apiFetch(path, Schema)`). Un error de parseo es un bug y
   se muestra como error, no se ignora.
5. **Cada ruta tiene `errorElement`** y cada lista tiene estado vacío, cargando y error.
6. **Archivos**: pedir URL prefirmada a la API, `PUT` directo a S3 con progreso, confirmar.
7. **Accesibilidad**: HTML semántico, labels en todos los inputs, foco visible, navegable con
   teclado, contraste AA. Probar en 390 px y 1440 px.
8. Textos de la interfaz en español neutro (o en el idioma que pida el desafío). Código en inglés.
9. Base UI es la única librería de componentes. Otra (gráficos, tablas virtualizadas, editor)
   solo con decisión anotada en `vault/decisiones.md`, y también se envuelve en
   `src/components/` con la regla de carpeta.

## TDD aquí

- Test primero con Testing Library: se escribe como lo usaría una persona
  (`getByRole`, `getByLabelText`, `userEvent`), no contra detalles de implementación.
- Cada componente trae su `Nombre.test.tsx` en su carpeta. En los de bajo nivel se prueba
  lo que agregamos sobre Base UI (variantes, estados deshabilitado o cargando, que reenvía
  props y `ref`), no el comportamiento interno de Base UI.
- MSW intercepta `/api/*` con respuestas que cumplen los contratos; para casos de error, un
  handler por test (`server.use(...)`).
- Rutas con loaders se prueban con `createMemoryRouter` + el mismo `QueryClient` de prueba.
- Stores de Zustand se prueban como funciones puras (estado inicial, acciones).
- Lo que los tests no ven (layout, responsive, animación, sensación) se verifica con el MCP de
  Chrome en `/verificar`.

## Comandos

```bash
npm run dev          # vite (:5173), proxy /api -> VITE_API_PROXY_TARGET
npm test             # vitest run
npm run lint         # eslint
npm run typecheck    # tsc --noEmit
npm run check        # lint + typecheck + test (gate antes de commit y PR)
npm run build        # vite build -> dist/
```

## Gotchas

1. Todo `VITE_*` termina en el bundle público: nunca secretos.
2. React Router v7: el paquete es `react-router` (incluye lo que antes era `react-router-dom`);
   `RouterProvider` para DOM se importa desde `react-router/dom`.
3. Rutas del SPA en prod las resuelve una CloudFront Function; si una ruta nueva da 403 en
   prod, revisar esa función, no el router.
4. El proxy de Vite solo existe en `npm run dev`; `vite preview` necesita el mismo proxy
   configurado en `preview.proxy`.
