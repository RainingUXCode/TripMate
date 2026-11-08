import { expect, test } from '@playwright/test';
import { authHeaders, createAccount, createTrip } from '../utils/api';

test('viagem é consultável pelo organizador e protegida contra terceiros', async ({ request }) => {
  const organizer = await createAccount(request, 'QA Organizer');
  const outsider = await createAccount(request, 'QA Outsider');
  const trip = await createTrip(request, organizer);

  const detail = await request.get(`/api/trips/${trip.id}/`, {
    headers: authHeaders(organizer),
  });
  expect(detail.status()).toBe(200);
  expect(await detail.json()).toMatchObject({
    id: trip.id,
    name: 'QA Trip',
    destination: 'QA Destination',
    created_by: organizer.id,
    accepted_participants_count: 1,
  });

  const ownerTrips = await request.get('/api/trips/', {
    headers: authHeaders(organizer),
  });
  expect((await ownerTrips.json()).map((row: { id: number }) => row.id)).toContain(trip.id);

  expect((await request.get(`/api/trips/${trip.id}/`, {
    headers: authHeaders(outsider),
  })).status()).toBe(404);
  expect((await request.patch(`/api/trips/${trip.id}/`, {
    headers: authHeaders(outsider),
    data: { name: 'Unauthorized change' },
  })).status()).toBe(404);
  const outsiderTrips = await request.get('/api/trips/', {
    headers: authHeaders(outsider),
  });
  expect((await outsiderTrips.json()).some((row: { id: number }) => row.id === trip.id)).toBe(false);
});

test('organizador edita e pode excluir viagem sem histórico protegido', async ({ request }) => {
  const organizer = await createAccount(request, 'QA Organizer');
  const trip = await createTrip(request, organizer);
  expect(trip.can_delete).toBe(true);

  const updated = await request.patch(`/api/trips/${trip.id}/`, {
    headers: authHeaders(organizer),
    data: { name: 'QA Trip Renamed' },
  });
  expect(updated.status()).toBe(200);
  expect((await updated.json()).name).toBe('QA Trip Renamed');

  const deleted = await request.delete(`/api/trips/${trip.id}/`, {
    headers: authHeaders(organizer),
  });
  expect(deleted.status()).toBe(204);
  expect((await request.get(`/api/trips/${trip.id}/`, {
    headers: authHeaders(organizer),
  })).status()).toBe(404);
});
