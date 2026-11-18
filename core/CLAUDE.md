# CLAUDE.md, core/

Backend del desafío: TypeScript + Express 5 sobre AWS Lambda (Node 24), PostgreSQL con
Drizzle, archivos en S3, agentes LangGraph con Claude, trazas y prompts en LangSmith.
La infraestructura de todo el sistema (también el hosting del front) vive en `infra/`.

Antes de tocar agentes, leer `docs/agentes.md`. Antes de tocar infraestructura o deploy,
leer `docs/infra.md`.

## Estructura

```
core/
  src/
    app.ts                  createApp(deps): arma Express. Lo usan los tests (supertest), el server local y la Lambda
    server.ts               local: app.listen(PORT)
    lambda.ts               prod: carga secretos de SSM, buildContainer(), serverless-http(app)
    container.ts            raíz de composición: crea db, s3, llm, repos, services, agentes
    config/env.ts           esquema zod del entorno; falla al arrancar si falta algo
    config/ssm.ts           en Lambda: GetParametersByPath(SSM_PREFIX) -> process.env
    db/client.ts            pool pg + drizzle (max 2 conexiones en Lambda)
    db/schema/*.ts          tablas Drizzle
    contracts/<feature>.contract.ts   esquemas zod de request (body, params, query) y response; console los importa (@contracts)
    modules/<feature>/
      <feature>.routes.ts          solo cableado: método + path + validate(schemas) + controller
      <feature>.controller.ts      capa HTTP: toma el input ya validado, llama al service, arma status y respuesta con el contrato
      <feature>.service.ts         lógica de negocio: input tipado, reglas, AppError; sin Express ni SQL
      <feature>.repository.ts      acceso a datos con Drizzle; sin reglas de negocio
      <feature>.service.spec.ts    unitario, repositorio falso
      <feature>.controller.spec.ts HTTP con supertest y service falso
      <feature>.repository.int.spec.ts   integración contra challenge_test
    agents/<agent>/
      <agent>.agent.ts       turno completo bajo una traza raíz (docs/agentes.md)
      <agent>.agent.spec.ts  con modelo falso
      tools/*.tool.ts        herramientas: zod + función pura testeable
      prompts/*.prompt.ts    registro local del prompt (fuente de verdad del Hub)
    shared/
      http/validate.ts       validate({ body, params, query }): middleware zod, deja el input tipado
      http/errors.ts         AppError + middleware de errores (formato único; ZodError -> 400)
      http/origin-verify.ts  exige X-Origin-Verify en prod
      http/rate-limit.ts     límite por IP para endpoints que llaman al LLM
      storage/s3.ts          URLs prefirmadas, keys `uploads/<uuid>-<nombre>`
      llm/models.ts          fábrica de ChatAnthropic desde el entorno
      tracing/traced.ts      traced(fn, name, runType) sobre langsmith/traceable
      tracing/flush.ts       vacía trazas pendientes antes de responder (Lambda)
      prompts/hub.ts         pull del Hub con respaldo local
  drizzle/                  migraciones generadas (se versionan)
  scripts/push-prompts.ts   publica todos los prompts registrados al Hub
  evals/                    evals con LLM real (fuera de la suite)
  infra/                    AWS CDK + scripts de Cloudflare/ACM (docs/infra.md)
  docs/                     agentes.md, infra.md
```

## Reglas de arquitectura

1. **Flujo único y separación estricta**: `routes -> controller -> service -> repository`.
   Cada capa tiene una sola responsabilidad y un revisor sabe qué buscar en cada archivo:

   | Capa | Hace | Nunca hace |
   |---|---|---|
   | `routes` | Declara método, path, `validate(...)` y el handler del controller | Lógica, try/catch, acceso a datos |
   | `controller` | Lee el input validado, llama **un** método del service, elige el status, da forma a la respuesta con el esquema del contrato | Reglas de negocio, SQL, llamar a otro repositorio, decidir permisos de negocio |
   | `service` | Reglas de negocio, orquesta repositorios y servicios externos (S3, LLM), lanza `AppError` | Conocer `req`/`res`, status HTTP, SQL |
   | `repository` | Consultas Drizzle, mapea filas a tipos de dominio | Reglas de negocio, validar input del usuario |

2. **Zod en todos los bordes** (lo que entra al sistema se valida, lo de adentro confía en los tipos):
   - request HTTP: `validate({ body, params, query })` con los esquemas del contrato, antes del controller;
   - response HTTP: el controller pasa el resultado por el esquema de respuesta (`Schema.parse`),
     así nunca se filtra un campo interno y el front recibe exactamente el contrato;
   - entorno: `config/env.ts` al arrancar;
   - herramientas de agentes: el `schema` zod de cada tool;
   - salidas del LLM y de APIs externas: se parsean con zod antes de usarlas.
   Los tipos salen de los esquemas (`z.infer<typeof CreateInvoiceBody>`); no se escriben a mano
   interfaces que dupliquen un esquema.
3. **Inyección por fábricas**: `createInvoiceService({ invoices, storage })` y
   `createInvoiceController({ invoiceService })` reciben dependencias; nada se importa como
   singleton salvo en `container.ts`. Así los tests pasan dobles sin mocks de módulos.
4. **Un módulo no importa el repositorio de otro.** Si necesita algo de otro módulo, recibe
   su service por la fábrica.
5. **Errores con formato único**: `{ "error": { "code": "INVOICE_NOT_FOUND", "message": "...", "details": {} } }`.
   El service lanza `AppError`; el middleware de errores traduce a HTTP. `ZodError` -> 400 con
   los `issues` en `details`. Los controllers no tienen try/catch (Express 5 propaga los
   errores de handlers async).
6. **Todas las rutas bajo `/api`**, igual en local y en prod. `app.ts` monta cada
   `<feature>.routes.ts`; no hay rutas declaradas en otro lado.
7. **Archivos nunca pasan por la Lambda**: URL prefirmada de subida y de bajada (ADR-005).
8. **Endpoints que llaman al LLM**: rate limit por IP, límite de tokens por conversación y
   timeout explícito. Si un turno puede pasar de ~45 s, patrón de corrida asíncrona
   (`docs/agentes.md`).
9. **Nombres**: archivos `kebab-case.suffix.ts`; clases y tipos `PascalCase`; funciones y
   variables `camelCase`; constantes `UPPER_SNAKE_CASE`. Código y comentarios en inglés.
10. TypeScript `strict: true` desde el día uno. Sin `any` salvo en el borde con librerías, y
    comentado.

## Ejemplo de un módulo

Referencia de forma (verificar firmas contra las versiones instaladas). Un endpoint
`POST /api/invoices` de punta a punta:

```ts
// contracts/invoice.contract.ts: lo comparten core y console
export const CreateInvoiceBody = z.object({
  folio: z.string().min(1),
  amount: z.number().int().positive(),
  issuedAt: z.iso.date(),
});
export const InvoiceResponse = z.object({
  id: z.uuid(), folio: z.string(), amount: z.number(), issuedAt: z.string(), status: z.enum(['pending', 'paid']),
});
export type CreateInvoiceInput = z.infer<typeof CreateInvoiceBody>;

// modules/invoices/invoices.routes.ts: solo cableado
export function invoicesRoutes(controller: InvoicesController) {
  const router = Router();
  router.post('/invoices', validate({ body: CreateInvoiceBody }), controller.create);
  router.get('/invoices/:id', validate({ params: IdParams }), controller.getById);
  return router;
}

// modules/invoices/invoices.controller.ts: HTTP, sin negocio
export function createInvoicesController({ invoiceService }: { invoiceService: InvoiceService }) {
  return {
    create: async (req: ValidatedRequest<{ body: typeof CreateInvoiceBody }>, res: Response) => {
      const invoice = await invoiceService.create(req.validated.body);
      res.status(201).json(InvoiceResponse.parse(invoice));
    },
    getById: async (req: ValidatedRequest<{ params: typeof IdParams }>, res: Response) => {
      res.json(InvoiceResponse.parse(await invoiceService.getById(req.validated.params.id)));
    },
  };
}

// modules/invoices/invoices.service.ts: negocio, sin HTTP ni SQL
export function createInvoiceService({ invoices }: { invoices: InvoiceRepository }) {
  return {
    async create(input: CreateInvoiceInput) {
      if (await invoices.findByFolio(input.folio)) {
        throw new AppError('INVOICE_DUPLICATED', `Invoice ${input.folio} already exists`, 409);
      }
      return invoices.insert({ ...input, status: 'pending' });
    },
    async getById(id: string) {
      const invoice = await invoices.findById(id);
      if (!invoice) throw new AppError('INVOICE_NOT_FOUND', 'Invoice not found', 404);
      return invoice;
    },
  };
}
export type InvoiceService = ReturnType<typeof createInvoiceService>;
```

El repositorio expone `findById`, `findByFolio`, `insert` con Drizzle y devuelve tipos de
dominio. `container.ts` arma la cadena: repository -> service -> controller -> routes.

## TDD aquí

- Ciclo: test en rojo -> mínimo código -> verde -> refactor. Commit por paso cohesivo.
- Orden típico de un endpoint: test del contrato (esquemas aceptan y rechazan lo correcto) ->
  test del service (reglas de negocio) -> test del controller (HTTP) -> test de integración del
  repositorio. Cada capa se prueba sola, con la de abajo falsa.
- **Contratos** (`*.contract.spec.ts`): casos válidos e inválidos de cada esquema.
- **Services** (`*.service.spec.ts`): reglas de negocio con un repositorio falso (objeto que
  implementa la interfaz). Aquí vive la mayor parte de los tests. Rápidos, sin red.
- **Controllers** (`*.controller.spec.ts`): `supertest(createApp(depsFalsas))` con el service
  falso. Validan status, 400 por input inválido (zod), formato de error al lanzar `AppError` y
  que la respuesta cumple el contrato. No repiten reglas de negocio.
- **Integración** (`*.int.spec.ts`): repositorios contra Postgres real (`DATABASE_URL_TEST`),
  migraciones aplicadas en el `globalSetup`, cada test en una transacción con rollback o con
  truncado.
- **Agentes**: modelo falso de `@langchain/core/utils/testing` con respuestas y tool calls
  guionizadas; se verifica que se llamaron las herramientas correctas y que se persistió el
  turno. La calidad de las respuestas se mide en `evals/`, no en la suite.
- Nunca un test que pase contra un mock que se afirma a sí mismo: cada test describe
  comportamiento observable.

## Comandos

```bash
npm run dev            # tsx watch src/server.ts (:3000)
npm test               # vitest run (unit + http)
npm run test:int       # vitest run --project int (necesita docker compose up)
npm run lint           # eslint
npm run typecheck      # tsc --noEmit
npm run check          # lint + typecheck + test + test:int (gate antes de commit y PR)
npm run db:generate    # drizzle-kit generate (nueva migración desde el schema)
npm run db:migrate     # aplica migraciones a DATABASE_URL
npm run prompts:push   # publica los prompts registrados al Hub de LangSmith
npm run eval           # evals con LLM real (cuesta dinero, traza en proyecto -evals)
npm run build          # esbuild -> dist/lambda.js (bundle para Lambda)
npm --prefix infra run deploy   # cdk deploy (ver docs/infra.md)
```

## Variables de entorno

`.env.example` es la referencia y se versiona; `.env` es local y no se versiona. Toda
variable nueva se agrega a la vez en: `.env.example`, `src/config/env.ts` (zod) y SSM de prod
(`docs/infra.md`). En prod la Lambda solo recibe `SSM_PREFIX` y valores no secretos; los
secretos se leen de SSM en el arranque en frío.

## Gotchas

1. **Lambda congela el proceso al responder**: si las trazas de LangSmith se envían en
   segundo plano se pierden. `LANGCHAIN_CALLBACKS_BACKGROUND=false` y además `flushTraces()`
   en un `finally` antes de devolver la respuesta.
2. **Conexiones a Postgres en Lambda**: el pool se crea fuera del handler y con `max: 2`.
   Concurrencia reservada de la Lambda acotada (ver infra) para no agotar conexiones del
   `t4g.micro`.
3. **Claude Opus 5.5 / Sonnet 5.5**: no aceptan `temperature`, `top_p` ni `top_k`, ni
   `tool_choice` forzado (`any` o `tool`), ni prefill del asistente. Ojo con
   `withStructuredOutput`: si la versión instalada usa tool calling forzado, falla con 400;
   usar el modo de JSON schema (salidas estructuradas). Verificarlo en la primera traza.
4. **Prompts**: con `LANGSMITH_USE_HUB=true` editar el `.prompt.ts` no cambia prod hasta
   correr `prompts:push`. No se editan prompts desde la UI del Hub: el repo es la fuente de verdad.
5. **Postgres local vs test**: los tests de integración usan `challenge_test`, nunca la base
   de desarrollo.
6. **MinIO local** necesita `S3_FORCE_PATH_STYLE=true`; en prod se deja en `false` y sin
   `S3_ENDPOINT`.
