import { expect, test } from '@playwright/test';
import {
  authHeaders,
  createAccount,
  createFriendship,
  createTrip,
} from '../utils/api';

test('organizador remove participante aceito e terceiro não altera viagem', async ({ request }) => {
  const organizer = await createAccount(request, 'QA Organizer');
  const member = await createAccount(request, 'QA Member');
  const outsider = await createAccount(request, 'QA Outsider');
  await createFriendship(request, organizer, member);
  const trip = await createTrip(request, organizer, { invitee_ids: [member.id] });
  expect((await request.post(`/api/trips/${trip.id}/invitation/accept/`, {
    headers: authHeaders(member), data: {},
  })).status()).toBe(200);

  const forbidden = await request.delete(`/api/trips/${trip.id}/members/${member.id}/`, {
    headers: authHeaders(outsider),
  });
  expect(forbidden.status()).toBe(404);

  const removed = await request.delete(`/api/trips/${trip.id}/members/${member.id}/`, {
    headers: authHeaders(organizer),
  });
  expect(removed.status()).toBe(200);
  expect(await removed.json()).toMatchObject({
    trip_id: trip.id,
    user_id: member.id,
    status: 'left',
  });

  const detail = await request.get(`/api/trips/${trip.id}/`, {
    headers: authHeaders(organizer),
  });
  const body = await detail.json();
  expect(body.accepted_participants_count).toBe(1);
  expect(body.accepted_participants.map((person: { id: number }) => person.id)).not.toContain(member.id);
  expect((await request.get(`/api/trips/${trip.id}/`, {
    headers: authHeaders(member),
  })).status()).toBe(404);
});

test('transferência preserva o acesso e permite a saída posterior do antigo organizador', async ({ request }) => {
  const formerOrganizer = await createAccount(request, 'QA Former Organizer');
  const successor = await createAccount(request, 'QA Successor');
  await createFriendship(request, formerOrganizer, successor);
  const trip = await createTrip(request, formerOrganizer, {
    invitee_ids: [successor.id],
  });
  await request.post(`/api/trips/${trip.id}/invitation/accept/`, {
    headers: authHeaders(successor), data: {},
  });

  const forbiddenTransfer = await request.post(`/api/trips/${trip.id}/transfer-organizer/`, {
    headers: authHeaders(successor),
    data: { new_organizer_id: formerOrganizer.id },
  });
  expect(forbiddenTransfer.status()).toBe(403);

  const transfer = await request.post(`/api/trips/${trip.id}/transfer-organizer/`, {
    headers: authHeaders(formerOrganizer),
    data: { new_organizer_id: successor.id },
  });
  expect(transfer.status()).toBe(200);
  expect((await transfer.json()).created_by).toBe(successor.id);

  const eligibility = await request.get(`/api/trips/${trip.id}/leave-eligibility/`, {
    headers: authHeaders(formerOrganizer),
  });
  expect((await eligibility.json()).can_leave).toBe(true);
  const leave = await request.post(`/api/trips/${trip.id}/leave/`, {
    headers: authHeaders(formerOrganizer), data: {},
  });
  expect(leave.status()).toBe(200);
  expect((await leave.json()).status).toBe('left');

  expect((await request.get(`/api/trips/${trip.id}/`, {
    headers: authHeaders(formerOrganizer),
  })).status()).toBe(404);
  expect((await request.get(`/api/trips/${trip.id}/`, {
    headers: authHeaders(successor),
  })).status()).toBe(200);
});
