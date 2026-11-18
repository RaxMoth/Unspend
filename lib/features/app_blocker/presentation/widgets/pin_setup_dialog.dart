import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/design_tokens.dart';
import 'package:unspend/core/widgets/pin_field.dart';

import '../../data/repositories/pin_repository.dart';

/// Lets a trusted person choose the PIN that is needed to lift a block.
///
/// [cancelLabel] is the wording of the way out ("Cancel" from Settings,
/// "Not now" when the app suggests setting a PIN). Returns true when a PIN
/// was saved.
Future<bool> showPinSetupDialog(
  BuildContext context, {
  required String cancelLabel,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PinSetupDialog(cancelLabel: cancelLabel),
  );
  return saved ?? false;
}

class PinSetupDialog extends ConsumerStatefulWidget {
  const PinSetupDialog({super.key, required this.cancelLabel});

  final String cancelLabel;

  @override
  ConsumerState<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends ConsumerState<PinSetupDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final pin = _pinController.text.trim();
    if (pin.length < PinRepository.minPinLength) {
      setState(() => _error = S.current.pinTooShort);
      return;
    }
    if (pin != _confirmController.text.trim()) {
      setState(() => _error = S.current.pinsMismatch);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(pinRepositoryProvider).setPin(pin);
    } catch (e) {
      debugPrint('[PinSetupDialog] Saving the PIN failed: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = S.current.errorTryAgain;
      });
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      backgroundColor: kSurface,
      title: Text(
        S.current.setPinTitle,
        style: TextStyle(color: kTextPrimary, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.current.setPinDescription,
            style: TextStyle(color: kTextSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          PinField(
            controller: _pinController,
            label: S.current.enterPin,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          PinField(
            controller: _confirmController,
            label: S.current.confirmPin,
            errorText: _error,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            widget.cancelLabel,
            style: TextStyle(color: kTextSecondary),
          ),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(
            S.current.savePin,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
