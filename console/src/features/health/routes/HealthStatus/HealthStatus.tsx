import { useEffect, useState } from 'react';
import { healthResponseSchema } from '@contracts/health.contract';
import { apiFetch } from '@/lib/api';

export default function HealthStatus() {
  const [status, setStatus] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    apiFetch('/health', healthResponseSchema)
      .then((r) => setStatus(r.status))
      .catch(() => setFailed(true));
  }, []);

  if (failed) return <p role="alert">No se pudo consultar la API.</p>;
  return <p>{status ? `API: ${status}` : 'Consultando la API...'}</p>;
}
