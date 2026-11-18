import 'package:flutter/material.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

/// One block rule (schedule, usage limit, task mode) with its on/off switch.
/// The whole card toggles the rule; while [locked] it only shows its state.
class RuleToggleCard extends StatelessWidget {
  const RuleToggleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.accent,
    this.locked = false,
    required this.onToggle,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final Color accent;
  final bool locked;
  final ValueChanged<bool> onToggle;

  void _toggle() {
    AppHaptics.selection();
    onToggle(!enabled);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return Semantics(
      container: true,
      toggled: enabled,
      enabled: !locked,
      label: '$title. $description',
      excludeSemantics: true,
      onTap: locked ? null : _toggle,
      child: Opacity(
        opacity: locked ? AppOpacity.disabled : 1,
        child: AppCard(
          tint: enabled ? accent : null,
          padding: AppInsets.cardWithTrailingControl,
          onTap: locked ? null : _toggle,
          excludeTapFromSemantics: true,
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled ? colors.readable(accent) : colors.textSecondary,
              ),
              Gap.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: text.label.tone(
                              enabled
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                        if (locked) ...[
                          Gap.hXs,
                          const Icon(Icons.lock_rounded, size: AppSizes.iconXs),
                        ],
                      ],
                    ),
                    Gap.vXxs,
                    Text(
                      description,
                      style: text.caption.tone(colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Gap.hXs,
              AppSwitch(
                value: enabled,
                activeColor: accent,
                onChanged: locked ? null : (_) => _toggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
