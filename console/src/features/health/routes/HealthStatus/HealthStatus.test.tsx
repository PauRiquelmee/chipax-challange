import { render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import HealthStatus from './HealthStatus';

afterEach(() => vi.unstubAllGlobals());

describe('HealthStatus', () => {
  it('shows the API status', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(Response.json({ status: 'ok' })));
    render(<HealthStatus />);
    expect(await screen.findByText(/API: ok/i)).toBeInTheDocument();
  });

  it('shows an error when the API fails', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('boom', { status: 500 })));
    render(<HealthStatus />);
    expect(await screen.findByRole('alert')).toHaveTextContent(/API/i);
  });
});
