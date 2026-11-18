import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

import '../../domain/shield_policy.dart';
import '../profile_formatters.dart';

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
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: AppSizes.iconMd,
            color: context.colors.readable(accent),
          ),
          Gap.hSm,
          Expanded(
            child: Text(S.current.dailyLimit, style: context.text.label),
          ),
          Gap.hSm,
          // Shares the row with the label; the value stays at the trailing
          // edge and wraps when both are long.
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppChip(
                label: formatDurationMinutes(minutes),
                color: accent,
                prominent: true,
              ),
            ),
          ),
          Gap.hXs,
          const Icon(Icons.chevron_right_rounded, size: AppSizes.iconMd),
        ],
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
  static const double _wheelHeight = 180;
  static const int _maxHours = 23;
  static const int _maxMinutesPart = 59;

  static _PickerMode _lastUsedMode = _PickerMode.wheel;

  late _PickerMode _mode = _lastUsedMode;
  late int _minutes = _clamp(widget.initialMinutes);
  late final _hoursController = TextEditingController(
    text: '${_minutes ~/ 60}',
  );
  late final _minutesController = TextEditingController(
    text: '${_minutes % 60}',
  );

  static int _clamp(int minutes) => minutes.clamp(
    ShieldPolicy.minUsageLimitMinutes,
    ShieldPolicy.maxUsageLimitMinutes,
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
      _minutes = _clamp(hours * 60 + minutes);
    }
    AppHaptics.confirm();
    Navigator.of(context).pop(_minutes);
  }

  Widget _modeLabel(String label, _PickerMode mode, FilledColors filled) =>
      Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: context.text.body.strong.tone(
              _mode == mode ? filled.onFill : context.colors.textPrimary,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final colors = context.colors;
    final text = context.text;
    final accent = widget.accent;
    final filled = colors.filled(accent);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoSlidingSegmentedControl<_PickerMode>(
          groupValue: _mode,
          backgroundColor: colors.border,
          thumbColor: filled.fill,
          onValueChanged: (mode) {
            if (mode == null) return;
            AppHaptics.selection();
            setState(() {
              _mode = mode;
              _lastUsedMode = mode;
            });
          },
          children: {
            _PickerMode.wheel: _modeLabel(
              s.pickerModeWheel,
              _PickerMode.wheel,
              filled,
            ),
            _PickerMode.keypad: _modeLabel(
              s.pickerModeKeypad,
              _PickerMode.keypad,
              filled,
            ),
          },
        ),
        Gap.vLg,
        if (_mode == _PickerMode.wheel)
          SizedBox(
            height: _wheelHeight,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: colors.brightness,
                textTheme: CupertinoTextThemeData(pickerTextStyle: text.title),
              ),
              // The wheel has a fixed geometry; scaled text would be clipped.
              child: MediaQuery.withNoTextScaling(
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hm,
                  initialTimerDuration: Duration(minutes: _minutes),
                  onTimerDurationChanged: (duration) {
                    _minutes = _clamp(duration.inMinutes);
                  },
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: _NumberField(
                    controller: _hoursController,
                    label: s.hoursShort,
                    max: _maxHours,
                    accent: accent,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: ExcludeSemantics(
                    child: Text(':', style: text.numeral),
                  ),
                ),
                Flexible(
                  child: _NumberField(
                    controller: _minutesController,
                    label: s.minutesShort,
                    max: _maxMinutesPart,
                    accent: accent,
                  ),
                ),
              ],
            ),
          ),
        Gap.vLg,
        Row(
          children: [
            Expanded(
              child: AppButton.secondary(
                label: s.cancel,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Gap.hMd,
            Expanded(
              child: AppButton.primary(
                label: s.save,
                color: accent,
                onPressed: _save,
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

  /// Widest the field gets; it narrows when the sheet is tight.
  static const double _maxWidth = 96;

  final TextEditingController controller;
  final String label;
  final int max;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Semantics(
            label: label,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 2,
              style: text.numeral,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _MaxValueFormatter(max),
              ],
              decoration: InputDecoration(
                counterText: '',
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.control,
                  borderSide: BorderSide(
                    color: colors.readable(accent),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.sm,
                ),
              ),
            ),
          ),
        ),
        Gap.vXs,
        ExcludeSemantics(
          child: Text(
            label,
            style: text.caption.strong.tone(colors.textSecondary),
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
