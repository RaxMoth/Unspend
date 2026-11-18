import 'package:flutter/material.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

import '../providers/device_mode_provider.dart';

/// The two answers to "Who uses this iPhone?", as a pair of radio cards.
/// Used in onboarding and in Settings.
class DeviceModeOptions extends StatelessWidget {
  const DeviceModeOptions({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final DeviceMode selected;
  final ValueChanged<DeviceMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OptionCard(
          icon: Icons.person_rounded,
          title: s.modePersonalTitle,
          body: s.modePersonalBody,
          selected: selected == DeviceMode.personal,
          onTap: () => onSelected(DeviceMode.personal),
        ),
        Gap.vMd,
        _OptionCard(
          icon: Icons.child_care_rounded,
          title: s.modeChildTitle,
          body: s.modeChildBody,
          selected: selected == DeviceMode.child,
          onTap: () => onSelected(DeviceMode.child),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final iconColor = selected ? colors.accent : colors.textSecondary;
    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: '$title. $body',
      excludeSemantics: true,
      onTap: onTap,
      child: AppCard(
        tint: selected ? colors.accent : null,
        outline: selected ? colors.accent : null,
        emphasized: selected,
        onTap: onTap,
        excludeTapFromSemantics: true,
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            Gap.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.label),
                  Gap.vXxs,
                  Text(body, style: text.bodySmall.tone(colors.textSecondary)),
                ],
              ),
            ),
            Gap.hSm,
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: iconColor,
            ),
          ],
        ),
      ),
    );
  }
}
