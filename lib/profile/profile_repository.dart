import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_models.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<UserProfile> fetchOrCreateProfile({
    required String userId,
    String? inferredFullName,
    String? defaultCountry,
    String? avatarUrl,
    String? phone,
  }) async {
    final existing = await _client
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      return UserProfile.fromMap(existing);
    }

    final payload = {
      'user_id': userId,
      if (inferredFullName != null) 'full_name': inferredFullName,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'default_country': defaultCountry ?? 'JO',
    };

    final created = await _client
        .from('profiles')
        .insert(payload)
        .select()
        .single();

    return UserProfile.fromMap(created);
  }

  Future<List<RoleAssignment>> fetchOrCreateRoles({
    required String userId,
  }) async {
    Future<List<dynamic>> queryRoles() {
      return _client
          .from('user_roles')
          .select()
          .eq('user_id', userId)
          .order('created_at')
          .then((value) => value as List<dynamic>);
    }

    var response = await queryRoles();
    if (response.isNotEmpty) {
      return response
          .map((item) => RoleAssignment.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    await _client.from('user_roles').insert({
      'user_id': userId,
      'role': AppUserRole.shopper.databaseValue,
    });

    response = await queryRoles();
    return response
        .map((item) => RoleAssignment.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, String>> fetchVendorNames(Set<String> vendorIds) async {
    if (vendorIds.isEmpty) {
      return {};
    }

    final response = await _client
        .from('vendors')
        .select('id,name')
        .in_('id', vendorIds.toList());

    final Map<String, String> names = {};
    for (final row in response as List<dynamic>) {
      final map = row as Map<String, dynamic>;
      names[map['id'] as String] = (map['name'] as String?) ?? 'Vendor';
    }
    return names;
  }

  Future<UserProfile> updateProfile({
    required String userId,
    required UserProfileUpdate update,
  }) async {
    final response = await _client
        .from('profiles')
        .update(update.toMap())
        .eq('user_id', userId)
        .select()
        .single();

    return UserProfile.fromMap(response);
  }
}
