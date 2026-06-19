import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static const separator = '.';

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String newValueText = newValue.text.replaceAll(separator, '');
    int? value = int.tryParse(newValueText);

    if (value == null) {
      return oldValue;
    }

    String newText = NumberFormat.currency(
            customPattern: '#,###', symbol: '', decimalDigits: 0)
        .format(value)
        .replaceAll(',', separator);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class ScannerTab extends StatefulWidget {
  const ScannerTab({super.key});

  @override
  State<ScannerTab> createState() => _ScannerTabState();
}

class _ScannerTabState extends State<ScannerTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  final _skuController = TextEditingController();
  final _colorController = TextEditingController();
  final _quantityController = TextEditingController();

  final FocusNode _skuFocusNode = FocusNode();
  final FocusNode _colorFocusNode = FocusNode();
  final FocusNode _quantityFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isCheckingSku = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _skuFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _skuController.dispose();
    _colorController.dispose();
    _quantityController.dispose();
    _skuFocusNode.dispose();
    _colorFocusNode.dispose();
    _quantityFocusNode.dispose();
    super.dispose();
  }

  void _showToast(String message, bool isSuccess) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
              ],
              border: Border(left: BorderSide(color: isSuccess ? Colors.green : Colors.red, width: 4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isSuccess ? Icons.check_circle : Icons.cancel, color: isSuccess ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  void _handleSkuSubmit() async {
    if (_skuController.text.isEmpty) {
      _showToast('Please scan/enter SKU code', false);
      return;
    }

    setState(() => _isCheckingSku = true);
    
    try {
      final response = await ApiService.checkSkuDuplicate(_skuController.text);
      if (response['isDuplicate'] == true) {
        _showToast('SKU ${_skuController.text} already exists!', false);
        _skuController.clear();
        _skuFocusNode.requestFocus();
      } else {
        setState(() => _currentStep = 1);
        _colorFocusNode.requestFocus();
      }
    } catch (e) {
      _showToast('Failed to verify SKU. Please try again.', false);
    } finally {
      if (mounted) setState(() => _isCheckingSku = false);
    }
  }

  void _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      int quantity = int.parse(_quantityController.text.replaceAll('.', ''));

      await ApiService.submitSku(
        skuCode: _skuController.text,
        color: _colorController.text,
        quantity: quantity,
      );

      if (mounted) {
        _showToast('Successfully submit', true);
        setState(() {
          _currentStep = 0;
          _skuController.clear();
          _colorController.clear();
          _quantityController.clear();
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _skuFocusNode.requestFocus();
        });
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        _showToast('Failed: $errorMessage', false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.05),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _currentStep == 0 ? _buildScanStep() : _buildFormStep(),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildScanStep() {
    return Card(
      key: const ValueKey('scan_step'),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner, size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            const Text(
              'Scan Barcode',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Focus the input below and scan a SKU to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _skuController,
              focusNode: _skuFocusNode,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'SKU Code *',
                hintText: 'e.g., SKU-12345',
                prefixIcon: Icon(Icons.qr_code),
              ),
              onSubmitted: _isCheckingSku ? null : (_) => _handleSkuSubmit(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCheckingSku ? null : _handleSkuSubmit,
                icon: _isCheckingSku 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_forward),
                label: Text(_isCheckingSku ? 'Verifying...' : 'Next Step'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormStep() {
    return Card(
      key: const ValueKey('form_step'),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha((255 * 0.05).toInt()),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withAlpha((255 * 0.2).toInt())),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Scanned SKU', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                          Text(
                            _skuController.text,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                      onPressed: () {
                        setState(() => _currentStep = 0);
                        _skuFocusNode.requestFocus();
                      },
                      tooltip: 'Edit SKU',
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Data Entry Form', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _colorController,
                focusNode: _colorFocusNode,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _quantityFocusNode.requestFocus(),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(5),
                ],
                decoration: const InputDecoration(
                  labelText: 'Color *',
                  hintText: 'Max 5 chars',
                  prefixIcon: Icon(Icons.color_lens_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value.length > 5) return 'Max 5 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                focusNode: _quantityFocusNode,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submitData(),
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Quantity *',
                  prefixIcon: Icon(Icons.calculate_outlined),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () {
                        setState(() => _currentStep = 0);
                        _skuFocusNode.requestFocus();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('Cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitData,
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Submit Data'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
