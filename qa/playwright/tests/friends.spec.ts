import { expect, test } from '@playwright/test';
import { authHeaders, createAccount } from '../utils/api';

test('solicitação pendente só é aceita pelo destinatário', async ({ request }) => {
  const sender = await createAccount(request, 'QA Sender');
  const receiver = await createAccount(request, 'QA Receiver');
  const thirdParty = await createAccount(request, 'QA Third Party');

  const sent = await request.post('/api/friends/requests/send/', {
    headers: authHeaders(sender),
    data: { receiver_id: receiver.id },
  });
  expect(sent.status()).toBe(201);
  const friendshipId = (await sent.json()).friendship.id as number;

  const senderRequests = await request.get('/api/friends/requests/', {
    headers: authHeaders(sender),
  });
  const receiverRequests = await request.get('/api/friends/requests/', {
    headers: authHeaders(receiver),
  });
  expect((await senderRequests.json()).sent).toHaveLength(1);
  expect((await receiverRequests.json()).received).toHaveLength(1);

  const forbiddenAccept = await request.post(
    `/api/friends/requests/${friendshipId}/accept/`,
    { headers: authHeaders(thirdParty), data: {} },
  );
  expect(forbiddenAccept.status()).toBe(404);

  const accepted = await request.post(
    `/api/friends/requests/${friendshipId}/accept/`,
    { headers: authHeaders(receiver), data: {} },
  );
  expect(accepted.status()).toBe(200);
  expect((await accepted.json()).friendship.status).toBe('accepted');

  for (const [account, expectedId] of [[sender, receiver.id], [receiver, sender.id]] as const) {
    const friends = await request.get('/api/friends/', {
      headers: authHeaders(account),
    });
    const rows = await friends.json();
    expect(rows.count).toBe(1);
    const friendship = rows.results[0];
    const friend = friendship.sender.id === account.id
      ? friendship.receiver
      : friendship.sender;
    expect(friend.id).toBe(expectedId);
    expect(friend).not.toHaveProperty('email');
    expect(JSON.stringify(rows)).not.toContain('email');
  }

  const duplicate = await request.post('/api/friends/requests/send/', {
    headers: authHeaders(sender),
    data: { receiver_id: receiver.id },
  });
  expect(duplicate.status()).toBe(409);
});
