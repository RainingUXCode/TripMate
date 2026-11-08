import { expect, test } from '@playwright/test';
import {
  authHeaders,
  createAccount,
  createFriendship,
  createTrip,
} from '../utils/api';

const cents = (value: string) => {
  const [whole, fraction = '00'] = value.split('.');
  return Number(whole) * 100 + Number(fraction.padEnd(2, '0'));
};

test('quatro modalidades persistem parcelas monetárias calculadas pelo backend', async ({ request }) => {
  const organizer = await createAccount(request, 'QA Organizer');
  const member = await createAccount(request, 'QA Member');
  await createFriendship(request, organizer, member);
  const trip = await createTrip(request, organizer, { invitee_ids: [member.id] });
  const accepted = await request.post(`/api/trips/${trip.id}/invitation/accept/`, {
    headers: authHeaders(member), data: {},
  });
  expect(accepted.status()).toBe(200);

  const cases = [
    { mode: 'equal', shares: [{ user_id: organizer.id }, { user_id: member.id }] },
    { mode: 'exact', shares: [{ user_id: organizer.id, value: '6.00' }, { user_id: member.id, value: '4.00' }] },
    { mode: 'percent', shares: [{ user_id: organizer.id, value: '60' }, { user_id: member.id, value: '40' }] },
    { mode: 'units', shares: [{ user_id: organizer.id, value: '3' }, { user_id: member.id, value: '2' }] },
  ];

  for (const [index, split] of cases.entries()) {
    const response = await request.post(`/api/trips/${trip.id}/finance/expenses/`, {
      headers: authHeaders(organizer),
      data: {
        description: `QA expense ${split.mode}`,
        amount: '10.00',
        expense_date: '2027-06-11',
        paid_by: organizer.id,
        ...split,
      },
    });
    expect(response.status()).toBe(201);
    const expense = await response.json();
    expect(expense.amount).toBe('10.00');
    expect(expense.version).toBe(1);
    expect(expense.cancelled).toBe(false);
    expect(expense.shares.reduce((total: number, share: { amount: string }) => total + cents(share.amount), 0)).toBe(1000);
    expect(expense.mode).toBe(cases[index].mode);
  }

  const rejectedFloat = await request.post(`/api/trips/${trip.id}/finance/expenses/`, {
    headers: authHeaders(organizer),
    data: {
      description: 'Invalid float', amount: 1.5, expense_date: '2027-06-11',
      paid_by: organizer.id, mode: 'equal', shares: [{ user_id: organizer.id }],
    },
  });
  expect(rejectedFloat.status()).toBe(400);
});

test('edição exige autoria e versão, cancelamento preserva registro histórico', async ({ request }) => {
  const organizer = await createAccount(request, 'QA Organizer');
  const member = await createAccount(request, 'QA Member');
  await createFriendship(request, organizer, member);
  const trip = await createTrip(request, organizer, { invitee_ids: [member.id] });
  await request.post(`/api/trips/${trip.id}/invitation/accept/`, {
    headers: authHeaders(member), data: {},
  });
  const expenseResponse = await request.post(`/api/trips/${trip.id}/finance/expenses/`, {
    headers: authHeaders(organizer),
    data: {
      description: 'Versioned expense', amount: '10.00', expense_date: '2027-06-11',
      paid_by: organizer.id, mode: 'equal', shares: [{ user_id: member.id }],
    },
  });
  expect(expenseResponse.status()).toBe(201);
  const expense = await expenseResponse.json();
  const path = `/api/trips/${trip.id}/finance/expenses/${expense.id}/`;
  const body = {
    description: 'Updated expense', amount: '10.00', expense_date: '2027-06-11',
    paid_by: organizer.id, mode: 'equal', shares: [{ user_id: member.id }], version: 1,
  };

  expect((await request.put(path, { headers: authHeaders(organizer), data: { ...body, version: undefined } })).status()).toBe(400);
  expect((await request.put(path, { headers: authHeaders(organizer), data: body })).status()).toBe(200);
  expect((await request.put(path, { headers: authHeaders(organizer), data: body })).status()).toBe(409);
  expect((await request.put(path, { headers: authHeaders(member), data: { ...body, version: 2 } })).status()).toBe(403);

  const cancelled = await request.delete(path, {
    headers: authHeaders(organizer), data: { version: 2 },
  });
  expect(cancelled.status()).toBe(200);
  expect((await cancelled.json()).cancelled).toBe(true);
  const list = await request.get(`/api/trips/${trip.id}/finance/expenses/`, {
    headers: authHeaders(organizer),
  });
  expect((await list.json()).some((row: { id: number; cancelled: boolean }) => row.id === expense.id && row.cancelled)).toBe(true);
});
