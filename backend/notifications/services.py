from .models import Notification


def create_notification(*, user=None, user_id=None, event_type, title, message,
                        event_key, resource_type='', resource_id=None,
                        context_id=None):
    if user is None and user_id is None:
        raise ValueError('A notification recipient is required.')
    defaults = {
        'event_type': event_type,
        'title': title,
        'message': message,
        'resource_type': resource_type,
        'resource_id': resource_id,
        'context_id': context_id,
    }
    lookup = {'event_key': event_key}
    defaults['user' if user is not None else 'user_id'] = user if user is not None else user_id
    notification, _ = Notification.objects.get_or_create(
        **lookup,
        defaults=defaults,
    )
    return notification
