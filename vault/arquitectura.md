# Arquitectura

Base común a cualquier desafío. El diagnóstico agrega lo propio (entidades, agentes, flujos).

## En prod

```
                         challenge.woku.uk  (Cloudflare DNS, solo DNS, sin proxy)
                                   |
                                   v
                        CloudFront (certificado ACM us-east-1)
                   /                                         \
     comportamiento por defecto                           /api/*
     S3 privado (console/dist, OAC)          Lambda Function URL (Node 24, Express)
     CloudFront Function: rutas SPA          exige X-Origin-Verify
                                                   |        |          |            |
                                                   v        v          v            v
                                            RDS Postgres   S3      Claude API   LangSmith
                                            (TLS, DML)  (uploads)  (Anthropic)  (trazas + Hub)
                                                   ^
                                       SSM Parameter Store /chipax-challenge/prod/*
                                       (secretos, leídos en el arranque en frío)
```

## Cómo viaja un request

1. El navegador pide `https://challenge.woku.uk/facturas/123`. La CloudFront Function
   reescribe a `/index.html`; S3 entrega el SPA.
2. El loader de React Router llama `queryClient.ensureQueryData(...)`, que hace
   `GET /api/facturas/123` al mismo origen.
3. CloudFront reenvía `/api/*` a la Function URL agregando `X-Origin-Verify`.
4. La Lambda (contenedor tibio o arranque en frío: carga secretos de SSM, valida el entorno
   con zod, abre el pool) pasa el request a Express: middleware de verificación de origen,
   routes con `validate` (zod sobre body, params y query), controller, service, repository.
5. El controller pasa el resultado por el esquema de respuesta del contrato y responde JSON;
   el front lo valida con el mismo contrato antes de usarlo.

## Subida de archivos

1. `POST /api/files/upload-url` con nombre, tipo y tamaño; la API valida y responde una URL
   prefirmada de `PUT` para `uploads/<uuid>-<nombre>`.
2. El navegador sube directo a S3.
3. `POST /api/files` confirma; la API verifica que el objeto exista (`HeadObject`) y guarda
   el registro.

## Turno de un agente

Todo dentro de una traza raíz en LangSmith (`core/docs/agentes.md`):
guardar mensaje del usuario, leer historial, pull del prompt del Hub, bucle ReAct (Claude +
herramientas), guardar respuesta, devolver. Antes de que la Lambda responda se vacían las
trazas pendientes.

## Local

| Pieza | Local | Prod |
|---|---|---|
| Front | Vite `:5173`, proxy `/api` a `:3000` | S3 + CloudFront |
| API | `tsx watch` `:3000` | Lambda + Function URL |
| Base | Postgres 18 en Docker (`challenge` y `challenge_test`) | RDS Postgres 18 |
| Archivos | MinIO en Docker (`:9000`, consola `:9001`) | S3 |
| LLM y trazas | Claude y LangSmith reales (proyecto `-local`) | Claude y LangSmith (proyecto `-prod`) |
| Secretos | `core/.env` | SSM Parameter Store |
