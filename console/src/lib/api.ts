import type { ZodType } from 'zod';

export class ApiError extends Error {
  constructor(public status: number) {
    super(`API error ${status}`);
  }
}

export async function apiFetch<T>(path: string, schema: ZodType<T>): Promise<T> {
  const res = await fetch(`/api${path}`);
  if (!res.ok) throw new ApiError(res.status);
  return schema.parse(await res.json());
}
