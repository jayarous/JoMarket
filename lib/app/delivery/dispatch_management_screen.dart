import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'delivery_service.dart';

/// Admin dispatch management screen
class DispatchManagementScreen extends StatefulWidget {
  const DispatchManagementScreen({super.key});

  @override
  State<DispatchManagementScreen> createState() =>
      _DispatchManagementScreenState();
}

class _DispatchManagementScreenState extends State<DispatchManagementScreen> {
  late final DeliveryService _service;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _availableStaff = [];
  List<Map<String, dynamic>> _pendingShipments = [];

  @override
  void initState() {
    super.initState();
    _service = DeliveryService(Supabase.instance.client);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load available staff
      final staffResponse = await Supabase.instance.client
          .from('delivery_staff')
          .select('id,user_id,is_available,max_concurrent_jobs,vehicle_type')
          .eq('active', true)
          .eq('is_available', true);

      // Load pending shipments
      final shipmentsResponse = await Supabase.instance.client
          .from('shipments')
          .select('id,order_id,status,created_at')
          .is_('accepted_by_staff_id', null)
          .eq('visibility', 'marketplace')
          .order('created_at', ascending: true)
          .limit(50);

      setState(() {
        _availableStaff = (staffResponse as List)
            .map((s) => s as Map<String, dynamic>)
            .toList();
        _pendingShipments = (shipmentsResponse as List)
            .map((s) => s as Map<String, dynamic>)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _assignShipment(String shipmentId, String staffId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      await _service.createDispatchAssignment(
        shipmentId: shipmentId,
        staffId: staffId,
        assignedBy: userId,
        priority: 3,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shipment assigned successfully')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispatch Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
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
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Pending Shipments (${_pendingShipments.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ..._pendingShipments.map((shipment) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(
                        'Shipment ${(shipment['id'] as String).substring(0, 8)}',
                      ),
                      subtitle: Text(
                        shipment['status'] as String? ?? 'unknown',
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.person_add),
                        tooltip: 'Assign to staff',
                        onSelected: (staffId) =>
                            _assignShipment(shipment['id'] as String, staffId),
                        itemBuilder: (context) => _availableStaff
                            .map(
                              (staff) => PopupMenuItem<String>(
                                value: staff['id'] as String,
                                child: Text(
                                  'Staff ${(staff['id'] as String).substring(0, 8)}',
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                Text(
                  'Available Staff (${_availableStaff.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ..._availableStaff.map((staff) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(
                        'Staff ${(staff['id'] as String).substring(0, 8)}',
                      ),
                      subtitle: Text(
                        staff['vehicle_type'] as String? ?? 'No vehicle',
                      ),
                      trailing: Text(
                        'Max: ${staff['max_concurrent_jobs']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
