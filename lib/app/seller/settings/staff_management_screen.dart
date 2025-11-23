import 'package:flutter/material.dart';
import '../seller_models.dart';
import '../seller_repository.dart';

/// Screen for managing vendor staff and invitations
class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({
    required this.vendorId,
    required this.vendorName,
    required this.repository,
    super.key,
  });

  final String vendorId;
  final String vendorName;
  final SellerRepository repository;

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  bool _isLoading = true;
  String? _error;
  List<VendorStaffMember> _staff = [];

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final staff = await widget.repository.getVendorStaff(widget.vendorId);
      setState(() => _staff = staff);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _inviteStaffMember() async {
    final emailController = TextEditingController();
    String selectedRole = 'staff';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Invite Staff Member'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                      DropdownMenuItem(
                        value: 'manager',
                        child: Text('Manager'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedRole = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'An invitation will be sent to this email address',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Send Invite'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;

    final email = emailController.text.trim();
    if (email.isEmpty) return;

    try {
      await widget.repository.inviteStaffMember(
        vendorId: widget.vendorId,
        email: email,
        role: selectedRole,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invitation sent to $email'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending invitation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeStaffMember(VendorStaffMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Staff Member'),
        content: Text(
          'Are you sure you want to remove ${member.userFullName ?? member.userEmail ?? "this member"}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.repository.removeStaffMember(widget.vendorId, member.userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Staff member removed'),
          backgroundColor: Colors.green,
        ),
      );

      _loadStaff();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing staff member: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Staff Management'),
            Text(widget.vendorName, style: theme.textTheme.labelSmall),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Invite Staff',
            onPressed: _inviteStaffMember,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  const Text('Error loading staff'),
                  Text(_error!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadStaff,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _staff.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  const Text('No staff members yet'),
                  const SizedBox(height: 8),
                  Text(
                    'Invite team members to help manage your store',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _inviteStaffMember,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Invite Staff'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _staff.length,
              itemBuilder: (context, index) {
                final member = _staff[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: member.userAvatarUrl != null
                          ? NetworkImage(member.userAvatarUrl!)
                          : null,
                      child: member.userAvatarUrl == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(
                      member.userFullName ?? member.userEmail ?? 'Unknown',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (member.userEmail != null) Text(member.userEmail!),
                        Text(
                          'Role: ${member.role}',
                          style: theme.textTheme.labelSmall,
                        ),
                        Text(
                          'Joined: ${member.createdAt.toLocal().toString().split(' ')[0]}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    trailing: member.isOwner
                        ? const Chip(
                            label: Text('Owner'),
                            backgroundColor: Colors.blue,
                          )
                        : PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'permissions',
                                child: Text('Edit Permissions'),
                              ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('Remove'),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'remove') {
                                _removeStaffMember(member);
                              }
                            },
                          ),
                  ),
                );
              },
            ),
    );
  }
}
