import 'package:flutter/foundation.dart';

/// Enumerates the Supabase `user_role` enum values the app cares about.
enum AppUserRole {
  shopper('shopper', 'Shopper'),
  vendorOwner('vendor_owner', 'Vendor owner'),
  vendorStaff('vendor_staff', 'Vendor staff'),
  delivery('delivery', 'Delivery staff'),
  admin('admin', 'Admin');

  const AppUserRole(this.databaseValue, this._label);

  final String databaseValue;
  final String _label;

  String get label => _label;

  static AppUserRole fromDatabaseValue(String value) {
    return AppUserRole.values.firstWhere(
      (role) => role.databaseValue == value,
      orElse: () {
        debugPrint('Unknown user role "$value", defaulting to shopper.');
        return AppUserRole.shopper;
      },
    );
  }
}

/// Represents a row from `user_roles`.
class RoleAssignment {
  RoleAssignment({
    required this.id,
    required this.role,
    required this.createdAt,
    this.vendorId,
    this.vendorName,
  });

  final String id;
  final AppUserRole role;
  final DateTime createdAt;
  final String? vendorId;
  final String? vendorName;

  factory RoleAssignment.guest() {
    return RoleAssignment(
      id: 'guest',
      role: AppUserRole.shopper,
      createdAt: DateTime.now(),
    );
  }

  bool get isVendorScoped => vendorId != null;

  String get displayLabel {
    if (vendorName != null && vendorName!.isNotEmpty) {
      return '${role.label} - $vendorName';
    }
    return role.label;
  }

  RoleAssignment copyWith({String? vendorName}) {
    return RoleAssignment(
      id: id,
      role: role,
      vendorId: vendorId,
      vendorName: vendorName ?? this.vendorName,
      createdAt: createdAt,
    );
  }

  static RoleAssignment fromMap(Map<String, dynamic> map) {
    return RoleAssignment(
      id: map['id'] as String,
      role: AppUserRole.fromDatabaseValue(map['role'] as String),
      vendorId: map['vendor_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Represents a row from `profiles`.
class UserProfile {
  const UserProfile({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.avatarUrl,
    required this.defaultCountry,
    required this.createdAt,
    required this.updatedAt,
  });

  final String userId;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String? defaultCountry;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UserProfile.guest() {
    final now = DateTime.now();
    return UserProfile(
      userId: 'guest',
      fullName: 'Guest User',
      phone: null,
      avatarUrl: null,
      defaultCountry: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? defaultCountry,
  }) {
    return UserProfile(
      userId: userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      defaultCountry: defaultCountry ?? this.defaultCountry,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static UserProfile fromMap(Map<String, dynamic> map) {
    return UserProfile(
      userId: map['user_id'] as String,
      fullName: map['full_name'] as String?,
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      defaultCountry: map['default_country'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// Payload for updating the profile row.
class UserProfileUpdate {
  const UserProfileUpdate({
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.defaultCountry,
  });

  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String? defaultCountry;

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (phone != null) data['phone'] = phone;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    if (defaultCountry != null) data['default_country'] = defaultCountry;
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return data;
  }
}
