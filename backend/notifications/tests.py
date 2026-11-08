from uuid import uuid4

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APIClient, APITestCase

from friends.models import Friendship
from trips import finance
from trips.models import Trip, TripMember

from .models import Notification


User = get_user_model()


class NotificationEventTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(
            username='owner@example.test', password='Pass123456!', first_name='Marina'
        )
        self.member = User.objects.create_user(
            username='member@example.test', password='Pass123456!', first_name='João'
        )
        self.other = User.objects.create_user(
            username='other@example.test', password='Pass123456!', first_name='Ana'
        )

    def authenticate(self, user):
        self.client.force_authenticate(user=user)

    def trip(self, *, accepted_members=()):
        trip = Trip.objects.create(
            name='Viagem de teste',
            destination='Lisboa',
            start_date='2026-08-10',
            end_date='2026-08-15',
            created_by=self.owner,
        )
        TripMember.objects.create(
            trip=trip, user=self.owner, status=TripMember.Status.ACCEPTED
        )
        for user in accepted_members:
            TripMember.objects.create(
                trip=trip, user=user, status=TripMember.Status.ACCEPTED
            )
        return trip

    def friendship(self, sender, receiver, status_value=Friendship.Status.ACCEPTED):
        return Friendship.objects.create(
            sender=sender, receiver=receiver, status=status_value
        )

    def test_friend_request_creates_one_private_notification(self):
        self.authenticate(self.owner)
        response = self.client.post(
            '/api/friends/requests/send/', {'receiver_id': self.member.pk}, format='json'
        )
        repeated = self.client.post(
            '/api/friends/requests/send/', {'receiver_id': self.member.pk}, format='json'
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(repeated.status_code, status.HTTP_409_CONFLICT)
        notification = Notification.objects.get(user=self.member)
        self.assertEqual(notification.event_type, 'friend_request')
        self.assertEqual(notification.resource_id, response.data['friendship']['id'])
        self.assertNotIn(self.owner.username, notification.message)

    def test_trip_creation_and_later_invite_create_notifications(self):
        self.friendship(self.owner, self.member)
        self.authenticate(self.owner)
        created = self.client.post(
            '/api/trips/',
            {
                'name': 'Lisboa',
                'destination': 'Lisboa, Portugal',
                'start_date': '2026-08-10',
                'end_date': '2026-08-15',
                'invitee_ids': [self.member.pk],
            },
            format='json',
        )
        self.assertEqual(created.status_code, status.HTTP_201_CREATED, created.data)
        initial = Notification.objects.get(user=self.member)
        self.assertEqual(initial.event_type, 'trip_invitation')
        self.assertEqual(initial.resource_id, created.data['id'])

        trip = self.trip()
        self.friendship(self.owner, self.other)
        later = self.client.post(
            f'/api/trips/{trip.pk}/invitations/',
            {'user_ids': [self.other.pk]}, format='json'
        )
        self.assertEqual(later.status_code, status.HTTP_201_CREATED, later.data)
        self.assertTrue(
            Notification.objects.filter(user=self.other, event_type='trip_invitation').exists()
        )

    def test_settlement_pending_confirmation_and_transfer_events(self):
        trip = self.trip(accepted_members=[self.member])
        finance.write_expense(
            trip.pk,
            self.owner,
            {
                'description': 'Hospedagem', 'amount': '20.00',
                'expense_date': '2026-08-10', 'paid_by': self.owner.pk,
                'mode': 'equal', 'shares': [{'user_id': self.member.pk}],
            },
        )
        settlement = finance.create_settlement(
            trip.pk,
            self.member,
            {
                'debtor_id': self.member.pk, 'creditor_id': self.owner.pk,
                'amount': '20.00', 'request_key': uuid4(),
            },
        )
        pending = Notification.objects.get(user=self.owner)
        self.assertEqual(pending.event_type, 'settlement_pending')
        self.assertEqual(pending.context_id, trip.pk)
        finance.transition_settlement(trip.pk, self.owner, settlement.pk, 'confirm')
        confirmed = Notification.objects.get(user=self.member)
        self.assertEqual(confirmed.event_type, 'settlement_confirmed')
        self.assertEqual(confirmed.resource_id, settlement.pk)

        finance.transfer_organizer(trip.pk, self.owner, self.member.pk)
        transfer_notice = Notification.objects.filter(
            user=self.member, event_type='organizer_transferred'
        ).get()
        self.assertEqual(transfer_notice.resource_id, trip.pk)

    def test_failed_business_operations_create_no_notifications(self):
        trip = self.trip()
        self.authenticate(self.owner)
        response = self.client.post(
            f'/api/trips/{trip.pk}/invitations/',
            {'user_ids': [self.member.pk]}, format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(Notification.objects.count(), 0)

    def test_list_count_read_read_all_pagination_and_user_isolation(self):
        first = Notification.objects.create(
            user=self.member, event_type='friend_request', title='Pedido',
            message='Solicitação recebida', resource_type='friendship',
            resource_id=1, event_key='test:first',
        )
        for index in range(24):
            Notification.objects.create(
                user=self.member, event_type='trip_invitation', title='Convite',
                message='Convite recebido', resource_type='trip', resource_id=index + 1,
                event_key=f'test:{index + 2}',
            )
        Notification.objects.create(
            user=self.other, event_type='friend_request', title='Privado',
            message='Privado', event_key='other:private',
        )
        self.authenticate(self.member)
        page = self.client.get('/api/notifications/')
        self.assertEqual(page.status_code, status.HTTP_200_OK)
        self.assertEqual(page.data['count'], 25)
        self.assertEqual(len(page.data['results']), 20)
        self.assertIsNotNone(page.data['next'])
        self.assertEqual(
            self.client.get('/api/notifications/unread-count/').data['unread_count'], 25
        )
        self.assertEqual(
            self.client.post(f'/api/notifications/{first.pk}/read/').status_code,
            status.HTTP_200_OK,
        )
        self.assertEqual(
            self.client.post(f'/api/notifications/{first.pk}/read/').status_code,
            status.HTTP_200_OK,
        )
        self.assertEqual(
            self.client.get('/api/notifications/unread-count/').data['unread_count'], 24
        )
        self.authenticate(self.other)
        self.assertEqual(
            self.client.post(f'/api/notifications/{first.pk}/read/').status_code,
            status.HTTP_404_NOT_FOUND,
        )
        self.authenticate(self.member)
        self.assertEqual(self.client.post('/api/notifications/read-all/').status_code, 200)
        self.assertEqual(
            self.client.get('/api/notifications/unread-count/').data['unread_count'], 0
        )

    def test_endpoints_require_authentication(self):
        self.assertEqual(
            self.client.get('/api/notifications/').status_code,
            status.HTTP_401_UNAUTHORIZED,
        )

    def test_notifications_are_persisted_for_a_new_authenticated_client(self):
        Notification.objects.create(
            user=self.member, event_type='trip_invitation', title='Convite',
            message='Você recebeu um convite.', resource_type='trip',
            resource_id=42, event_key='new-client:persistent',
        )
        new_client = APIClient()
        new_client.force_authenticate(user=self.member)

        response = new_client.get('/api/notifications/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['results'][0]['resource_id'], 42)
