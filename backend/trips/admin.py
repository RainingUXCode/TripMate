from django.contrib import admin

from .models import Trip, TripMember, TripOrganizerTransfer


@admin.register(Trip)
class TripAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "destination",
        "start_date",
        "end_date",
        "cover_image",
        "created_by",
        "created_at",
    )
    search_fields = ("name", "destination", "created_by__email")
    readonly_fields = ("created_at", "updated_at", "budget_amount", "finance_version")


@admin.register(TripMember)
class TripMemberAdmin(admin.ModelAdmin):
    list_display = ("trip", "user", "status", "created_at", "updated_at")
    list_filter = ("status",)
    search_fields = ("trip__name", "user__email")
    readonly_fields = ("created_at", "updated_at")


@admin.register(TripOrganizerTransfer)
class TripOrganizerTransferAdmin(admin.ModelAdmin):
    list_display = (
        "trip",
        "previous_organizer",
        "new_organizer",
        "transferred_by",
        "transferred_at",
    )
    readonly_fields = (
        "trip",
        "previous_organizer",
        "new_organizer",
        "transferred_by",
        "transferred_at",
    )

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


from .models import Expense, ExpenseShare, Settlement, FinancialEvent


class FinancialReadOnlyAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(Expense)
class ExpenseAdmin(FinancialReadOnlyAdmin):
    list_display = ('id', 'trip', 'description', 'amount', 'created_by', 'paid_by', 'mode', 'cancelled', 'version')
    list_filter = ('mode', 'cancelled')


@admin.register(ExpenseShare)
class ShareAdmin(FinancialReadOnlyAdmin):
    list_display = ('expense', 'user', 'amount', 'input_value')


@admin.register(Settlement)
class SettlementAdmin(FinancialReadOnlyAdmin):
    list_display = ('trip', 'debtor', 'creditor', 'amount', 'status', 'created_by', 'confirmed_by', 'created_at')
    list_filter = ('status',)


@admin.register(FinancialEvent)
class EventAdmin(FinancialReadOnlyAdmin):
    list_display = ('trip', 'expense', 'settlement', 'actor', 'action', 'created_at')
