import 'dart:convert';

class EventItem {
  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;

  /// Display-only label (best-effort). For Supabase events, it is derived from [startsAt].
  final String dateLabel;

  /// Physical location label or city. For online-only events, can be "En ligne".
  final String location;

  /// High level category (Tech, Business, Networking…).
  final String category;

  /// UI-friendly price label ("Gratuit", "50 USD").
  final String priceLabel;

  /// Structured pricing.
  final bool isFree;
  final num? price;
  final String currency;

  /// Event type: online / physical / hybrid.
  final String eventType;

  /// Optional streaming / meeting link.
  final String? meetingLink;

  /// Short hook used in banners.
  final String? quickHook;

  /// Long description.
  final String description;

  /// Highlights shown in details.
  final List<String> highlights;

  /// Featured / "À LA UNE".
  final bool isFeatured;

  /// Published/unpublished.
  final String status;

  /// Attendees label (best-effort).
  final String attendeesLabel;

  /// Local asset path used as hero/cover image (fallback).
  final String? imageAssetPath;

  /// Supabase Storage cover reference.
  final String? coverImageBucket;
  final String? coverImagePath;

  /// Optional rich data (stored as JSON in Supabase).
  final List<Map<String, dynamic>> speakers;
  final List<Map<String, dynamic>> sponsors;
  final List<Map<String, dynamic>> agenda;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventItem({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.startsAt,
    required this.endsAt,
    required this.location,
    required this.category,
    required this.priceLabel,
    required this.isFree,
    required this.price,
    required this.currency,
    required this.eventType,
    required this.meetingLink,
    required this.quickHook,
    required this.attendeesLabel,
    required this.description,
    required this.highlights,
    required this.imageAssetPath,
    required this.coverImageBucket,
    required this.coverImagePath,
    required this.isFeatured,
    required this.status,
    required this.speakers,
    required this.sponsors,
    required this.agenda,
    required this.createdAt,
    required this.updatedAt,
  });

  EventItem copyWith({
    String? id,
    String? title,
    String? dateLabel,
    DateTime? startsAt,
    DateTime? endsAt,
    String? location,
    String? category,
    String? priceLabel,
    bool? isFree,
    num? price,
    String? currency,
    String? eventType,
    String? meetingLink,
    String? quickHook,
    String? attendeesLabel,
    String? description,
    List<String>? highlights,
    String? imageAssetPath,
    String? coverImageBucket,
    String? coverImagePath,
    bool? isFeatured,
    String? status,
    List<Map<String, dynamic>>? speakers,
    List<Map<String, dynamic>>? sponsors,
    List<Map<String, dynamic>>? agenda,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventItem(
      id: id ?? this.id,
      title: title ?? this.title,
      dateLabel: dateLabel ?? this.dateLabel,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      location: location ?? this.location,
      category: category ?? this.category,
      priceLabel: priceLabel ?? this.priceLabel,
      isFree: isFree ?? this.isFree,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      eventType: eventType ?? this.eventType,
      meetingLink: meetingLink ?? this.meetingLink,
      quickHook: quickHook ?? this.quickHook,
      attendeesLabel: attendeesLabel ?? this.attendeesLabel,
      description: description ?? this.description,
      highlights: highlights ?? this.highlights,
      imageAssetPath: imageAssetPath ?? this.imageAssetPath,
      coverImageBucket: coverImageBucket ?? this.coverImageBucket,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      isFeatured: isFeatured ?? this.isFeatured,
      status: status ?? this.status,
      speakers: speakers ?? this.speakers,
      sponsors: sponsors ?? this.sponsors,
      agenda: agenda ?? this.agenda,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date_label': dateLabel,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),
      'location': location,
      'category': category,
      'price_label': priceLabel,
      'is_free': isFree,
      'price': price,
      'currency': currency,
      'event_type': eventType,
      'meeting_link': meetingLink,
      'quick_hook': quickHook,
      'attendees_label': attendeesLabel,
      'description': description,
      'highlights': highlights,
      'image_asset_path': imageAssetPath,
      'cover_image_bucket': coverImageBucket,
      'cover_image_path': coverImagePath,
      'is_featured': isFeatured,
      'status': status,
      'speakers': speakers,
      'sponsors': sponsors,
      'agenda': agenda,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static EventItem fromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? v) {
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    List<Map<String, dynamic>> parseMapList(Object? v) {
      if (v is List) {
        return v
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList(growable: false);
      }
      return const <Map<String, dynamic>>[];
    }

    num? parseNum(Object? v) {
      if (v == null) return null;
      if (v is num) return v;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return num.tryParse(s.replaceAll(',', '.'));
    }

    final startsAt = parseDate(json['starts_at']);
    final endsAt = (json['ends_at'] == null) ? null : parseDate(json['ends_at']);
    final isFree = (json['is_free'] == true) || (json['is_free']?.toString() == 'true') || (parseNum(json['price']) == null);
    final currency = (json['currency'] ?? 'USD').toString().trim().isEmpty ? 'USD' : (json['currency'] ?? 'USD').toString();
    final price = parseNum(json['price']);
    final priceLabelRaw = (json['price_label'] ?? '').toString().trim();
    final priceLabel = priceLabelRaw.isNotEmpty
        ? priceLabelRaw
        : (isFree ? 'Gratuit' : (price == null ? '' : '${price.toString()} $currency'));
    final status = (json['status'] ?? 'published').toString();
    final isFeatured = (json['is_featured'] == true) || (json['is_featured']?.toString() == 'true');

    // Backward-compat: legacy local seed used these fields.
    final legacyPrice = (json['price'] ?? '').toString();
    final legacyCategory = (json['category'] ?? '').toString();
    final legacyLocation = (json['location'] ?? '').toString();

    return EventItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      dateLabel: (json['date_label'] ?? '').toString().trim().isEmpty ? _defaultDateLabel(startsAt) : (json['date_label'] ?? '').toString(),
      startsAt: startsAt,
      endsAt: endsAt,
      location: legacyLocation.trim().isEmpty ? (json['place'] ?? json['city'] ?? '—').toString() : legacyLocation,
      category: legacyCategory.trim().isEmpty ? (json['category'] ?? 'Événement').toString() : legacyCategory,
      priceLabel: legacyPrice.trim().isNotEmpty ? legacyPrice : priceLabel,
      isFree: isFree,
      price: price,
      currency: currency,
      eventType: (json['event_type'] ?? 'online').toString(),
      meetingLink: (json['meeting_link'] ?? json['virtual_link'] ?? '').toString().trim().isEmpty ? null : (json['meeting_link'] ?? json['virtual_link']).toString(),
      quickHook: (json['quick_hook'] ?? '').toString().trim().isEmpty ? null : (json['quick_hook'] ?? '').toString(),
      attendeesLabel: (json['attendees_label'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      highlights: (json['highlights'] is List)
          ? (json['highlights'] as List).map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      imageAssetPath: (json['image_asset_path'] ?? '').toString().trim().isEmpty ? null : (json['image_asset_path'] ?? '').toString(),
      coverImageBucket: (json['cover_image_bucket'] ?? '').toString().trim().isEmpty ? null : (json['cover_image_bucket'] ?? '').toString(),
      coverImagePath: (json['cover_image_path'] ?? '').toString().trim().isEmpty ? null : (json['cover_image_path'] ?? '').toString(),
      isFeatured: isFeatured,
      status: status,
      speakers: parseMapList(json['speakers']),
      sponsors: parseMapList(json['sponsors']),
      agenda: parseMapList(json['agenda']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  static String _defaultDateLabel(DateTime startsAt) {
    // Simple formatting without intl dependency.
    final d = startsAt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} • ${two(d.hour)}:${two(d.minute)}';
  }

  static String encodeList(List<EventItem> items) => jsonEncode(items.map((e) => e.toJson()).toList(growable: false));

  static List<EventItem> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((m) => EventItem.fromJson(m.cast<String, dynamic>())).toList(growable: false);
  }
}
