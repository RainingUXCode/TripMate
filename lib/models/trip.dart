class Trip {
  final int id;
  final String name;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final String description;
  final DateTime createdAt;
  final int organizerId;
  final int acceptedParticipantsCount;
  final bool canDelete;
  final String? coverImageUrl;
  final List<TripParticipant> acceptedParticipants;
  final List<TripParticipant> pendingInvites;
  final List<TripParticipant> rejectedInvitees;

  const Trip({
    required this.id,
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.description,
    required this.createdAt,
    required this.organizerId,
    required this.acceptedParticipantsCount,
    this.canDelete = false,
    this.coverImageUrl,
    this.acceptedParticipants = const [],
    this.pendingInvites = const [],
    this.rejectedInvitees = const [],
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      startDate: DateTime.parse(json['start_date'].toString()),
      endDate: DateTime.parse(json['end_date'].toString()),
      description: json['description']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at'].toString()),
      organizerId: _toInt(json['created_by']),
      acceptedParticipantsCount: _toInt(json['accepted_participants_count']),
      canDelete: json['can_delete'] == true,
      coverImageUrl: json['cover_image_url']?.toString(),
      acceptedParticipants: _toParticipants(json['accepted_participants']),
      pendingInvites: _toParticipants(json['pending_invites']),
      rejectedInvitees: _toParticipants(json['rejected_invitees']),
    );
  }

  static List<TripParticipant> _toParticipants(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => TripParticipant.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class TripInvitation {
  final int tripId;
  final String name;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final String? coverImageUrl;
  final TripParticipant organizer;

  const TripInvitation({
    required this.tripId,
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.organizer,
    this.coverImageUrl,
  });

  factory TripInvitation.fromJson(Map<String, dynamic> json) {
    final organizer = json['organizer'] is Map
        ? Map<String, dynamic>.from(json['organizer'] as Map)
        : const <String, dynamic>{};
    return TripInvitation(
      tripId: Trip._toInt(json['trip_id']),
      name: json['name']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      startDate: DateTime.parse(json['start_date'].toString()),
      endDate: DateTime.parse(json['end_date'].toString()),
      coverImageUrl: json['cover_image_url']?.toString(),
      organizer: TripParticipant.fromJson(organizer),
    );
  }
}

class TripParticipant {
  final int id;
  final String name;
  final String? avatarUrl;

  const TripParticipant({required this.id, required this.name, this.avatarUrl});

  factory TripParticipant.fromJson(Map<String, dynamic> json) {
    return TripParticipant(
      id: Trip._toInt(json['id']),
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString().trim()
          : 'Viajante',
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}
