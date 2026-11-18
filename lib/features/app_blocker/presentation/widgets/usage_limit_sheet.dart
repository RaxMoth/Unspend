import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/design_tokens.dart';
import 'package:unspend/core/widgets/app_sheet.dart';

import '../profile_formatters.dart';
import 'section_widgets.dart';

const _minMinutes = 1;
const _maxMinutes = 24 * 60 - 1;

/// The daily limit of the usage-limit rule; opens the duration picker.
class UsageLimitCard extends StatelessWidget {
  const UsageLimitCard({
    super.key,
    required this.minutes,
    required this.accent,
    required this.onTap,
  });

  final int minutes;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.current.dailyLimit,
                    style: TextStyle(
                      color: kTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      formatDurationMinutes(minutes),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kReadable(accent),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: kTextSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets the user choose a daily limit between 1 minute and 23 h 59 min.
/// Returns the chosen minutes, or null when cancelled.
Future<int?> showUsageLimitSheet(
  BuildContext context, {
  required int initialMinutes,
  required Color accent,
}) => showAppSheet<int>(
  context: context,
  title: S.current.dailyLimit,
  builder: (_) =>
      _UsageLimitPicker(initialMinutes: initialMinutes, accent: accent),
);

enum _PickerMode { wheel, keypad }

/// Two ways to enter the duration: a wheel for quick scrubbing and a keypad
/// for an exact value such as 13 minutes. The last used mode is remembered
/// for the session.
class _UsageLimitPicker extends StatefulWidget {
  const _UsageLimitPicker({required this.initialMinutes, required this.accent});

  final int initialMinutes;
  final Color accent;

  @override
  State<_UsageLimitPicker> createState() => _UsageLimitPickerState();
}

class _UsageLimitPickerState extends State<_UsageLimitPicker> {
  static _PickerMode _lastUsedMode = _PickerMode.wheel;

  late _PickerMode _mode = _lastUsedMode;
  late int _minutes = widget.initialMinutes.clamp(_minMinutes, _maxMinutes);
  late final _hoursController = TextEditingController(
    text: '${_minutes ~/ 60}',
  );
  late final _minutesController = TextEditingController(
    text: '${_minutes % 60}',
  );

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _save() {
    if (_mode == _PickerMode.keypad) {
      final hours = int.tryParse(_hoursController.text.trim()) ?? 0;
      final minutes = int.tryParse(_minutesController.text.trim()) ?? 0;
      _minutes = (hours * 60 + minutes).clamp(_minMinutes, _maxMinutes);
    }
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(_minutes);
  }

  Widget _modeLabel(String text, _PickerMode mode) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        style: TextStyle(
          color: _mode == mode ? kFilled(widget.accent).onFill : kTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final filled = kFilled(accent);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoSlidingSegmentedControl<_PickerMode>(
          groupValue: _mode,
          backgroundColor: kBorder,
          thumbColor: filled.fill,
          onValueChanged: (mode) {
            if (mode == null) return;
            HapticFeedback.selectionClick();
            setState(() {
              _mode = mode;
              _lastUsedMode = mode;
            });
          },
          children: {
            _PickerMode.wheel: _modeLabel(
              S.current.pickerModeWheel,
              _PickerMode.wheel,
            ),
            _PickerMode.keypad: _modeLabel(
              S.current.pickerModeKeypad,
              _PickerMode.keypad,
            ),
          },
        ),
        const SizedBox(height: 16),
        if (_mode == _PickerMode.wheel)
          SizedBox(
            height: 180,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(context).brightness,
                textTheme: CupertinoTextThemeData(
                  pickerTextStyle: TextStyle(color: kTextPrimary, fontSize: 20),
                ),
              ),
              // The wheel has a fixed geometry; scaled text would be clipped.
              child: MediaQuery.withNoTextScaling(
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hm,
                  initialTimerDuration: Duration(minutes: _minutes),
                  onTimerDurationChanged: (duration) {
                    _minutes = duration.inMinutes.clamp(
                      _minMinutes,
                      _maxMinutes,
                    );
                  },
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NumberField(
                  controller: _hoursController,
                  label: S.current.hoursShort,
                  max: 23,
                  accent: accent,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: ExcludeSemantics(
                    child: Text(
                      ':',
                      style: TextStyle(
                        color: kTextPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                _NumberField(
                  controller: _minutesController,
                  label: S.current.minutesShort,
                  max: 59,
                  accent: accent,
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  S.current.cancel,
                  style: TextStyle(color: kTextSecondary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: filled.fill,
                  foregroundColor: filled.onFill,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  S.current.save,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.max,
    required this.accent,
  });

  final TextEditingController controller;
  final String label;
  final int max;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 96,
          child: Semantics(
            label: label,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 2,
              style: TextStyle(
                color: kTextPrimary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _MaxValueFormatter(max),
              ],
              decoration: InputDecoration(
                counterText: '',
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accent, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        ExcludeSemantics(
          child: Text(
            label,
            style: TextStyle(
              color: kTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Caps a number being typed at [max]: typing or pasting 99 gives 23 or 59.
class _MaxValueFormatter extends TextInputFormatter {
  _MaxValueFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final value = int.tryParse(newValue.text);
    if (value == null) return oldValue;
    if (value <= max) return newValue;
    final capped = '$max';
    return TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
    );
  }
}
