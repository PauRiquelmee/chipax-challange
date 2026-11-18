# Decisiones

ADR cortos. Las de base (001 a 008) vienen con la estructura del repo y aplican a cualquier
desafío; las del desafío se agregan desde ADR-100. Formato: contexto, decisión, alternativas,
consecuencias.

## ADR-001. Backend en Express, no NestJS

- **Contexto**: un desafío tiene pocos endpoints y corre en Lambda, donde el arranque en frío
  cuenta. NestJS ordena bien un producto grande (woku) pero agrega decoradores, módulos y
  reflexión que aquí no pagan su costo.
- **Decisión**: Express 5 con módulos por feature y capas separadas en archivos distintos
  (`routes -> controller -> service -> repository`), zod en todos los bordes (request,
  response, entorno, herramientas de agentes, salidas del LLM), inyección de dependencias por
  funciones fábrica y una raíz de composición (`container.ts`). El orden lo imponen las reglas
  de `core/CLAUDE.md`, no el framework. La separación busca que el código se revise rápido:
  cada archivo tiene una sola responsabilidad conocida.
- **Alternativas**: NestJS (más estructura, más arranque y más boilerplate); Fastify (similar,
  menos conocido por quien evalúa).
- **Consecuencias**: servicios testeables sin framework; si el desafío crece mucho, migrar a
  Nest es mecánico porque la separación ya existe.

## ADR-002. PostgreSQL en RDS, Lambda fuera de VPC

- **Contexto**: Lambda dentro de una VPC necesita NAT Gateway (unos USD 32 al mes más tráfico)
  para llegar a Claude y LangSmith. Para un desafío eso es costo y complejidad sin retorno.
- **Decisión**: RDS PostgreSQL 18 `db.t4g.micro`, accesible públicamente pero con TLS forzado
  (`rds.force_ssl=1`), contraseña generada en Secrets Manager, usuario de aplicación solo DML
  y migraciones con un usuario aparte. Lambda fuera de la VPC, pool de 1 a 2 conexiones por
  contenedor y concurrencia reservada acotada.
- **Alternativas**: Lambda en VPC + NAT (más seguro, más caro); Aurora Serverless v2 con Data
  API (sin VPC, pero driver distinto al local y sin checkpointer de LangGraph); MongoDB Atlas
  (plan B si RDS se complica: el diagnóstico lo decide).
- **Consecuencias**: el endpoint de la base es alcanzable desde internet; mitigado con TLS,
  credenciales fuertes y usuario sin DDL. Camino de mejora documentado: VPC + NAT o RDS Proxy.

## ADR-003. Un solo dominio: CloudFront delante del front y de la API

- **Contexto**: front y API en dominios distintos obligan a CORS, dos certificados y cookies
  entre sitios.
- **Decisión**: `challenge.woku.uk` apunta a una distribución CloudFront con dos orígenes: el
  bucket S3 del front (comportamiento por defecto, con OAC) y la Function URL de la Lambda
  para `/api/*`. CloudFront agrega un encabezado secreto (`X-Origin-Verify`) que la API exige,
  así la Function URL no se usa directo. Rutas del SPA resueltas con una CloudFront Function
  (no con páginas de error, que esconderían los 404 de la API).
- **Alternativas**: API Gateway HTTP API (límite duro de 30 s por request); subdominio aparte
  para la API.
- **Consecuencias**: mismo origen en local (proxy de Vite) y en prod; timeouts de origen de
  CloudFront hasta 60 s. Un agente que pueda tardar más usa el patrón de corrida asíncrona
  (`core/docs/agentes.md`).

## ADR-004. DNS en Cloudflare, certificado en ACM

- **Contexto**: la zona `woku.uk` está en Cloudflare; CloudFront exige un certificado de ACM en
  `us-east-1`.
- **Decisión**: un script (`core/infra/scripts/`) pide el certificado en ACM, crea el CNAME de
  validación y luego el CNAME `challenge` hacia CloudFront con la API de Cloudflare, ambos en
  modo DNS only (sin proxy naranjo, para no apilar dos CDN). Token de Cloudflare acotado a
  `Zone:DNS:Edit` sobre `woku.uk`.
- **Consecuencias**: la infraestructura AWS queda en CDK y el DNS en un script idempotente.

## ADR-005. Archivos en S3 con prefijo de id

- **Decisión**: bucket privado; cada archivo se guarda como `uploads/<uuid>-<nombre-saneado>`.
  Subida directa del navegador a S3 con URL prefirmada (Lambda tiene un límite de 6 MB por
  payload), bajada con URL prefirmada de vida corta. La base guarda el `key`, nombre original,
  tipo, tamaño y dueño.
- **Consecuencias**: sin colisiones de nombre y sin pasar binarios por la Lambda.

## ADR-006. Agentes con LangGraph + Claude, trazas y prompts en LangSmith

- **Decisión**: agentes ReAct de LangGraph con `ChatAnthropic` (Claude Platform). Modelo por
  variable de entorno (`claude-opus-5-5` por defecto, `claude-haiku-5-5` para tareas simples).
  Cada turno es una sola traza raíz en LangSmith que contiene persistencia, pull del prompt,
  llamadas al modelo y herramientas. Prompts: el repo es la fuente de verdad y un script los
  publica al Hub; en prod se leen del Hub (`LANGSMITH_USE_HUB=true`) con respaldo local.
- **Consecuencias**: cualquier respuesta del agente se puede auditar de punta a punta en
  LangSmith; un cambio de prompt en el repo no llega a prod hasta correr `prompts:push`.

## ADR-007. Frontend: Vite, React Router data mode, TanStack Query, Zustand, Zod, Tailwind, Base UI

- **Decisión**: estado del servidor solo en TanStack Query (los loaders del router precargan
  con `ensureQueryData`); Zustand solo para estado de UI; toda respuesta de la API se valida
  con los contratos zod compartidos desde `core/src/contracts`. Componentes de bajo nivel
  sobre Base UI (`@base-ui/react`, sin estilos, accesible) envueltos en `src/components/`.
  Todo componente vive en su carpeta (`Button/Button.tsx`, `Button.test.tsx`, `index.ts` con
  export default) y se importa por la carpeta.
- **Alternativas**: Radix (similar, menos activo), shadcn/ui (copia código con estética
  propia que compite con `DESIGN.md`), componentes desde cero (accesibilidad a mano).
- **Consecuencias**: un solo lugar para cada tipo de estado; los contratos rompen en tests si
  front y back se desalinean; accesibilidad y teclado vienen de Base UI y el estilo es 100 %
  nuestro; imports cortos y sin nombre repetido (`import Button from '@/components/Button'`).

## ADR-009. Cuenta AWS aparte dentro de la organización de woku

- **Contexto**: el usuario IAM de Paula vive en la cuenta de producción de woku. Desplegar con
  CDK ahí equivale a darle administrador de esa cuenta (el rol de ejecución de CloudFormation
  del bootstrap es administrador), y el agente operaría con esas llaves cerca de woku prod.
- **Decisión**: cuenta miembro `chipax-challenge` en la organización de woku, con el rol
  `ChipaxChallengeAdmin` (administrador solo ahí) que Paula asume con su usuario de siempre.
  En la cuenta de woku, el único permiso nuevo de Paula es asumir ese rol.
- **Alternativas**: misma cuenta con política acotada por prefijo (frágil: CloudFront, ACM y
  Budgets no se acotan bien por nombre, y CDK necesita el rol de ejecución); misma cuenta con
  administrador (riesgo inaceptable sobre woku prod).
- **Consecuencias**: aislamiento total, factura consolidada en la organización, alerta de
  presupuesto propia y cierre limpio al terminar (borrar stacks y, si se quiere, cerrar la
  cuenta). Sin llaves nuevas ni SSO.

## ADR-008. TDD y verificación en navegador

- **Decisión**: Vitest en los dos paquetes (supertest en la API, Testing Library + MSW en el
  front, Postgres real en tests de integración). La verificación de punta a punta se hace con
  el MCP de Chrome y queda como evidencia en el vault; los agentes se verifican con su traza
  en LangSmith. Evals con LLM real aparte de la suite (`npm run eval`), porque cuestan dinero.
- **Consecuencias**: la suite es rápida y determinista (modelos falsos en unitarios); la
  calidad del agente se mide aparte.
