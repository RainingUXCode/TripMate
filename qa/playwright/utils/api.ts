import { randomUUID } from 'node:crypto';
import type { APIRequestContext, APIResponse } from '@playwright/test';

export type QaAccount = {
  id: number;
  name: string;
  email: string;
  password: string;
  access: string;
  refresh: string;
};

export function authHeaders(account: QaAccount) {
  return { Authorization: `Bearer ${account.access}` };
}

export async function createAccount(
  request: APIRequestContext,
  name = 'QA Participant',
): Promise<QaAccount> {
  const id = randomUUID();
  const email = `tripmate-qa-${id}@example.test`;
  const password = `Qa-${id}-42!`;
  const registration = await request.post('/api/auth/register/', {
    data: { name, email, password },
  });
  assertStatus(registration, 201, 'cadastro QA');

  const response = await request.post('/api/auth/login/', {
    data: { email, password },
  });
  assertStatus(response, 200, 'login QA');
  const body = await response.json();
  return {
    id: body.user.id,
    name: body.user.name,
    email,
    password,
    access: body.access,
    refresh: body.refresh,
  };
}

export async function createFriendship(
  request: APIRequestContext,
  sender: QaAccount,
  recipient: QaAccount,
) {
  const sent = await request.post('/api/friends/requests/send/', {
    headers: authHeaders(sender),
    data: { receiver_id: recipient.id },
  });
  assertStatus(sent, 201, 'envio de solicitação de amizade');
  const requestBody = await sent.json();
  const friendshipId = requestBody.friendship.id as number;

  const accepted = await request.post(
    `/api/friends/requests/${friendshipId}/accept/`,
    { headers: authHeaders(recipient), data: {} },
  );
  assertStatus(accepted, 200, 'aceitação de amizade');
  return friendshipId;
}

export async function createTrip(
  request: APIRequestContext,
  organizer: QaAccount,
  extra: Record<string, unknown> = {},
) {
  const response = await request.post('/api/trips/', {
    headers: authHeaders(organizer),
    data: {
      name: 'QA Trip',
      destination: 'QA Destination',
      start_date: '2027-06-10',
      end_date: '2027-06-15',
      description: 'Automated isolated QA data',
      ...extra,
    },
  });
  assertStatus(response, 201, 'criação de viagem QA');
  return response.json();
}

export async function assertStatus(
  response: APIResponse,
  expected: number,
  operation: string,
) {
  if (response.status() !== expected) {
    throw new Error(
      `${operation}: esperado HTTP ${expected}, obtido ${response.status()}: ${await response.text()}`,
    );
  }
}
