import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import HealthStatus from '@/features/health/routes/HealthStatus';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <main style={{ fontFamily: 'system-ui', padding: '2rem' }}>
      <h1>Chipax challenge</h1>
      <HealthStatus />
    </main>
  </StrictMode>,
);
