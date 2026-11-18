import 'package:flutter/material.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

import '../../domain/shield_policy.dart';
import '../profile_formatters.dart';

int _minuteOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

/// Start and end time of the schedule rule. Windows may cross midnight.
class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    required this.start,
    required this.end,
    required this.accent,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final TimeOfDay start;
  final TimeOfDay end;
  final Color accent;
  final ValueChanged<TimeOfDay> onStartChanged;
  final ValueChanged<TimeOfDay> onEndChanged;

  Future<void> _pick(
    BuildContext context,
    TimeOfDay initial,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final primary = context.colors.readable(accent);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      // The picker follows the app's theme and takes the profile's colour
      // as its accent.
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(primary: primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final colors = context.colors;
    final text = context.text;
    final valid = ShieldPolicy.isValidSchedule(
      startMinute: _minuteOfDay(start),
      endMinute: _minuteOfDay(end),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: AppSizes.iconMd,
                color: colors.readable(accent),
              ),
              Gap.hSm,
              Expanded(child: Text(s.scheduleTitle, style: text.label)),
            ],
          ),
          Gap.vMd,
          Row(
            children: [
              Expanded(
                child: _TimeTile(
                  label: s.scheduleStart,
                  time: start,
                  onTap: () => _pick(context, start, onStartChanged),
                ),
              ),
              Gap.hMd,
              Expanded(
                child: _TimeTile(
                  label: s.scheduleEnd,
                  time: end,
                  onTap: () => _pick(context, end, onEndChanged),
                ),
              ),
            ],
          ),
          if (!valid) ...[
            Gap.vSm,
            Text(
              s.errorScheduleTooShort,
              style: text.caption.tone(colors.accentText),
            ),
          ],
        ],
      ),
    );
  }
}

/// A tappable label + time, e.g. "Start 09:00".
class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final formatted = formatMinuteOfDay(_minuteOfDay(time));
    return Semantics(
      button: true,
      label: '$label $formatted',
      excludeSemantics: true,
      child: AppCard(
        inset: true,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.micro.tone(context.colors.textSecondary)),
              Gap.vXs,
              Text(formatted, style: text.heading),
            ],
          ),
        ),
      ),
    );
  }
}
