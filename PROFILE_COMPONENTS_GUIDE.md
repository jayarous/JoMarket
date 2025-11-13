# Profile Management Component Usage Guide

## Quick Reference for Developers

### 1. ProfileEditSheet - Profile Editing with Avatar Upload

```dart
// Show profile edit sheet
final updatedProfile = await showModalBottomSheet<UserProfile>(
  context: context,
  isScrollControlled: true,
  builder: (context) => ProfileEditSheet(
    profile: currentProfile,
    repository: profileRepository,
  ),
);

// Handle result
if (updatedProfile != null) {
  setState(() {
    _profile = updatedProfile;
  });
  onReloadRequested();
}
```

**Features:**
- Full name, phone, country editing
- Avatar upload with image picker
- Uploads to Supabase Storage `public/avatars/`
- Returns updated UserProfile or null if cancelled

---

### 2. AddressManagementSection - Complete Address Management

```dart
// Add to any screen
AddressManagementSection(
  userId: currentUser.id,
  repository: dashboardRepository,
)
```

**Features:**
- Lists all user addresses
- Add new addresses
- Delete existing addresses
- Shows default address badge
- Auto-refreshes on changes

---

### 3. AddressFormSheet - Add/Edit Address

```dart
// Show address form
final newAddress = await showModalBottomSheet<Address>(
  context: context,
  isScrollControlled: true,
  builder: (context) => AddressFormSheet(
    userId: currentUser.id,
    repository: dashboardRepository,
  ),
);

// Handle result
if (newAddress != null) {
  // Address was created
  refreshAddresses();
}
```

**Form Fields:**
- Label (Home, Office, etc.)
- Address line 1 (required)
- Address line 2 (optional)
- City (required)
- State/Region (optional)
- Postal code (optional)
- Country (required, defaults to Jordan)
- Set as default toggle

---

### 4. AddressCard - Display Single Address

```dart
AddressCard(
  address: myAddress,
  onDelete: () async {
    await repository.deleteAddress(myAddress.id);
    refreshAddresses();
  },
)
```

**Display:**
- Label with default badge
- Full formatted address
- Delete button (optional)
- Material Card styling

---

### 5. RoleEnrollmentSection - Role Upgrade UI

```dart
RoleEnrollmentSection(
  profile: userProfile,
  roles: currentRoles,
  onEnrollmentRequested: () {
    // Handle enrollment flow
    // e.g., navigate to vendor application
  },
)
```

**Shows:**
- Available roles not yet enrolled
- Vendor and Delivery enrollment cards
- Completion message when all roles enrolled

---

## Repository Methods

### ProfileRepository

```dart
// Update profile (including avatar URL)
final updated = await profileRepository.updateProfile(
  userId: userId,
  update: UserProfileUpdate(
    fullName: 'John Doe',
    phone: '+962-XXX-XXXX',
    avatarUrl: 'https://...', // from Supabase Storage
    defaultCountry: 'JO',
  ),
);
```

### DashboardRepository

```dart
// Get user addresses
final addresses = await dashboardRepository.getUserAddresses(userId);

// Create address
final address = await dashboardRepository.createAddress(
  AddressInput(
    userId: userId,
    label: 'Home',
    line1: '123 Main St',
    city: 'Amman',
    country: 'Jordan',
    isDefault: true,
  ),
);

// Delete address (soft delete)
await dashboardRepository.deleteAddress(addressId);
```

---

## Avatar Upload Flow

### 1. User picks image from gallery
```dart
final XFile? image = await ImagePicker().pickImage(
  source: ImageSource.gallery,
  maxWidth: 512,
  maxHeight: 512,
  imageQuality: 85,
);
```

### 2. Upload to Supabase Storage
```dart
final file = File(image.path);
final bytes = await file.readAsBytes();
final fileName = '${userId}_${timestamp}.jpg';
final path = 'avatars/$fileName';

await Supabase.instance.client.storage
    .from('public')
    .uploadBinary(path, bytes);
```

### 3. Get public URL
```dart
final url = Supabase.instance.client.storage
    .from('public')
    .getPublicUrl(path);
```

### 4. Update profile with avatar URL
```dart
await profileRepository.updateProfile(
  userId: userId,
  update: UserProfileUpdate(avatarUrl: url),
);
```

---

## Supabase Storage Setup

### Create Storage Bucket

1. Go to Supabase Dashboard → Storage
2. Create new bucket: `public`
3. Enable public access
4. Set RLS policy (if needed):

```sql
-- Allow authenticated users to upload to their own folder
CREATE POLICY "Users can upload avatars"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'public' 
  AND (storage.foldername(name))[1] = 'avatars'
);

-- Allow everyone to read public files
CREATE POLICY "Public files are publicly accessible"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'public');
```

---

## Common Patterns

### Pattern 1: Profile Screen with All Features

```dart
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.profile,
    required this.repository,
    required this.dashboardRepository,
    required this.roles,
    required this.onReloadRequested,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile header with avatar
            ProfileHeader(...),
            
            // Edit profile button → opens ProfileEditSheet
            EditButton(...),
            
            // Address management
            AddressManagementSection(
              userId: profile.userId,
              repository: dashboardRepository,
            ),
            
            // Role enrollment
            RoleEnrollmentSection(
              profile: profile,
              roles: roles,
              onEnrollmentRequested: _handleEnrollment,
            ),
          ],
        ),
      ),
    );
  }
}
```

### Pattern 2: Quick Profile Edit from Dashboard

```dart
// In any dashboard widget
FilledButton.icon(
  icon: Icon(Icons.edit),
  label: Text('Edit Profile'),
  onPressed: () async {
    final updated = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProfileEditSheet(
        profile: currentProfile,
        repository: profileRepository,
      ),
    );
    
    if (updated != null) {
      onProfileUpdated(updated);
    }
  },
)
```

### Pattern 3: Address Selection (Checkout Flow)

```dart
// Show address selection with add option
final selectedAddress = await showModalBottomSheet<Address>(
  context: context,
  builder: (context) => AddressSelectionSheet(
    addresses: existingAddresses,
    onAddNew: () async {
      final newAddress = await showModalBottomSheet<Address>(
        context: context,
        isScrollControlled: true,
        builder: (context) => AddressFormSheet(
          userId: userId,
          repository: repository,
        ),
      );
      return newAddress;
    },
  ),
);
```

---

## Error Handling

### Handle Upload Failures

```dart
try {
  await uploadAvatar();
} catch (e) {
  if (e is StorageException) {
    // Handle storage-specific errors
    showError('Failed to upload image: ${e.message}');
  } else {
    // Handle general errors
    showError('Failed to upload image. Please try again.');
  }
}
```

### Handle Profile Update Failures

```dart
try {
  final updated = await repository.updateProfile(...);
  showSuccess('Profile updated successfully');
} on PostgrestException catch (e) {
  showError('Database error: ${e.message}');
} catch (e) {
  showError('Failed to update profile. Please try again.');
}
```

---

## Testing Checklist

- [ ] Avatar upload from gallery works
- [ ] Avatar displays correctly in profile
- [ ] Profile edit saves all fields
- [ ] Address creation works
- [ ] Address deletion works
- [ ] Default address toggle works
- [ ] Role enrollment UI shows correct options
- [ ] Profile updates propagate to parent screens
- [ ] Error messages display correctly
- [ ] Loading states show during async operations
- [ ] Layout scrolls properly on small screens
- [ ] Form validation works

---

## Performance Notes

- **Avatar images** are automatically resized to 512x512 before upload
- **Image quality** is set to 85% to reduce file size
- **Address lists** are fetched on demand, not cached
- **Profile updates** trigger parent reload via callback
- **Soft deletes** used for addresses (can be recovered if needed)

---

## Accessibility

All components include:
- Semantic labels for screen readers
- Sufficient touch targets (44x44 minimum)
- Proper focus management
- Clear error messages
- Loading indicators

---

**Last Updated**: November 13, 2025
