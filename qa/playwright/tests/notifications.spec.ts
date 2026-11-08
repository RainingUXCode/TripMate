import { expect, test } from '@playwright/test';
import {
  authHeaders,
  createAccount,
} from '../utils/api';

test('notificações são isoladas por usuário e leitura atualiza contador', async ({ request }) => {
  const sender = await createAccount(request, 'QA Sender');
  const recipient = await createAccount(request, 'QA Recipient');
  const unrelated = await createAccount(request, 'QA Unrelated');
  const sent = await request.post('/api/friends/requests/send/', {
    headers: authHeaders(sender),
    data: { receiver_id: recipient.id },
  });
  expect(sent.status()).toBe(201);

  const unread = await request.get('/api/notifications/unread-count/', {
    headers: authHeaders(recipient),
  });
  expect((await unread.json()).unread_count).toBe(1);
  const list = await request.get('/api/notifications/', {
    headers: authHeaders(recipient),
  });
  const result = await list.json();
  expect(result.count).toBe(1);
  expect(result.results[0]).toMatchObject({
    event_type: 'friend_request',
    resource_type: 'friendship',
    is_read: false,
  });

  const unrelatedList = await request.get('/api/notifications/', {
    headers: authHeaders(unrelated),
  });
  expect((await unrelatedList.json()).count).toBe(0);

  const id = result.results[0].id as number;
  const read = await request.post(`/api/notifications/${id}/read/`, {
    headers: authHeaders(recipient), data: {},
  });
  expect((await read.json()).is_read).toBe(true);
  const countAfterRead = await request.get('/api/notifications/unread-count/', {
    headers: authHeaders(recipient),
  });
  expect((await countAfterRead.json()).unread_count).toBe(0);
});
