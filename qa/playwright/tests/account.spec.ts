import { expect, test } from '@playwright/test';
import { authHeaders, createAccount } from '../utils/api';

const validPng = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNI9rkCAAKZAYSOSefDAAAAAElFTkSuQmCC',
  'base64',
);

test('perfil atualiza nome, exige senha ao trocar email e isola contas', async ({ request }) => {
  const account = await createAccount(request, 'QA Profile');
  const other = await createAccount(request, 'QA Other Profile');

  const nameUpdate = await request.patch('/api/auth/me/', {
    headers: authHeaders(account),
    data: { name: '  QA Updated Profile  ' },
  });
  expect(nameUpdate.status()).toBe(200);
  expect((await nameUpdate.json()).user.name).toBe('QA Updated Profile');

  const missingPassword = await request.patch('/api/auth/me/', {
    headers: authHeaders(account),
    data: { email: 'updated-profile@example.test' },
  });
  expect(missingPassword.status()).toBe(400);
  expect(await missingPassword.text()).toContain('current_password');

  const emailUpdate = await request.patch('/api/auth/me/', {
    headers: authHeaders(account),
    data: { email: '  UPDATED-PROFILE@EXAMPLE.TEST ', current_password: account.password },
  });
  expect(emailUpdate.status()).toBe(200);
  expect((await emailUpdate.json()).user.email).toBe('updated-profile@example.test');

  const ownProfile = await request.get('/api/auth/me/', { headers: authHeaders(account) });
  const otherProfile = await request.get('/api/auth/me/', { headers: authHeaders(other) });
  expect((await ownProfile.json()).id).toBe(account.id);
  expect((await otherProfile.json()).id).toBe(other.id);
  expect((await otherProfile.json()).email).toBe(other.email);
});

test('avatar aceita imagem válida, rejeita arquivo falso e permite remoção', async ({ request }) => {
  const account = await createAccount(request, 'QA Avatar');
  const headers = authHeaders(account);

  const upload = await request.patch('/api/auth/me/avatar/', {
    headers,
    multipart: { avatar: { name: 'qa-avatar.png', mimeType: 'image/png', buffer: validPng } },
  });
  expect(upload.status(), await upload.text()).toBe(200);
  expect((await upload.json()).user.avatar_url).toContain('/media/avatars/user_');

  const invalid = await request.patch('/api/auth/me/avatar/', {
    headers,
    multipart: { avatar: { name: 'fake.png', mimeType: 'image/png', buffer: Buffer.from('not an image') } },
  });
  expect(invalid.status()).toBe(400);

  const removed = await request.delete('/api/auth/me/avatar/', { headers });
  expect(removed.status()).toBe(200);
  expect((await removed.json()).user.avatar_url).toBeNull();
  expect((await request.delete('/api/auth/me/avatar/', { headers })).status()).toBe(200);
});
