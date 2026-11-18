import 'package:flutter/material.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/design_tokens.dart';

import '../../domain/shield_policy.dart';
import '../profile_formatters.dart';
import 'section_widgets.dart';

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
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      // The picker follows the app's light or dark theme and takes the
      // profile's colour as its accent.
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(primary: accent),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final valid = ShieldPolicy.isValidSchedule(
      startMinute: _minuteOfDay(start),
      endMinute: _minuteOfDay(end),
    );
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time_rounded, color: accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.current.scheduleTitle,
                    style: TextStyle(
                      color: kTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TimeTile(
                    label: S.current.scheduleStart,
                    formatted: formatMinuteOfDay(_minuteOfDay(start)),
                    onTap: () => _pick(context, start, onStartChanged),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TimeTile(
                    label: S.current.scheduleEnd,
                    formatted: formatMinuteOfDay(_minuteOfDay(end)),
                    onTap: () => _pick(context, end, onEndChanged),
                  ),
                ),
              ],
            ),
            if (!valid) ...[
              const SizedBox(height: 10),
              Text(
                S.current.errorScheduleTooShort,
                style: TextStyle(color: kAccentText, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
