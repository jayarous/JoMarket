import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'delivery_service.dart';

/// Proof of delivery capture screen
class ProofOfDeliveryScreen extends StatefulWidget {
  const ProofOfDeliveryScreen({
    required this.shipmentId,
    required this.staffId,
    required this.service,
    super.key,
  });

  final String shipmentId;
  final String staffId;
  final DeliveryService service;

  @override
  State<ProofOfDeliveryScreen> createState() => _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends State<ProofOfDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isSubmitting = false;
  String? _signatureUrl;
  final List<String> _photoUrls = [];
  final List<File> _photoFiles = [];
  String _deliveryCondition = 'good';

  @override
  void dispose() {
    _recipientNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (photo != null) {
      setState(() => _isSubmitting = true);
      try {
        final file = File(photo.path);
        final url = await _uploadFile(
          file,
          'delivery_photos',
          'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        setState(() {
          _photoUrls.add(url);
          _photoFiles.add(file);
          _isSubmitting = false;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to upload photo: $e')));
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  Future<String> _uploadFile(File file, String bucket, String fileName) async {
    final path = '${widget.shipmentId}/$fileName';
    await Supabase.instance.client.storage
        .from(bucket)
        .upload(path, file, fileOptions: const FileOptions(upsert: true));

    return Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Get current location if possible
      double? latitude;
      double? longitude;

      final pod = await widget.service.createProofOfDelivery(
        shipmentId: widget.shipmentId,
        staffId: widget.staffId,
        recipientName: _recipientNameController.text.trim(),
        recipientSignatureUrl: _signatureUrl,
        photoUrls: _photoUrls.isNotEmpty ? _photoUrls : null,
        latitude: latitude,
        longitude: longitude,
        notes: _notesController.text.trim(),
        deliveryCondition: _deliveryCondition,
      );

      if (mounted) {
        Navigator.of(context).pop(pod);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit proof of delivery: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Proof of Delivery')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Delivery Confirmation', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Capture proof of delivery for shipment ${widget.shipmentId.substring(0, 8)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _recipientNameController,
              decoration: const InputDecoration(
                labelText: 'Recipient Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter recipient name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _deliveryCondition,
              decoration: const InputDecoration(
                labelText: 'Delivery Condition',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2),
              ),
              items: const [
                DropdownMenuItem(value: 'good', child: Text('Good Condition')),
                DropdownMenuItem(value: 'damaged', child: Text('Damaged')),
                DropdownMenuItem(
                  value: 'partial',
                  child: Text('Partial Delivery'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _deliveryCondition = value);
                }
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Delivery Photos',
                          style: theme.textTheme.titleMedium,
                        ),
                        FilledButton.icon(
                          onPressed: _isSubmitting ? null : _capturePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Add Photo'),
                        ),
                      ],
                    ),
                    if (_photoFiles.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _photoFiles.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file = entry.value;
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  file,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  icon: const Icon(Icons.close),
                                  iconSize: 20,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _photoFiles.removeAt(index);
                                      _photoUrls.removeAt(index);
                                    });
                                  },
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'No photos added (optional)',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Delivery Notes',
                border: OutlineInputBorder(),
                hintText: 'Any additional notes or observations...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(
                _isSubmitting ? 'Submitting...' : 'Complete Delivery',
              ),
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
          ],
        ),
      ),
    );
  }
}
