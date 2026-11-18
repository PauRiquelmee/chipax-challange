/// <reference types="vitest/config" />
import { fileURLToPath } from 'node:url';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

const target = process.env.VITE_API_PROXY_TARGET ?? 'http://localhost:3000';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
      '@contracts': fileURLToPath(new URL('../core/src/contracts', import.meta.url)),
    },
  },
  server: { proxy: { '/api': target } },
  preview: { proxy: { '/api': target } },
  test: { environment: 'jsdom', globals: true, setupFiles: ['./src/setup-tests.ts'] },
});
