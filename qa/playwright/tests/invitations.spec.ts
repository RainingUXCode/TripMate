import { expect, test } from '@playwright/test';
import {
  authHeaders,
  createAccount,
  createFriendship,
  createTrip,
} from '../utils/api';

test('convite permanece pendente, é privado e só passa a acesso após aceite', async ({ request }) => {
  const organizer = await createAccount(request, 'QA Organizer');
  const invited = await createAccount(request, 'QA Invitee');
  const outsider = await createAccount(request, 'QA Outsider');
  await createFriendship(request, organizer, invited);
  const trip = await createTrip(request, organizer, { invitee_ids: [invited.id] });

  expect(trip.accepted_participants_count).toBe(1);
  expect(trip.pending_invites.map((row: { id: number }) => row.id)).toContain(invited.id);
  expect((await request.get('/api/trips/invitations/', {
    headers: authHeaders(invited),
  })).status()).toBe(200);
  expect((await request.get(`/api/trips/${trip.id}/`, {
    headers: authHeaders(invited),
  })).status()).toBe(404);
  expect((await request.post(`/api/trips/${trip.id}/invitation/accept/`, {
    headers: authHeaders(outsider),
    data: {},
  })).status()).toBe(404);

  const accepted = await request.post(`/api/trips/${trip.id}/invitation/accept/`, {
    headers: authHeaders(invited),
    data: {},
  });
  expect(accepted.status()).toBe(200);
  expect((await accepted.json()).accepted_participants_count).toBe(2);

  const privateDetail = await request.get(`/api/trips/${trip.id}/`, {
    headers: authHeaders(invited),
  });
  expect(privateDetail.status()).toBe(200);
  expect((await privateDetail.json()).accepted_participants.map((row: { id: number }) => row.id)).toContain(invited.id);

  const duplicate = await request.post(`/api/trips/${trip.id}/invitations/`, {
    headers: authHeaders(organizer),
    data: { user_ids: [invited.id] },
  });
  expect([400, 409]).toContain(duplicate.status());
});

test('convite é restrito ao organizador e apenas amigos podem ser convidados', async ({ request }) => {
  const organizer = await createAccount(request, 'QA Organizer');
  const member = await createAccount(request, 'QA Member');
  const outsider = await createAccount(request, 'QA Outsider');
  await createFriendship(request, organizer, member);
  const trip = await createTrip(request, organizer, { invitee_ids: [member.id] });

  const nonOrganizer = await request.post(`/api/trips/${trip.id}/invitations/`, {
    headers: authHeaders(member),
    data: { user_ids: [outsider.id] },
  });
  // The authorization queryset intentionally returns 404 for private trips.
  expect(nonOrganizer.status()).toBe(404);

  const nonFriend = await request.post(`/api/trips/${trip.id}/invitations/`, {
    headers: authHeaders(organizer),
    data: { user_ids: [outsider.id] },
  });
  expect(nonFriend.status()).toBe(400);
});
