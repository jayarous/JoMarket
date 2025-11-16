import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'delivery_service.dart';
import 'proof_of_delivery_screen.dart';

class DeliveryJobScreen extends StatefulWidget {
  const DeliveryJobScreen({
    required this.shipmentId,
    required this.staffId,
    super.key,
  });

  final String shipmentId;
  final String staffId;

  @override
  State<DeliveryJobScreen> createState() => _DeliveryJobScreenState();
}

class _DeliveryJobScreenState extends State<DeliveryJobScreen> {
  late final DeliveryService _service;
  ShipmentDetail? _shipment;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = DeliveryService(Supabase.instance.client);
    _loadShipment();
  }

  Future<void> _loadShipment() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('shipments')
          .select(
            'id,order_id,vendor_id,status,visibility,tracking_number,carrier,accepted_by_staff_id,updated_at',
          )
          .eq('id', widget.shipmentId)
          .single();

      setState(() {
        _shipment = ShipmentDetail.fromMap(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptJob() async {
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client
          .from('shipments')
          .update({
            'accepted_by_staff_id': widget.staffId,
            'status': 'assigned',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', widget.shipmentId);

      await _loadShipment();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Job accepted!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to accept job: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _completeJob() async {
    // Navigate to proof of delivery screen
    final pod = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProofOfDeliveryScreen(
          shipmentId: widget.shipmentId,
          staffId: widget.staffId,
          service: _service,
        ),
      ),
    );

    // If POD was submitted, reload the shipment
    if (pod != null && mounted) {
      await _loadShipment();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery completed successfully!')),
        );
      }
    }
  }

  Future<void> _reportIssue() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Issue'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Describe the issue',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true || controller.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // In a real app, this would create a support ticket or delivery event
      await Supabase.instance.client
          .from('shipments')
          .update({
            'status': 'issue_reported',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', widget.shipmentId);

      await _loadShipment();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue reported to dispatch')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to report issue: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery ${widget.shipmentId.substring(0, 8)}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadShipment,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _shipment == null
          ? const Center(child: Text('Shipment not found'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shipment Details',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        _DetailRow(label: 'Status', value: _shipment!.status),
                        if (_shipment!.orderId != null)
                          _DetailRow(
                            label: 'Order ID',
                            value: _shipment!.orderId!.substring(0, 8),
                          ),
                        if (_shipment!.trackingNumber != null)
                          _DetailRow(
                            label: 'Tracking',
                            value: _shipment!.trackingNumber!,
                          ),
                        if (_shipment!.carrier != null)
                          _DetailRow(
                            label: 'Carrier',
                            value: _shipment!.carrier!,
                          ),
                        _DetailRow(
                          label: 'Updated',
                          value: _formatDateTime(_shipment!.updatedAt),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_shipment!.acceptedByStaffId == null)
                  ElevatedButton.icon(
                    onPressed: _acceptJob,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Accept Job'),
                  )
                else if (_shipment!.acceptedByStaffId == widget.staffId &&
                    _shipment!.status != 'delivered') ...[
                  ElevatedButton.icon(
                    onPressed: _completeJob,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture Proof of Delivery'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _reportIssue,
                    icon: const Icon(Icons.report_problem_outlined),
                    label: const Text('Report Issue'),
                  ),
                ] else if (_shipment!.status == 'delivered')
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Delivery completed',
                              style: TextStyle(
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class ShipmentDetail {
  ShipmentDetail({
    required this.id,
    this.orderId,
    required this.vendorId,
    required this.status,
    required this.visibility,
    this.trackingNumber,
    this.carrier,
    this.acceptedByStaffId,
    required this.updatedAt,
  });

  final String id;
  final String? orderId;
  final String vendorId;
  final String status;
  final String visibility;
  final String? trackingNumber;
  final String? carrier;
  final String? acceptedByStaffId;
  final DateTime updatedAt;

  factory ShipmentDetail.fromMap(Map<String, dynamic> map) {
    return ShipmentDetail(
      id: map['id'] as String,
      orderId: map['order_id'] as String?,
      vendorId: map['vendor_id'] as String,
      status: map['status'] as String? ?? 'pending',
      visibility: map['visibility'] as String? ?? 'private',
      trackingNumber: map['tracking_number'] as String?,
      carrier: map['carrier'] as String?,
      acceptedByStaffId: map['accepted_by_staff_id'] as String?,
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
