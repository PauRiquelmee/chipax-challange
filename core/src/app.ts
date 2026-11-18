import express from 'express';
import { healthRoutes } from './modules/health/health.routes.js';

export function createApp() {
  const app = express();
  app.use(express.json());
  app.use('/api', healthRoutes);
  return app;
}
