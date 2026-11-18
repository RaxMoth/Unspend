import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

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
  if (!isFrontmost(context)) return false;
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
    AppHaptics.confirm();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    return AppDialog(
      title: s.setPinTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.setPinDescription,
            style: context.text.bodySmall.tone(context.colors.textSecondary),
          ),
          Gap.vXl,
          PinField(
            controller: _pinController,
            label: s.enterPin,
            textInputAction: TextInputAction.next,
          ),
          Gap.vMd,
          PinField(
            controller: _confirmController,
            label: s.confirmPin,
            errorText: _error,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        DialogButton.cancel(label: widget.cancelLabel),
        DialogButton(label: s.savePin, onPressed: _saving ? null : _save),
      ],
    );
  }
}
