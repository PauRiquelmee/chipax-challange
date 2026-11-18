import type { Request, Response } from 'express';
import { healthResponseSchema } from '../../contracts/health.contract.js';

export function getHealth(_req: Request, res: Response) {
  res.json(healthResponseSchema.parse({ status: 'ok' }));
}
