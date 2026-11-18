# Agentes: LangGraph + Claude + LangSmith

Patrón tomado de los agentes de woku (Data Studio y WhatsApp en `woku-server`) y ajustado a
Lambda. Objetivo: **cada turno es una sola traza en LangSmith**, desde que llega el input
hasta que sale el output, con todo lo que pasó adentro como hijos de esa traza.

> El código de abajo es la referencia del patrón. Al implementarlo, verificar imports y
> firmas contra las versiones instaladas (`langchain`, `@langchain/langgraph`,
> `@langchain/anthropic`, `langsmith`) y escribirlo con TDD como todo lo demás.

## Cómo se ve una traza bien hecha

```
assistant_turn                       chain     <- traza raíz (traceable), metadata thread_id
├─ save_user_message                 tool      <- escritura en Postgres (traced)
├─ load_history                      retriever <- lectura del historial (traced)
├─ pull_prompt                       chain     <- Hub de LangSmith o respaldo local (traced)
├─ assistant (LangGraph)             chain     <- agente ReAct, se cuelga solo por contexto
│  ├─ model                          llm       <- ChatAnthropic: prompt, tokens, costo
│  ├─ tools
│  │  └─ search_invoices             tool      <- herramienta
│  │     └─ invoices.search          retriever <- IO real dentro de la herramienta (traced)
│  └─ model                          llm
└─ save_assistant_message            tool
```

Si en LangSmith aparecen trazas sueltas (el agente por un lado y la escritura en la base por
otro), algo se ejecutó fuera de la función raíz: corregir antes de seguir.

## Piezas

### 1. Modelo (`shared/llm/models.ts`)

```ts
import { ChatAnthropic } from '@langchain/anthropic';

export function createChatModel(env: Env, tier: 'main' | 'fast' = 'main') {
  return new ChatAnthropic({
    model: tier === 'main' ? env.LLM_MODEL : env.LLM_MODEL_FAST, // claude-opus-5-5 / claude-haiku-5-5
    apiKey: env.ANTHROPIC_API_KEY,
    maxTokens: 16_000,
    // Opus 5.5: thinking adaptativo siempre activo; la profundidad se controla con effort.
    // Sin temperature/topP/topK (400). Confirmar cómo la versión instalada expone effort.
    invocationKwargs: { output_config: { effort: env.LLM_EFFORT } },
    maxRetries: 2,
  });
}
```

### 2. Prompt registrado en el repo (`agents/<agent>/prompts/<name>.prompt.ts`)

```ts
export const ASSISTANT_PROMPT = {
  hubName: 'chipax-challenge-assistant',     // `${LANGSMITH_PROMPT_PREFIX}-<agente>`
  description: 'Assistant for ...',
  template: `You are ... (mustache: {{companyName}}, {{today}})`,
} as const;
```

Todos los prompts se listan en `src/agents/prompt-registry.ts`; `scripts/push-prompts.ts` los
publica:

```ts
import { Client } from 'langsmith';
import { ChatPromptTemplate } from '@langchain/core/prompts';

for (const p of PROMPTS) {
  const object = ChatPromptTemplate.fromMessages([['system', p.template]], { templateFormat: 'mustache' });
  try {
    await client.pushPrompt(p.hubName, { object, description: p.description, isPublic: false, tags: ['chipax-challenge'] });
  } catch (e) {
    if ((e as { status?: number }).status === 409) continue; // sin cambios
    throw e;
  }
}
```

### 3. Pull con respaldo (`shared/prompts/hub.ts`)

```ts
export const pullPrompt = traced(async (p: RegisteredPrompt, vars: Record<string, string>) => {
  if (env.LANGSMITH_USE_HUB) {
    try {
      const tpl = await hub.pull<ChatPromptTemplate>(p.hubName);   // langchain/hub
      const [system] = await tpl.formatMessages(vars);
      return String(system.content);
    } catch (error) {
      logger.warn({ error, prompt: p.hubName }, 'hub pull failed, using local template');
    }
  }
  return renderMustache(p.template, vars);
}, 'pull_prompt', 'chain');
```

Cachear el template del Hub en memoria del contenedor por unos minutos para no pagar la
latencia en cada turno.

### 4. Envoltorio de trazas (`shared/tracing/traced.ts`), igual que `traced-wrappers.ts` de woku

```ts
import { traceable } from 'langsmith/traceable';

export function traced<T extends (...args: any[]) => any>(
  fn: T, name: string, runType: 'tool' | 'retriever' | 'chain' | 'llm' = 'tool',
): T {
  return traceable(fn, { name, run_type: runType }) as T;
}
```

Se usa en repositorios y servicios que el agente toca (`invoices.search`, `save_user_message`)
para que el IO aparezca como hijo dentro de la traza.

### 5. Herramientas (`agents/<agent>/tools/*.tool.ts`)

```ts
import { tool } from '@langchain/core/tools';
import { z } from 'zod';

export const searchInvoicesTool = (deps: { invoices: InvoiceService }) =>
  tool(
    async ({ query, limit }) => JSON.stringify(await deps.invoices.search({ query, limit })),
    {
      name: 'search_invoices',
      description: 'Search the user invoices by text. Use it before answering about specific invoices.',
      schema: z.object({ query: z.string().min(1), limit: z.number().int().max(50).default(10) }),
    },
  );
```

La lógica vive en el service (testeado aparte); la herramienta solo adapta. Descripciones en
inglés, concretas, diciendo cuándo usarla.

### 6. El turno completo (`agents/<agent>/<agent>.agent.ts`)

```ts
import { traceable } from 'langsmith/traceable';
import { createAgent } from 'langchain'; // ReAct sobre LangGraph (equivale a createReactAgent de @langchain/langgraph/prebuilt)

export function createAssistant(deps: AssistantDeps) {
  async function turn(input: { conversationId: string; userId: string; message: string }) {
    await deps.messages.saveUser(input);                                  // traced
    const history = await deps.messages.lastN(input.conversationId, 10);  // traced
    const systemPrompt = await pullPrompt(ASSISTANT_PROMPT, { today: deps.today() });

    const agent = createAgent({
      model: deps.model,
      tools: [searchInvoicesTool(deps)],
      systemPrompt,
      name: 'assistant',
    });
    const result = await agent.invoke(
      { messages: [...history, { role: 'user', content: input.message }] },
      { recursionLimit: 25 },
    );
    const answer = lastText(result.messages);
    await deps.messages.saveAssistant({ ...input, content: answer, usage: sumUsage(result.messages) }); // traced
    return { answer };
  }

  // Una traza raíz por turno. thread_id agrupa los turnos en la vista Threads de LangSmith.
  return (input: Parameters<typeof turn>[0]) =>
    traceable(turn, {
      name: 'assistant_turn',
      run_type: 'chain',
      client: deps.langsmith,
      project_name: deps.env.LANGSMITH_PROJECT,
      metadata: { thread_id: input.conversationId, user_id: input.userId },
      tags: ['assistant', deps.env.APP_ENV],
    })(input);
}
```

Claves:

- Todo lo que ocurre en el turno se llama **dentro** de `turn`. LangChain y LangGraph toman el
  contexto de la traza raíz por `AsyncLocalStorage` y se cuelgan solos.
- **Historial en nuestra tabla `messages`**, no en un checkpointer: se pasan los últimos N
  mensajes por turno (como Data Studio). Si el desafío necesita estado de grafo persistente,
  evaluar `@langchain/langgraph-checkpoint-postgres` con la misma base y anotarlo en
  `decisiones.md`.
- Presupuesto: tokens acumulados por conversación en la tabla; si se supera, respuesta fija
  sin llamar al modelo.

### 7. Vaciar trazas antes de responder (`shared/tracing/flush.ts`)

```ts
import { awaitAllCallbacks } from '@langchain/core/callbacks/promises';

export async function flushTraces(client: Client) {
  await Promise.allSettled([client.awaitPendingTraceBatches(), awaitAllCallbacks()]);
}
```

El agente se expone como cualquier módulo: el controller llama al service del agente
(`assistantService.reply(input)`), y es el service el que ejecuta el turno y vacía las trazas
en un `finally` (`try { return await assistant(input); } finally { await flushTraces(deps.langsmith); }`).
Así el controller sigue sin lógica y el vaciado no se olvida en ningún endpoint. Sin esto, en
Lambda las trazas llegan incompletas o no llegan. La respuesta final del agente se valida con
zod antes de devolverla.

## Turnos largos: corrida asíncrona

CloudFront corta el origen a los 60 s. Si un turno puede tardar más de ~45 s:

1. `POST /api/<agent>/runs` crea una fila `agent_runs` (`queued`) y responde `202 { runId }`.
2. El despachador ejecuta el turno fuera del request: en prod invoca la misma Lambda en modo
   asíncrono (`InvocationType: 'Event'`, payload `{ kind: 'agent-run', runId }`); en local lo
   corre en el mismo proceso sin esperar. Es una interfaz `RunDispatcher` inyectada.
3. El worker ejecuta `assistant(...)` (misma traza raíz), guarda resultado y estado.
4. El front consulta `GET /api/<agent>/runs/:id` con `refetchInterval` de TanStack Query
   hasta `done` o `failed`.

## Verificación de un agente

- Unitario con modelo falso: herramientas llamadas, persistencia, presupuesto, errores.
- Manual en local: un turno real y revisar la traza con el MCP de LangSmith (o la UI): árbol
  completo, tokens, sin trazas huérfanas. La URL de la traza va a `vault/evidencia/pruebas.md`.
- Evals (`evals/`): casos del dominio con criterio de corrección explícito, corridos con
  `npm run eval` contra el proyecto `LANGSMITH_PROJECT-evals`. Se corren al cambiar prompt o
  modelo, y el resultado se anota en la bitácora.
