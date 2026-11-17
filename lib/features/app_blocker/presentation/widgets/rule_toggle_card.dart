import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unspend/core/theme/design_tokens.dart';
import 'package:unspend/core/widgets/app_switch.dart';

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
    HapticFeedback.selectionClick();
    onToggle(!enabled);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      toggled: enabled,
      enabled: !locked,
      label: '$title. $description',
      excludeSemantics: true,
      onTap: locked ? null : _toggle,
      child: Opacity(
        opacity: locked ? 0.6 : 1,
        child: Material(
          color: enabled ? accent.withValues(alpha: 0.08) : kSurface,
          borderRadius: BorderRadius.circular(kRadius),
          child: InkWell(
            onTap: locked ? null : _toggle,
            borderRadius: BorderRadius.circular(kRadius),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kRadius),
                border: Border.all(
                  color: enabled ? accent.withValues(alpha: 0.4) : kBorder,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: enabled ? accent : kTextSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: enabled
                                      ? kTextPrimary
                                      : kTextSecondary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (locked) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.lock_rounded,
                                size: 14,
                                color: kTextSecondary.withValues(alpha: 0.6),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: TextStyle(color: kTextSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  AppSwitch(
                    value: enabled,
                    activeColor: accent,
                    onChanged: locked ? null : (_) => _toggle(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
