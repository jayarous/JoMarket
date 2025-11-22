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
      appBar: AppBar(
        title: const Text('Proof of Delivery'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildHeader(theme),
                  const SizedBox(height: 24),
                  _buildRecipientSection(theme),
                  const SizedBox(height: 24),
                  _buildConditionSection(theme),
                  const SizedBox(height: 24),
                  _buildPhotosSection(theme),
                  const SizedBox(height: 24),
                  _buildNotesSection(theme),
                ],
              ),
            ),
            _buildSubmitButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Confirmation',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Capture proof of delivery for shipment #${widget.shipmentId.substring(0, 8)}',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildRecipientSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recipient Details',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _recipientNameController,
          decoration: InputDecoration(
            labelText: 'Recipient Name',
            hintText: 'Who received the package?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.person_outline),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter recipient name';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildConditionSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Package Condition',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _deliveryCondition,
          decoration: InputDecoration(
            labelText: 'Condition',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.inventory_2_outlined),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          items: const [
            DropdownMenuItem(value: 'good', child: Text('Good Condition')),
            DropdownMenuItem(value: 'damaged', child: Text('Damaged')),
            DropdownMenuItem(value: 'partial', child: Text('Partial Delivery')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _deliveryCondition = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildPhotosSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Photos',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _isSubmitting ? null : _capturePhoto,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Add Photo'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_photoFiles.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _photoFiles.length,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _photoFiles[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _photoFiles.removeAt(index);
                          _photoUrls.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          )
        else
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.photo_camera_back, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No photos added',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Notes',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            hintText: 'Any observations...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'COMPLETE DELIVERY',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
