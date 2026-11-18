import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

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
  // A second tap while the gate is opening must not stack another one.
  if (!isFrontmost(context)) return false;
  final passed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PinGateDialog(purpose: purpose, withCooldown: withCooldown),
  );
  return passed ?? false;
}

enum _Step { cooldown, loading, pin, confirm, failed }

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
  static const _tick = Duration(seconds: 1);

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
      _timer = Timer.periodic(_tick, (_) => _onTick());
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

  void _onTick() {
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
    final bool hasPin;
    final Duration? lockout;
    try {
      hasPin = await _pins.hasPin();
      lockout = hasPin ? await _pins.lockoutRemaining() : null;
    } catch (e) {
      // The Keychain could not be read. Never treat that as "no PIN".
      debugPrint('[PinGate] Reading the PIN failed: $e');
      if (mounted) setState(() => _step = _Step.failed);
      return;
    }
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
    setState(() {
      _step = _Step.pin;
      _pinError = lockout == null ? null : _lockoutMessage(lockout);
    });
  }

  String _lockoutMessage(Duration remaining) => S.current.pinLockedOut(
    (remaining.inMilliseconds / Duration.millisecondsPerSecond).ceil(),
  );

  Future<void> _checkPin() async {
    if (_checking) return;
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _pinError = S.current.enterYourPin);
      return;
    }
    setState(() => _checking = true);
    final PinCheck result;
    try {
      result = await _pins.verify(pin);
    } catch (e) {
      debugPrint('[PinGate] Checking the PIN failed: $e');
      if (!mounted) return;
      setState(() {
        _checking = false;
        _pinError = S.current.errorTryAgain;
      });
      return;
    }
    if (!mounted) return;
    switch (result) {
      case PinCorrect():
        AppHaptics.confirm();
        Navigator.of(context).pop(true);
      case PinWrong():
        _rejectPin(S.current.incorrectPin);
      case PinLockedOut(:final remaining):
        _rejectPin(_lockoutMessage(remaining));
    }
  }

  void _rejectPin(String message) {
    AppHaptics.reject();
    _pinController.clear();
    setState(() {
      _checking = false;
      _pinError = message;
    });
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
    final s = S.current;
    final proceedLabel = _isDeactivation ? s.deactivateAction : s.continueLabel;
    return AppDialog(
      title: _title,
      content: switch (_step) {
        _Step.cooldown => _Countdown(
          remainingSeconds: _remainingSeconds,
          totalSeconds: _cooldownSeconds,
          message: _isDeactivation ? s.cooldownDescription : s.cooldownGeneric,
        ),
        _Step.loading => const AppLoader(),
        _Step.pin => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.enterTrustedPersonPin,
              style: context.text.bodySmall.tone(context.colors.textSecondary),
            ),
            Gap.vLg,
            PinField(
              controller: _pinController,
              label: s.pinLabel,
              errorText: _pinError,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _checkPin(),
            ),
          ],
        ),
        _Step.confirm => Text(s.areYouSureDeactivate),
        _Step.failed => Text(s.errorTryAgain),
      },
      actions: [
        DialogButton.cancel(label: s.cancel),
        switch (_step) {
          _Step.pin => DialogButton(
            label: proceedLabel,
            onPressed: _checking ? null : _checkPin,
          ),
          _Step.confirm => DialogButton(
            label: proceedLabel,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          _Step.failed => DialogButton(
            label: s.retry,
            onPressed: _afterCooldown,
          ),
          _Step.cooldown || _Step.loading => const SizedBox.shrink(),
        },
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
    final colors = context.colors;
    final text = context.text;
    final seconds = remainingSeconds.clamp(0, totalSeconds);
    final minutesText = (seconds ~/ Duration.secondsPerMinute)
        .toString()
        .padLeft(2, '0');
    final secondsText = (seconds % Duration.secondsPerMinute)
        .toString()
        .padLeft(2, '0');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Gap.vSm,
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$minutesText:$secondsText',
            style: text.display.tone(colors.accent),
          ),
        ),
        Gap.vMd,
        Text(
          message,
          textAlign: TextAlign.center,
          style: text.bodySmall.tone(colors.textSecondary),
        ),
        Gap.vLg,
        AppProgressBar(
          value: totalSeconds == 0 ? 1 : 1 - seconds / totalSeconds,
        ),
      ],
    );
  }
}
