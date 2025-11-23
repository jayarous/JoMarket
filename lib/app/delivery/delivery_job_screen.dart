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
        elevation: 0,
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
                  : Column(
                      children: [
                        _buildStatusBanner(context),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildDetailsCard(context),
                              const SizedBox(height: 24),
                              if (_shipment!.acceptedByStaffId == null)
                                _buildAcceptButton(context)
                              else if (_shipment!.acceptedByStaffId == widget.staffId &&
                                  _shipment!.status != 'delivered') ...[
                                _buildActionButtons(context),
                              ] else if (_shipment!.status == 'delivered')
                                _buildCompletedState(context),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    final color = _getStatusColor(_shipment!.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: color.withAlpha(26),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 12),
          Text(
            'Status: ${_shipment!.status.toUpperCase()}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shipment Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            _DetailRow(
              label: 'Order ID',
              value: _shipment!.orderId?.substring(0, 8) ?? 'N/A',
              icon: Icons.receipt_long,
            ),
            const Divider(height: 24),
            _DetailRow(
              label: 'Tracking',
              value: _shipment!.trackingNumber ?? 'Not assigned',
              icon: Icons.qr_code,
            ),
            const Divider(height: 24),
            _DetailRow(
              label: 'Carrier',
              value: _shipment!.carrier ?? 'Standard',
              icon: Icons.local_shipping,
            ),
            const Divider(height: 24),
            _DetailRow(
              label: 'Last Update',
              value: _formatDateTime(_shipment!.updatedAt),
              icon: Icons.access_time,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _acceptJob,
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('ACCEPT JOB', style: TextStyle(fontSize: 16)),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _completeJob,
            icon: const Icon(Icons.camera_alt),
            label: const Text('CAPTURE PROOF OF DELIVERY', style: TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _reportIssue,
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('REPORT ISSUE', style: TextStyle(fontSize: 16)),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Completed',
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Great job! This shipment is closed.',
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'picked_up':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.grey[700]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
