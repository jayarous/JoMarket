import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShipmentEditScreen extends StatefulWidget {
  const ShipmentEditScreen({
    required this.vendorId,
    required this.shipmentId,
    super.key,
  });

  final String vendorId;
  final String shipmentId;

  @override
  State<ShipmentEditScreen> createState() => _ShipmentEditScreenState();
}

class _ShipmentEditScreenState extends State<ShipmentEditScreen> {
  ShipmentDetail? _shipment;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
            'id,order_id,status,visibility,tracking_number,carrier,updated_at',
          )
          .eq('id', widget.shipmentId)
          .eq('vendor_id', widget.vendorId)
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

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client
          .from('shipments')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', widget.shipmentId);

      await _loadShipment();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shipment updated to $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateVisibility(String newVisibility) async {
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client
          .from('shipments')
          .update({
            'visibility': newVisibility,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', widget.shipmentId);

      await _loadShipment();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Visibility set to $newVisibility')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update visibility: $e')),
        );
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
        title: Text('Shipment ${widget.shipmentId.substring(0, 8)}'),
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
                        _DetailRow(label: 'Shipment ID', value: _shipment!.id),
                        if (_shipment!.orderId != null)
                          _DetailRow(
                            label: 'Order ID',
                            value: _shipment!.orderId!,
                          ),
                        _DetailRow(label: 'Status', value: _shipment!.status),
                        _DetailRow(
                          label: 'Visibility',
                          value: _shipment!.visibility,
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
                Text(
                  'Update Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label: 'Pending',
                      onTap: () => _updateStatus('pending'),
                    ),
                    _StatusChip(
                      label: 'Assigned',
                      onTap: () => _updateStatus('assigned'),
                    ),
                    _StatusChip(
                      label: 'In Transit',
                      onTap: () => _updateStatus('in_transit'),
                    ),
                    _StatusChip(
                      label: 'Delivered',
                      onTap: () => _updateStatus('delivered'),
                    ),
                    _StatusChip(
                      label: 'Cancelled',
                      onTap: () => _updateStatus('cancelled'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Visibility',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Private'),
                      selected: _shipment!.visibility == 'private',
                      onSelected: (_) => _updateVisibility('private'),
                    ),
                    ChoiceChip(
                      label: const Text('Marketplace'),
                      selected: _shipment!.visibility == 'marketplace',
                      onSelected: (_) => _updateVisibility('marketplace'),
                    ),
                  ],
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
    required this.status,
    required this.visibility,
    this.trackingNumber,
    this.carrier,
    required this.updatedAt,
  });

  final String id;
  final String? orderId;
  final String status;
  final String visibility;
  final String? trackingNumber;
  final String? carrier;
  final DateTime updatedAt;

  factory ShipmentDetail.fromMap(Map<String, dynamic> map) {
    return ShipmentDetail(
      id: map['id'] as String,
      orderId: map['order_id'] as String?,
      status: map['status'] as String? ?? 'pending',
      visibility: map['visibility'] as String? ?? 'private',
      trackingNumber: map['tracking_number'] as String?,
      carrier: map['carrier'] as String?,
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
            width: 120,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}
