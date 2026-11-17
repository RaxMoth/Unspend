import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/core/theme/design_tokens.dart';
import 'package:unspend/core/widgets/pin_field.dart';

import '../../data/repositories/pin_repository.dart';

/// What the user is trying to do behind the gate. Decides the wording.
enum PinGatePurpose {
  deactivate,
  changePin,
  deleteAllData,
  changeDeviceMode,
  uninstallProtection,
}

/// Makes the user earn an action that weakens a block.
///
/// With [withCooldown] the user first waits out the cooldown; then the PIN
/// is checked if one is set. Without a PIN, deactivating asks for a plain
/// confirmation instead. Returns true when the user got through.
Future<bool> showPinGate(
  BuildContext context, {
  required PinGatePurpose purpose,
  required bool withCooldown,
}) async {
  final passed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PinGateDialog(purpose: purpose, withCooldown: withCooldown),
  );
  return passed ?? false;
}

enum _Step { cooldown, loading, pin, confirm }

class PinGateDialog extends ConsumerStatefulWidget {
  const PinGateDialog({
    super.key,
    required this.purpose,
    required this.withCooldown,
  });

  final PinGatePurpose purpose;
  final bool withCooldown;

  @override
  ConsumerState<PinGateDialog> createState() => _PinGateDialogState();
}

class _PinGateDialogState extends ConsumerState<PinGateDialog> {
  final _pinController = TextEditingController();
  Timer? _timer;

  late final int _cooldownSeconds;
  late int _remainingSeconds;
  _Step _step = _Step.loading;
  String? _pinError;
  bool _checking = false;

  PinRepository get _pins => ref.read(pinRepositoryProvider);
  bool get _isDeactivation => widget.purpose == PinGatePurpose.deactivate;

  @override
  void initState() {
    super.initState();
    _cooldownSeconds = widget.withCooldown
        ? ref.read(cooldownDurationProvider).inSeconds
        : 0;
    _remainingSeconds = _cooldownSeconds;
    if (_cooldownSeconds > 0) {
      _step = _Step.cooldown;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else {
      _afterCooldown();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _remainingSeconds--);
    if (_remainingSeconds <= 0) {
      _timer?.cancel();
      _afterCooldown();
    }
  }

  Future<void> _afterCooldown() async {
    if (mounted && _step != _Step.loading) {
      setState(() => _step = _Step.loading);
    }
    final hasPin = await _pins.hasPin();
    if (!mounted) return;
    if (!hasPin) {
      // Nothing to check. Deactivating still asks once; the other actions
      // have their own confirmation before the gate.
      if (_isDeactivation) {
        setState(() => _step = _Step.confirm);
      } else {
        Navigator.of(context).pop(true);
      }
      return;
    }
    final lockout = await _pins.lockoutRemaining();
    if (!mounted) return;
    setState(() {
      _step = _Step.pin;
      _pinError = lockout == null ? null : _lockoutMessage(lockout);
    });
  }

  String _lockoutMessage(Duration remaining) =>
      S.current.pinLockedOut((remaining.inMilliseconds / 1000).ceil());

  Future<void> _checkPin() async {
    if (_checking) return;
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _pinError = S.current.enterYourPin);
      return;
    }
    setState(() => _checking = true);
    final result = await _pins.verify(pin);
    if (!mounted) return;
    switch (result) {
      case PinCorrect():
        Navigator.of(context).pop(true);
      case PinWrong():
        _pinController.clear();
        setState(() {
          _checking = false;
          _pinError = S.current.incorrectPin;
        });
      case PinLockedOut(:final remaining):
        _pinController.clear();
        setState(() {
          _checking = false;
          _pinError = _lockoutMessage(remaining);
        });
    }
  }

  String get _title => switch ((_step, widget.purpose)) {
    (_Step.pin, PinGatePurpose.deactivate) => S.current.enterPinToDeactivate,
    (_Step.confirm, _) => S.current.confirmDeactivation,
    (_, PinGatePurpose.deactivate) => S.current.deactivateAction,
    (_, PinGatePurpose.changePin) => S.current.changePin,
    (_, PinGatePurpose.deleteAllData) => S.current.deleteAllData,
    (_, PinGatePurpose.changeDeviceMode) => S.current.whoUsesLabel,
    (_, PinGatePurpose.uninstallProtection) => S.current.uninstallProtection,
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      backgroundColor: kSurface,
      title: Text(_title, style: TextStyle(color: kTextPrimary, fontSize: 18)),
      content: switch (_step) {
        _Step.cooldown => _Countdown(
          remainingSeconds: _remainingSeconds,
          totalSeconds: _cooldownSeconds,
          message: _isDeactivation
              ? S.current.cooldownDescription
              : S.current.cooldownGeneric,
        ),
        _Step.loading => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(color: kAccent)),
        ),
        _Step.pin => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              S.current.enterTrustedPersonPin,
              style: TextStyle(color: kTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            PinField(
              controller: _pinController,
              label: S.current.pinLabel,
              errorText: _pinError,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _checkPin(),
            ),
          ],
        ),
        _Step.confirm => Text(
          S.current.areYouSureDeactivate,
          style: TextStyle(color: kTextSecondary, fontSize: 14),
        ),
      },
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            S.current.cancel,
            style: TextStyle(color: kTextSecondary),
          ),
        ),
        if (_step == _Step.pin || _step == _Step.confirm)
          TextButton(
            onPressed: _checking
                ? null
                : _step == _Step.pin
                ? _checkPin
                : () => Navigator.of(context).pop(true),
            child: Text(
              _isDeactivation
                  ? S.current.deactivateAction
                  : S.current.continueLabel,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.message,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final String message;

  @override
  Widget build(BuildContext context) {
    final seconds = remainingSeconds.clamp(0, totalSeconds);
    final minutesText = (seconds ~/ 60).toString().padLeft(2, '0');
    final secondsText = (seconds % 60).toString().padLeft(2, '0');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$minutesText:$secondsText',
            style: const TextStyle(
              color: kAccent,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: kTextSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: totalSeconds == 0 ? 1 : 1 - seconds / totalSeconds,
            backgroundColor: kBg,
            valueColor: const AlwaysStoppedAnimation(kAccent),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
