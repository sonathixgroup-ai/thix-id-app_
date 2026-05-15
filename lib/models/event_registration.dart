import 'dart:convert';

class EventRegistration {
  final String id;
  final String eventId;
  /// Supabase auth user id (optional for legacy local mode).
  final String? userId;
  final String attendeeThixId;
  final int tickets;
  /// Code unique à présenter à l'entrée (code-barres / scan).
  final String ticketCode;
  /// Server-side status: registered / checked_in / cancelled
  final String status;
  final DateTime? checkedInAt;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventRegistration({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.attendeeThixId,
    required this.tickets,
    required this.ticketCode,
    required this.status,
    required this.checkedInAt,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  EventRegistration copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? attendeeThixId,
    int? tickets,
    String? ticketCode,
    String? status,
    DateTime? checkedInAt,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventRegistration(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      attendeeThixId: attendeeThixId ?? this.attendeeThixId,
      tickets: tickets ?? this.tickets,
      ticketCode: ticketCode ?? this.ticketCode,
      status: status ?? this.status,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'attendee_thix_id': attendeeThixId,
      'tickets': tickets,
      'ticket_code': ticketCode,
      'status': status,
      'checked_in_at': checkedInAt?.toIso8601String(),
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static EventRegistration fromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? v) {
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    final rawNote = (json['note'] ?? '').toString();
    return EventRegistration(
      id: (json['id'] ?? '').toString(),
      eventId: (json['event_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString().trim().isEmpty ? null : (json['user_id'] ?? '').toString(),
      attendeeThixId: (json['attendee_thix_id'] ?? '').toString(),
      tickets: int.tryParse((json['tickets'] ?? '').toString()) ?? 1,
      ticketCode: (json['ticket_code'] ?? '').toString().trim().isEmpty ? (json['id'] ?? '').toString() : (json['ticket_code'] ?? '').toString(),
      status: (json['status'] ?? 'registered').toString(),
      checkedInAt: (json['checked_in_at'] == null) ? null : parseDate(json['checked_in_at']),
      note: rawNote.trim().isEmpty ? null : rawNote,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  static String encodeList(List<EventRegistration> items) => jsonEncode(items.map((e) => e.toJson()).toList(growable: false));

  static List<EventRegistration> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((m) => EventRegistration.fromJson(m.cast<String, dynamic>())).toList(growable: false);
  }
}
