from datetime import date
from decimal import Decimal
from uuid import uuid4
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

from django.contrib.auth import get_user_model
from django.db import transaction, IntegrityError, OperationalError, close_old_connections
from django.db.models.deletion import ProtectedError
from django.test import TestCase, TransactionTestCase
from rest_framework.test import APITestCase
from rest_framework.exceptions import ValidationError, PermissionDenied

from .models import Trip, TripMember, Expense, ExpenseShare, Settlement, FinancialEvent
from . import finance


class Fixture:
    def setUp(self):
        self.users = [get_user_model().objects.create_user(username=f'finance{i}', password=None) for i in range(5)]
        self.trip = Trip.objects.create(name='Teste', destination='Destino', start_date=date(2026, 1, 1), end_date=date(2026, 1, 2), created_by=self.users[0])
        for index, user in enumerate(self.users[:4]):
            TripMember.objects.create(trip=self.trip, user=user, status='pending' if index == 3 else 'accepted')

    def data(self, **kwargs):
        return {'description': 'Almoço', 'amount': '100.00', 'expense_date': '2026-01-01', 'paid_by': self.users[0].pk, 'mode': 'equal', 'shares': [{'user_id': self.users[1].pk}], **kwargs}

    def expense(self, actor=None, **kwargs):
        return finance.write_expense(self.trip.pk, actor or self.users[0], self.data(**kwargs))

    def payment(self, **kwargs):
        return finance.create_settlement(self.trip.pk, self.users[1], {'debtor_id': self.users[1].pk, 'creditor_id': self.users[0].pk, 'amount': '40.00', 'request_key': uuid4(), **kwargs})


class SplitTests(TestCase):
    def test_all_modes_and_exact_sum(self):
        cases = [('equal', [{ 'user_id': i} for i in [3, 1, 2]], ['3.34', '3.33', '3.33']),
                 ('exact', [{'user_id': 1, 'value': '2'}, {'user_id': 2, 'value': '8'}], ['2', '8']),
                 ('percent', [{'user_id': 1, 'value': '25'}, {'user_id': 2, 'value': '75'}], ['2.5', '7.5']),
                 ('units', [{'user_id': 1, 'value': '1'}, {'user_id': 2, 'value': '3'}], ['2.5', '7.5'])]
        for mode, shares, expected in cases:
            with self.subTest(mode=mode):
                result = finance.split_amount('10', mode, shares)
                self.assertEqual([row[1] for row in result], list(map(Decimal, expected)))
                self.assertEqual(sum(row[1] for row in result), Decimal('10'))

    def test_invalid_splits(self):
        for mode, shares in [('equal', []), ('equal', [{'user_id': 1}, {'user_id': 1}]), ('exact', [{'user_id': 1, 'value': '9'}]), ('percent', [{'user_id': 1, 'value': '99'}]), ('units', [{'user_id': 1, 'value': '0'}]), ('units', [{'user_id': 1, 'value': '1.5'}]), ('percent', [{'user_id': 1, 'value': '-100'}])]:
            with self.subTest(mode=mode, shares=shares), self.assertRaises(ValidationError):
                finance.split_amount('10', mode, shares)

    def test_invalid_amounts_and_precision(self):
        for value in ['0', '-1', 'NaN', 'Infinity', '1.001', 0.1, True]:
            with self.subTest(value=value), self.assertRaises(ValidationError):
                finance.split_amount(value, 'equal', [{'user_id': 1}])


class FinancialAPITests(Fixture, APITestCase):
    def url(self, resource='expenses', suffix=''):
        return f'/api/trips/{self.trip.pk}/finance/{resource}/{suffix}'

    def login(self, index=0):
        self.client.force_authenticate(self.users[index])

    def test_all_accepted_members_can_create_author_not_payer(self):
        for index in [0, 1, 2]:
            self.login(index)
            response = self.client.post(self.url(), self.data(), format='json')
            self.assertEqual(response.status_code, 201, response.data)
            self.assertEqual(response.data['created_by'], self.users[index].pk)
            self.assertEqual(response.data['paid_by'], self.users[0].pk)

    def test_pending_rejected_external_and_unauthenticated(self):
        for index in [3, 4]:
            self.login(index)
            self.assertEqual(self.client.post(self.url(), self.data(), format='json').status_code, 403)
            self.assertEqual(self.client.get(self.url('summary')).status_code, 403)
        TripMember.objects.filter(trip=self.trip, user=self.users[3]).update(status='rejected')
        self.login(3)
        self.assertEqual(self.client.get(self.url()).status_code, 403)
        self.client.force_authenticate(None)
        self.assertEqual(self.client.get(self.url()).status_code, 401)

    def test_only_original_author_edits_or_cancels(self):
        expense = self.expense(actor=self.users[1])
        for index in [0, 2]:
            self.login(index)
            self.assertEqual(self.client.put(self.url(suffix=f'{expense.pk}/'), self.data(version=1), format='json').status_code, 403)
            self.assertEqual(self.client.delete(self.url(suffix=f'{expense.pk}/'), {'version': 1}, format='json').status_code, 403)
        self.login(1)
        response = self.client.put(self.url(suffix=f'{expense.pk}/'), self.data(version=1, amount='120.00'), format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['created_by'], self.users[1].pk)
        self.assertEqual(response.data['updated_by'], self.users[1].pk)
        self.assertEqual(self.client.put(self.url(suffix=f'{expense.pk}/'), self.data(version=1), format='json').status_code, 409)
        self.assertEqual(self.client.delete(self.url(suffix=f'{expense.pk}/'), {'version': 2}, format='json').status_code, 200)
        expense.refresh_from_db()
        self.assertTrue(expense.cancelled)
        self.assertEqual(expense.events.count(), 3)
        self.assertEqual(expense.events.get(action='expense.updated').snapshot['before']['amount'], '100.00')

    def test_protected_fields_invalid_users_and_atomicity(self):
        self.login()
        for changes in [{'created_by': self.users[1].pk}, {'trip': 999}, {'amount': '0'}, {'amount': '-10'}, {'amount': '1.001'}, {'paid_by': self.users[3].pk}, {'shares': [{'user_id': self.users[3].pk}]}, {'shares': [{'user_id': self.users[4].pk}]}]:
            response = self.client.post(self.url(), self.data(**changes), format='json')
            self.assertIn(response.status_code, [400, 403], response.data)
        self.assertEqual(Expense.objects.count(), 0)
        self.assertEqual(ExpenseShare.objects.count(), 0)

    def test_other_trip_expense_not_found(self):
        expense = self.expense()
        other = Trip.objects.create(name='Outra', destination='x', start_date=date(2026, 1, 1), end_date=date(2026, 1, 2), created_by=self.users[0])
        TripMember.objects.create(trip=other, user=self.users[0], status='accepted')
        self.login()
        self.assertEqual(self.client.put(f'/api/trips/{other.pk}/finance/expenses/{expense.pk}/', self.data(version=1), format='json').status_code, 404)

    def test_budget_permission_null_zero_and_overrun(self):
        self.login(1)
        self.assertEqual(self.client.put(self.url('budget'), {'budget_amount': '50.00'}, format='json').status_code, 403)
        self.login()
        for value in ['-1.00']:
            self.assertEqual(self.client.put(self.url('budget'), {'budget_amount': value}, format='json').status_code, 400)
        for value in [None, '0.00', '50.00']:
            self.assertEqual(self.client.put(self.url('budget'), {'budget_amount': value}, format='json').status_code, 200)
        self.expense()
        result = self.client.get(self.url('summary')).data
        self.assertEqual(result['remaining_budget'], '-50.00')
        self.assertEqual(result['consumed_percent'], '200.00')
        self.client.put(self.url('budget'), {'budget_amount': None}, format='json')
        self.assertIsNone(self.client.get(self.url('summary')).data['consumed_percent'])

    def test_api_settlement_flow_and_history_no_email(self):
        self.expense()
        self.login(1)
        payload = {'debtor_id': self.users[1].pk, 'creditor_id': self.users[0].pk, 'amount': '40.00', 'request_key': str(uuid4())}
        response = self.client.post(self.url('settlements'), payload, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        item_id = response.data['id']
        self.assertEqual(self.client.post(self.url('settlements'), payload, format='json').status_code, 409)
        self.assertEqual(self.client.post(self.url('settlements', f'{item_id}/confirm/'), {}, format='json').status_code, 403)
        self.login(2)
        self.assertEqual(self.client.post(self.url('settlements', f'{item_id}/confirm/'), {}, format='json').status_code, 403)
        self.login()
        self.assertEqual(self.client.post(self.url('settlements', f'{item_id}/confirm/'), {}, format='json').status_code, 200)
        self.assertEqual(self.client.post(self.url('settlements', f'{item_id}/confirm/'), {}, format='json').status_code, 409)
        self.assertNotIn('email', str(self.client.get(self.url('history')).data))


class FinancialDomainTests(Fixture, TestCase):
    def test_balances_pending_confirmed_and_proposals(self):
        self.expense()
        rows = finance.balances(self.trip)
        self.assertEqual(rows[self.users[0].pk]['balance'], 100)
        self.assertEqual(rows[self.users[1].pk]['balance'], -100)
        item = self.payment()
        self.assertEqual(finance.balances(self.trip)[self.users[1].pk]['balance'], -100)
        self.assertEqual(finance.proposals(self.trip)[0]['amount'], '60.00')
        finance.transition_settlement(self.trip.pk, self.users[0], item.pk, 'confirm')
        rows = finance.balances(self.trip)
        self.assertEqual(rows[self.users[1].pk]['balance'], -60)
        self.assertEqual(sum(row['balance'] for row in rows.values()), 0)

    def test_pending_reserves_balance_and_freezes_expenses(self):
        expense = self.expense()
        self.payment(amount='70.00')
        with self.assertRaises(ValidationError):
            self.payment(amount='31.00')
        with self.assertRaises(finance.Conflict):
            self.expense()
        with self.assertRaises(finance.Conflict):
            finance.write_expense(self.trip.pk, self.users[0], {'version': 1}, expense.pk, cancel=True)

    def test_invalid_settlements(self):
        self.expense()
        for changes in [{'amount': '101'}, {'amount': '0'}, {'amount': '-1'}, {'debtor_id': self.users[0].pk}, {'creditor_id': self.users[3].pk}]:
            with self.subTest(changes=changes), self.assertRaises((ValidationError, PermissionDenied)):
                self.payment(**changes)
        self.assertFalse(Settlement.objects.exists())

    def test_cancelled_payment_restores_reservation_and_preserves_history(self):
        self.expense()
        item = self.payment(amount='100.00')
        finance.transition_settlement(self.trip.pk, self.users[1], item.pk, 'cancel')
        self.assertEqual(finance.proposals(self.trip)[0]['amount'], '100.00')
        self.assertEqual(item.events.count(), 2)
        self.payment(amount='100.00')

    def test_confirmed_payment_protects_original_expense_and_trip(self):
        expense = self.expense()
        item = self.payment()
        finance.transition_settlement(self.trip.pk, self.users[0], item.pk, 'confirm')
        with self.assertRaises(finance.Conflict):
            finance.write_expense(self.trip.pk, self.users[0], self.data(version=1), expense.pk)
        with self.assertRaises(ProtectedError):
            self.trip.delete()

    def test_exit_debtor_creditor_pending_neutral_and_organizer(self):
        self.expense()
        for index in [0, 1]:
            self.assertFalse(finance.exit_eligibility(self.trip, self.users[index])['eligible'])
        self.assertIn('outstanding_credit', finance.exit_eligibility(self.trip, self.users[0])['reasons'])
        self.assertIn('outstanding_debt', finance.exit_eligibility(self.trip, self.users[1])['reasons'])
        self.assertTrue(finance.exit_eligibility(self.trip, self.users[2])['eligible'])
        item = self.payment(amount='100.00')
        self.assertFalse(finance.exit_eligibility(self.trip, self.users[1])['eligible'])
        self.assertIn('pending_settlement', finance.exit_eligibility(self.trip, self.users[1])['reasons'])
        finance.transition_settlement(self.trip.pk, self.users[0], item.pk, 'confirm')
        self.assertTrue(finance.exit_eligibility(self.trip, self.users[1])['eligible'])
        self.assertFalse(finance.exit_eligibility(self.trip, self.users[0])['eligible'])
        self.assertIn('organizer_transfer_required', finance.exit_eligibility(self.trip, self.users[0])['reasons'])

    def test_database_constraints(self):
        expense = self.expense()
        with self.assertRaises(IntegrityError), transaction.atomic():
            ExpenseShare.objects.create(expense=expense, user=self.users[1], amount=0)


class ConcurrentSettlementTests(Fixture, TransactionTestCase):
    def test_exit_racing_new_expense_is_serialized_and_keeps_history_consistent(self):
        barrier = Barrier(2)

        def write_expense():
            close_old_connections()
            try:
                barrier.wait(timeout=10)
                finance.write_expense(
                    self.trip.pk,
                    self.users[0],
                    {
                        **self.data(),
                        'amount': '10.00',
                        'mode': 'exact',
                        'shares': [{'user_id': self.users[2].pk, 'value': '10.00'}],
                    },
                )
                return 'expense'
            except (OperationalError, finance.Conflict, ValidationError, PermissionDenied):
                return 'blocked'
            finally:
                close_old_connections()

        def leave_trip():
            close_old_connections()
            try:
                barrier.wait(timeout=10)
                finance.leave_trip(self.trip.pk, self.users[2])
                return 'left'
            except (OperationalError, finance.Conflict, ValidationError, PermissionDenied):
                return 'blocked'
            finally:
                close_old_connections()

        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(lambda task: task(), [write_expense, leave_trip]))

        membership = TripMember.objects.get(trip=self.trip, user=self.users[2])
        expense_exists = Expense.objects.filter(trip=self.trip).exists()
        if membership.status == TripMember.Status.LEFT:
            self.assertFalse(expense_exists)
        else:
            self.assertEqual(membership.status, TripMember.Status.ACCEPTED)
            if expense_exists:
                self.assertEqual(
                    finance.balances(self.trip)[self.users[2].pk]['balance'],
                    Decimal('-10.00'),
                )
        self.assertLessEqual(results.count('left'), 1)

    def test_competing_confirmations_only_apply_once(self):
        self.expense()
        item = self.payment(amount='100.00')
        barrier = Barrier(2)
        def attempt():
            close_old_connections()
            try:
                barrier.wait(timeout=10)
                finance.transition_settlement(self.trip.pk, self.users[0], item.pk, 'confirm')
                return True
            except (OperationalError, finance.Conflict):
                return False
            finally:
                close_old_connections()
        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(lambda _: attempt(), range(2)))
        self.assertLessEqual(sum(results), 1)
        self.assertLessEqual(item.events.filter(action='settlement.confirmed').count(), 1)
        rows = finance.balances(self.trip)
        self.assertGreaterEqual(rows[self.users[0].pk]['balance'], 0)

    def test_competing_payments_cannot_overreserve(self):
        self.expense()
        barrier = Barrier(2)
        def attempt():
            close_old_connections()
            try:
                barrier.wait(timeout=10)
                self.payment(amount='60.00')
                return True
            except (OperationalError, ValidationError, finance.Conflict):
                return False
            finally:
                close_old_connections()
        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(lambda _: attempt(), range(2)))
        self.assertLessEqual(sum(results), 1)
        self.assertLessEqual(sum((item.amount for item in Settlement.objects.all()), Decimal(0)), 100)
