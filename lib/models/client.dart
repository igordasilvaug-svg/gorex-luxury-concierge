import 'enums.dart';

/// Profil client VIP confidentiel
class Client {
  final String id;
  final String code; // ex: GRX-VIP-0001
  final String fullName;
  final String? companyName;
  final ClientCategory category;
  final String email;
  final String phone;
  final String? secondaryContact;
  final String language;
  final String country;
  final String city;
  final String? personalAssistant;
  final String? assistantPhone;
  final ConfidentialityLevel confidentiality;
  final String subscriptionTierId;
  final String? assignedConciergeId;

  // Préférences
  final List<String> preferredHotels;
  final List<String> preferredRestaurants;
  final List<String> preferredDrivers;
  final List<String> travelPreferences;
  final List<String> dietaryPreferences;
  final List<String> interests;

  final String? notes;
  final bool active;
  final DateTime createdAt;

  const Client({
    required this.id,
    required this.code,
    required this.fullName,
    this.companyName,
    required this.category,
    required this.email,
    required this.phone,
    this.secondaryContact,
    this.language = 'Français',
    required this.country,
    required this.city,
    this.personalAssistant,
    this.assistantPhone,
    this.confidentiality = ConfidentialityLevel.elevated,
    required this.subscriptionTierId,
    this.assignedConciergeId,
    this.preferredHotels = const [],
    this.preferredRestaurants = const [],
    this.preferredDrivers = const [],
    this.travelPreferences = const [],
    this.dietaryPreferences = const [],
    this.interests = const [],
    this.notes,
    this.active = true,
    required this.createdAt,
  });

  Client copyWith({
    String? fullName,
    String? companyName,
    ClientCategory? category,
    String? email,
    String? phone,
    String? secondaryContact,
    String? language,
    String? country,
    String? city,
    String? personalAssistant,
    String? assistantPhone,
    ConfidentialityLevel? confidentiality,
    String? subscriptionTierId,
    String? assignedConciergeId,
    List<String>? preferredHotels,
    List<String>? preferredRestaurants,
    List<String>? preferredDrivers,
    List<String>? travelPreferences,
    List<String>? dietaryPreferences,
    List<String>? interests,
    String? notes,
    bool? active,
  }) => Client(
    id: id,
    code: code,
    fullName: fullName ?? this.fullName,
    companyName: companyName ?? this.companyName,
    category: category ?? this.category,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    secondaryContact: secondaryContact ?? this.secondaryContact,
    language: language ?? this.language,
    country: country ?? this.country,
    city: city ?? this.city,
    personalAssistant: personalAssistant ?? this.personalAssistant,
    assistantPhone: assistantPhone ?? this.assistantPhone,
    confidentiality: confidentiality ?? this.confidentiality,
    subscriptionTierId: subscriptionTierId ?? this.subscriptionTierId,
    assignedConciergeId: assignedConciergeId ?? this.assignedConciergeId,
    preferredHotels: preferredHotels ?? this.preferredHotels,
    preferredRestaurants: preferredRestaurants ?? this.preferredRestaurants,
    preferredDrivers: preferredDrivers ?? this.preferredDrivers,
    travelPreferences: travelPreferences ?? this.travelPreferences,
    dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
    interests: interests ?? this.interests,
    notes: notes ?? this.notes,
    active: active ?? this.active,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'fullName': fullName,
    'companyName': companyName,
    'category': category.name,
    'email': email,
    'phone': phone,
    'secondaryContact': secondaryContact,
    'language': language,
    'country': country,
    'city': city,
    'personalAssistant': personalAssistant,
    'assistantPhone': assistantPhone,
    'confidentiality': confidentiality.name,
    'subscriptionTierId': subscriptionTierId,
    'assignedConciergeId': assignedConciergeId,
    'preferredHotels': preferredHotels,
    'preferredRestaurants': preferredRestaurants,
    'preferredDrivers': preferredDrivers,
    'travelPreferences': travelPreferences,
    'dietaryPreferences': dietaryPreferences,
    'interests': interests,
    'notes': notes,
    'active': active,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Client.fromMap(Map<String, dynamic> m) => Client(
    id: m['id'] as String,
    code: m['code'] as String,
    fullName: m['fullName'] as String,
    companyName: m['companyName'] as String?,
    category: ClientCategory.fromName(m['category'] as String),
    email: m['email'] as String,
    phone: m['phone'] as String,
    secondaryContact: m['secondaryContact'] as String?,
    language: m['language'] as String? ?? 'Français',
    country: m['country'] as String,
    city: m['city'] as String,
    personalAssistant: m['personalAssistant'] as String?,
    assistantPhone: m['assistantPhone'] as String?,
    confidentiality: ConfidentialityLevel.fromName(
      m['confidentiality'] as String,
    ),
    subscriptionTierId: m['subscriptionTierId'] as String,
    assignedConciergeId: m['assignedConciergeId'] as String?,
    preferredHotels: _list(m['preferredHotels']),
    preferredRestaurants: _list(m['preferredRestaurants']),
    preferredDrivers: _list(m['preferredDrivers']),
    travelPreferences: _list(m['travelPreferences']),
    dietaryPreferences: _list(m['dietaryPreferences']),
    interests: _list(m['interests']),
    notes: m['notes'] as String?,
    active: m['active'] as bool? ?? true,
    createdAt: DateTime.parse(m['createdAt'] as String),
  );

  static List<String> _list(dynamic v) =>
      v == null ? <String>[] : (v as List).map((e) => e.toString()).toList();
}
