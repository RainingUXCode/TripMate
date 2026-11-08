import { randomUUID } from 'node:crypto';
import { expect, test } from '@playwright/test';
import {
  authHeaders,
  createAccount,
  createFriendship,
  createTrip,
} from '../utils/api';

test('pagamento pendente só é confirmado pela contraparte e atualiza saldos', async ({ request }) => {
  const creditor = await createAccount(request, 'QA Creditor');
  const debtor = await createAccount(request, 'QA Debtor');
  await createFriendship(request, creditor, debtor);
  const trip = await createTrip(request, creditor, { invitee_ids: [debtor.id] });
  await request.post(`/api/trips/${trip.id}/invitation/accept/`, {
    headers: authHeaders(debtor), data: {},
  });

  const expense = await request.post(`/api/trips/${trip.id}/finance/expenses/`, {
    headers: authHeaders(creditor),
    data: {
      description: 'Shared cost', amount: '20.00', expense_date: '2027-06-12',
      paid_by: creditor.id, mode: 'equal', shares: [{ user_id: debtor.id }],
    },
  });
  expect(expense.status()).toBe(201);
  const key = randomUUID();
  const created = await request.post(`/api/trips/${trip.id}/finance/settlements/`, {
    headers: authHeaders(debtor),
    data: { debtor_id: debtor.id, creditor_id: creditor.id, amount: '20.00', request_key: key },
  });
  expect(created.status()).toBe(201);
  const settlement = await created.json();
  expect(settlement.status).toBe('pending');
  expect(settlement.amount).toBe('20.00');

  expect((await request.post(`/api/trips/${trip.id}/finance/settlements/${settlement.id}/confirm/`, {
    headers: authHeaders(debtor), data: {},
  })).status()).toBe(403);
  const confirmed = await request.post(`/api/trips/${trip.id}/finance/settlements/${settlement.id}/confirm/`, {
    headers: authHeaders(creditor), data: {},
  });
  expect(confirmed.status()).toBe(200);
  expect((await confirmed.json()).status).toBe('confirmed');

  const duplicate = await request.post(`/api/trips/${trip.id}/finance/settlements/`, {
    headers: authHeaders(debtor),
    data: { debtor_id: debtor.id, creditor_id: creditor.id, amount: '20.00', request_key: key },
  });
  expect(duplicate.status()).toBe(409);
  const summary = await request.get(`/api/trips/${trip.id}/finance/summary/`, {
    headers: authHeaders(creditor),
  });
  const rows = (await summary.json()).participants as Array<{ user_id: number; balance: string }>;
  expect(rows.find((row) => row.user_id === debtor.id)?.balance).toBe('0.00');
  expect(rows.find((row) => row.user_id === creditor.id)?.balance).toBe('0.00');
});

test('acerto pendente bloqueia nova despesa e mantém saldo reservado', async ({ request }) => {
  const creditor = await createAccount(request, 'QA Creditor');
  const debtor = await createAccount(request, 'QA Debtor');
  await createFriendship(request, creditor, debtor);
  const trip = await createTrip(request, creditor, { invitee_ids: [debtor.id] });
  await request.post(`/api/trips/${trip.id}/invitation/accept/`, {
    headers: authHeaders(debtor), data: {},
  });
  await request.post(`/api/trips/${trip.id}/finance/expenses/`, {
    headers: authHeaders(creditor),
    data: {
      description: 'Shared cost', amount: '20.00', expense_date: '2027-06-12',
      paid_by: creditor.id, mode: 'equal', shares: [{ user_id: debtor.id }],
    },
  });
  const payment = await request.post(`/api/trips/${trip.id}/finance/settlements/`, {
    headers: authHeaders(debtor),
    data: {
      debtor_id: debtor.id, creditor_id: creditor.id,
      amount: '10.00', request_key: randomUUID(),
    },
  });
  expect(payment.status()).toBe(201);

  const blockedExpense = await request.post(`/api/trips/${trip.id}/finance/expenses/`, {
    headers: authHeaders(creditor),
    data: {
      description: 'Blocked cost', amount: '1.00', expense_date: '2027-06-12',
      paid_by: creditor.id, mode: 'equal', shares: [{ user_id: creditor.id }],
    },
  });
  expect(blockedExpense.status()).toBe(409);
  const eligibility = await request.get(`/api/trips/${trip.id}/leave-eligibility/`, {
    headers: authHeaders(debtor),
  });
  expect(eligibility.status()).toBe(200);
  expect((await eligibility.json()).reasons).toContain('pending_settlement');
});
