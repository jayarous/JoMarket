import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShippingSettingsScreen extends StatefulWidget {
  const ShippingSettingsScreen({required this.vendorId, super.key});

  final String vendorId;

  @override
  State<ShippingSettingsScreen> createState() => _ShippingSettingsScreenState();
}

class _ShippingSettingsScreenState extends State<ShippingSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _flatRateController = TextEditingController();
  final _expressRateController = TextEditingController();
  final _freeThresholdController = TextEditingController();
  final _markupController = TextEditingController();

  bool _useLiveRates = false;
  String _currency = 'JOD';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _flatRateController.dispose();
    _expressRateController.dispose();
    _freeThresholdController.dispose();
    _markupController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('shipping_settings')
          .select(
            'currency,use_live_rates,flat_rate_cents,express_rate_cents,free_shipping_threshold_cents,live_rate_markup_percent',
          )
          .eq('vendor_id', widget.vendorId)
          .maybeSingle();

      final settings = response as Map<String, dynamic>?;
      _currency = settings?['currency'] as String? ?? 'JOD';
      _useLiveRates = settings?['use_live_rates'] as bool? ?? false;
      _flatRateController.text =
          _centsToString(settings?['flat_rate_cents'] as int? ?? 250);
      _expressRateController.text =
          _centsToString(settings?['express_rate_cents'] as int? ?? 450);
      _freeThresholdController.text = _centsToString(
        settings?['free_shipping_threshold_cents'] as int? ?? 10000,
      );
      _markupController.text = (settings?['live_rate_markup_percent'] as num?)
              ?.toStringAsFixed(2) ??
          '0';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final flatCents = _stringToCents(_flatRateController.text);
      final expressCents = _stringToCents(_expressRateController.text);
      final thresholdCents =
          _freeThresholdController.text.trim().isEmpty ? null : _stringToCents(
            _freeThresholdController.text,
          );
      final markup =
          double.tryParse(_markupController.text.trim()) ?? 0.0;

      await Supabase.instance.client
          .from('shipping_settings')
          .upsert({
            'vendor_id': widget.vendorId,
            'currency': _currency,
            'use_live_rates': _useLiveRates,
            'flat_rate_cents': flatCents,
            'express_rate_cents': expressCents,
            'free_shipping_threshold_cents': thresholdCents,
            'live_rate_markup_percent': markup,
            'updated_by': userId,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shipping settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _centsToString(int cents) {
    return (cents / 100).toStringAsFixed(2);
  }

  int _stringToCents(String value) {
    return (double.parse(value.trim()) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipping settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text(
                      'Control shopper-facing shipping fees. Saved values are used by checkout-quote before falling back to live carrier rates.',
                    ),
                    const SizedBox(height: 16),
                    _buildCurrencyField(),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _useLiveRates,
                      title: const Text('Use live carrier rates'),
                      subtitle: const Text(
                        'When on, Shippo rates are shown first (with optional markup/discount). When off, flat/express values below are used.',
                      ),
                      onChanged: (value) {
                        setState(() => _useLiveRates = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMoneyField(
                            controller: _flatRateController,
                            label: 'Standard rate',
                            helper: 'Displayed as the default option.',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMoneyField(
                            controller: _expressRateController,
                            label: 'Express rate',
                            helper: 'Optional faster service.',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildMoneyField(
                      controller: _freeThresholdController,
                      label: 'Free shipping threshold',
                      helper: 'Leave blank to disable. Applies when subtotal meets threshold.',
                      allowEmpty: true,
                    ),
                    const SizedBox(height: 12),
                    if (_useLiveRates)
                      _buildPercentageField(
                        controller: _markupController,
                        label: 'Live-rate markup %',
                        helper: 'Negative to discount. Applied to Shippo totals.',
                      ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save settings'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCurrencyField() {
    return TextFormField(
      readOnly: true,
      initialValue: _currency,
      decoration: const InputDecoration(
        labelText: 'Currency',
        helperText: 'Defaults to JOD for now.',
      ),
    );
  }

  Widget _buildMoneyField({
    required TextEditingController controller,
    required String label,
    String? helper,
    bool allowEmpty = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixText: '$_currency ',
      ),
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) {
          return allowEmpty ? null : 'Required';
        }
        final parsed = double.tryParse(trimmed);
        if (parsed == null || parsed < 0) {
          return 'Enter a positive amount';
        }
        return null;
      },
    );
  }

  Widget _buildPercentageField({
    required TextEditingController controller,
    required String label,
    String? helper,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        suffixText: '%',
      ),
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) return null;
        final parsed = double.tryParse(trimmed);
        if (parsed == null) {
          return 'Enter a number';
        }
        if (parsed < -100) {
          return 'Cannot go below -100%';
        }
        return null;
      },
    );
  }
}
