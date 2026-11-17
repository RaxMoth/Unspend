import 'package:flutter/material.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/design_tokens.dart';

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
        const SizedBox(height: 12),
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
    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: '$title. $body',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? kAccent.withValues(alpha: 0.08) : kSurface,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(
                color: selected ? kAccent : kBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: selected ? kAccent : kTextSecondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: kTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: TextStyle(color: kTextSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? kAccent : kTextSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
