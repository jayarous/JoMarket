import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../seller_models.dart';
import '../seller_repository.dart';

/// Screen for managing vendor KYC/compliance documents
class KycManagementScreen extends StatefulWidget {
  const KycManagementScreen({
    required this.vendorId,
    required this.vendorName,
    required this.repository,
    super.key,
  });

  final String vendorId;
  final String vendorName;
  final SellerRepository repository;

  @override
  State<KycManagementScreen> createState() => _KycManagementScreenState();
}

class _KycManagementScreenState extends State<KycManagementScreen> {
  bool _isLoading = true;
  String? _error;
  VendorKycStatus? _kycStatus;
  bool _isLoadingConnect = true;
  String? _connectError;
  SellerConnectStatus? _connectStatus;

  final _taxIdController = TextEditingController();
  String? _businessLicensePath;
  String? _additionalDocsPath;

  @override
  void initState() {
    super.initState();
    _loadKycStatus();
    _loadConnectStatus();
  }

  @override
  void dispose() {
    _taxIdController.dispose();
    super.dispose();
  }

  Future<void> _loadKycStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final status = await widget.repository.getVendorKycStatus(
        widget.vendorId,
      );
      setState(() {
        _kycStatus = status;
        if (status != null) {
          _taxIdController.text = status.taxId ?? '';
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _copyOnboardingLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stripe onboarding link copied')),
    );
  }

  Widget _buildConnectCard(ThemeData theme) {
    if (_isLoadingConnect) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_connectError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stripe payouts unavailable',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 8),
              Text(_connectError!),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadConnectStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final status = _connectStatus;
    if (status == null) {
      return const SizedBox.shrink();
    }

    final chips = <Widget>[
      Chip(
        label: Text(
          status.chargesEnabled ? 'Charges enabled' : 'Charges disabled',
          style: TextStyle(
            color: status.chargesEnabled ? Colors.green : Colors.orange,
          ),
        ),
      ),
      Chip(
        label: Text(
          status.payoutsEnabled ? 'Payouts enabled' : 'Payouts disabled',
          style: TextStyle(
            color: status.payoutsEnabled ? Colors.green : Colors.orange,
          ),
        ),
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Stripe Connect',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
            if (status.requirementsDue.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Outstanding requirements:',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...status.requirementsDue.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
              ),
            ],
            if (status.onboardingUrl != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _copyOnboardingLink(status.onboardingUrl!),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Continue Stripe Onboarding'),
              ),
              const SizedBox(height: 8),
              Text(
                'Copy link and open it in a secure browser to resume verification.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadConnectStatus() async {
    setState(() {
      _isLoadingConnect = true;
      _connectError = null;
    });

    try {
      final status = await widget.repository.getStripeConnectStatus(
        vendorId: widget.vendorId,
        returnUrl: Uri.parse(
          'https://app.jomarket.local/vendors/${widget.vendorId}/payouts/complete',
        ),
        refreshUrl: Uri.parse(
          'https://app.jomarket.local/vendors/${widget.vendorId}/payouts/retry',
        ),
      );
      if (!mounted) return;
      setState(() => _connectStatus = status);
    } catch (e) {
      if (!mounted) return;
      setState(() => _connectError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingConnect = false);
      }
    }
  }

  Future<void> _pickFile(String type) async {
    // In a production app, integrate with image_picker or file_picker
    // For now, show a placeholder dialog
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Upload'),
        content: const Text(
          'File upload functionality will be integrated with your file picker implementation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // Simulate file selection
    setState(() {
      if (type == 'license') {
        _businessLicensePath =
            'business_license_${DateTime.now().millisecondsSinceEpoch}.pdf';
      } else {
        _additionalDocsPath =
            'additional_docs_${DateTime.now().millisecondsSinceEpoch}.pdf';
      }
    });
  }

  Future<void> _submitKyc() async {
    if (_businessLicensePath == null || _taxIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide all required documents'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // In production, you would upload files to storage first
      // For now, we're just storing the file paths
      await widget.repository.submitKycDocuments(
        vendorId: widget.vendorId,
        businessLicense: _businessLicensePath!,
        taxId: _taxIdController.text,
        additionalDocs: _additionalDocsPath,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('KYC documents submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _loadKycStatus();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting KYC: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
            const Text('KYC & Compliance'),
            Text(widget.vendorName, style: theme.textTheme.labelSmall),
          ],
        ),
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
                  const Text('Error loading KYC status'),
                  Text(_error!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadKycStatus,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildConnectCard(theme),
                  const SizedBox(height: 16),
                  // Status card
                  if (_kycStatus != null) ...[
                    Card(
                      color: _kycStatus!.isApproved
                          ? Colors.green.withValues(alpha: 0.1)
                          : _kycStatus!.isRejected
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _kycStatus!.isApproved
                                      ? Icons.check_circle
                                      : _kycStatus!.isRejected
                                      ? Icons.cancel
                                      : Icons.pending,
                                  color: _kycStatus!.isApproved
                                      ? Colors.green
                                      : _kycStatus!.isRejected
                                      ? Colors.red
                                      : Colors.orange,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _kycStatus!.isApproved
                                            ? 'Verification Approved'
                                            : _kycStatus!.isRejected
                                            ? 'Verification Rejected'
                                            : 'Verification Pending',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      if (_kycStatus!.submittedAt != null)
                                        Text(
                                          'Submitted: ${_kycStatus!.submittedAt!.toLocal().toString().split(' ')[0]}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_kycStatus!.rejectionReason != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Rejection Reason:',
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onErrorContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _kycStatus!.rejectionReason!,
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Info card
                  Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Complete your KYC verification',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'To comply with local regulations and process payments, please provide the following documents:',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form
                  Text(
                    'Required Documents',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tax ID
                  TextField(
                    controller: _taxIdController,
                    decoration: const InputDecoration(
                      labelText: 'Tax ID / Business Registration Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                      helperText:
                          'Enter your official tax identification number',
                    ),
                    enabled: _kycStatus == null || !_kycStatus!.isApproved,
                  ),
                  const SizedBox(height: 16),

                  // Business License
                  _DocumentPicker(
                    label: 'Business License',
                    required: true,
                    filePath: _businessLicensePath,
                    existingUrl: _kycStatus?.businessLicenseUrl,
                    onPick: () => _pickFile('license'),
                    enabled: _kycStatus == null || !_kycStatus!.isApproved,
                  ),
                  const SizedBox(height: 16),

                  // Additional Documents
                  _DocumentPicker(
                    label: 'Additional Documents (Optional)',
                    required: false,
                    filePath: _additionalDocsPath,
                    existingUrl: _kycStatus?.additionalDocuments,
                    onPick: () => _pickFile('additional'),
                    enabled: _kycStatus == null || !_kycStatus!.isApproved,
                  ),
                  const SizedBox(height: 32),

                  // Submit button
                  if (_kycStatus == null ||
                      _kycStatus!.isRejected ||
                      !_kycStatus!.isApproved)
                    FilledButton(
                      onPressed: _submitKyc,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(
                        _kycStatus == null
                            ? 'Submit for Verification'
                            : 'Resubmit Documents',
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Guidelines
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Document Guidelines',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...[
                            'Documents must be clear and legible',
                            'Accepted formats: PDF, JPG, PNG',
                            'Maximum file size: 10MB per document',
                            'Documents must be valid and not expired',
                            'Processing time: 2-5 business days',
                          ].map((guideline) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(guideline)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DocumentPicker extends StatelessWidget {
  const _DocumentPicker({
    required this.label,
    required this.required,
    required this.filePath,
    required this.existingUrl,
    required this.onPick,
    required this.enabled,
  });

  final String label;
  final bool required;
  final String? filePath;
  final String? existingUrl;
  final VoidCallback onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = filePath != null || existingUrl != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (required)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Required',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasFile) ...[
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      filePath?.split('/').last ??
                          existingUrl?.split('/').last ??
                          'Document uploaded',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (enabled) const SizedBox(height: 8),
            ],
            if (enabled)
              OutlinedButton.icon(
                onPressed: onPick,
                icon: Icon(hasFile ? Icons.refresh : Icons.upload_file),
                label: Text(hasFile ? 'Replace Document' : 'Upload Document'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
