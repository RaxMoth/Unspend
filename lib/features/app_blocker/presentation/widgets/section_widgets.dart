import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unspend/core/theme/design_tokens.dart';

/// Small heading above a group of settings.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          color: kTextSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Bordered surface that groups related content.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kBorder),
      ),
      child: child,
    );
  }
}

/// Dims its child and makes it unresponsive while [locked] — used for the
/// settings that cannot change while a profile is active.
class LockedSection extends StatelessWidget {
  const LockedSection({super.key, required this.locked, required this.child});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: locked,
      child: Opacity(opacity: locked ? 0.5 : 1, child: child),
    );
  }
}

/// A tappable label + time, e.g. "Start 09:00".
class TimeTile extends StatelessWidget {
  const TimeTile({
    super.key,
    required this.label,
    required this.formatted,
    required this.onTap,
  });

  final String label;
  final String formatted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label $formatted',
      excludeSemantics: true,
      child: Material(
        color: kBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: kTextSecondary, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  formatted,
                  style: TextStyle(
                    color: kTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The screen's main action. The label wraps instead of overflowing.
class FullWidthButton extends StatelessWidget {
  const FullWidthButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.borderColor,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color? borderColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled ? color : color.withValues(alpha: 0.5);
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: enabled
            ? () {
                HapticFeedback.lightImpact();
                onPressed!();
              }
            : null,
        style: TextButton.styleFrom(
          backgroundColor: enabled ? bgColor : bgColor.withValues(alpha: 0.3),
          overlayColor: color.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: borderColor != null
                ? BorderSide(color: borderColor!)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
