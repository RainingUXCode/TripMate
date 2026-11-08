import { expect, test } from '@playwright/test';
import { authHeaders, createAccount } from '../utils/api';

test('login, refresh, credenciais inválidas e proteção JWT', async ({ request }) => {
  const account = await createAccount(request, 'QA Auth');

  const me = await request.get('/api/auth/me/', {
    headers: authHeaders(account),
  });
  expect(me.status()).toBe(200);
  expect(await me.json()).toMatchObject({ id: account.id, email: account.email });

  const wrongPassword = await request.post('/api/auth/login/', {
    data: { email: account.email, password: 'incorrect-password' },
  });
  expect(wrongPassword.status()).toBe(400);
  expect(await wrongPassword.text()).toContain('E-mail ou senha inválidos.');

  expect((await request.get('/api/auth/me/')).status()).toBe(401);
  expect((await request.get('/api/auth/me/', {
    headers: { Authorization: 'Bearer invalid-token' },
  })).status()).toBe(401);

  const refresh = await request.post('/api/auth/token/refresh/', {
    data: { refresh: account.refresh },
  });
  expect(refresh.status()).toBe(200);
  const refreshed = await refresh.json();
  expect(typeof refreshed.access).toBe('string');
  expect((await request.get('/api/auth/me/', {
    headers: { Authorization: `Bearer ${refreshed.access}` },
  })).status()).toBe(200);

  const invalidRefresh = await request.post('/api/auth/token/refresh/', {
    data: { refresh: 'invalid-refresh' },
  });
  expect(invalidRefresh.status()).toBe(401);
});
