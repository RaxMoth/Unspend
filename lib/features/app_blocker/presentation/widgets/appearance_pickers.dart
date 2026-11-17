import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/design_tokens.dart';

import '../../domain/entities/blocker_profile.dart';

/// Size of one option's tap target; the drawn swatch is smaller.
const _targetSize = 48.0;

/// Row of colour swatches for a profile's accent colour.
class ProfileColorPicker extends StatelessWidget {
  const ProfileColorPicker({
    super.key,
    required this.selectedValue,
    required this.onSelected,
  });

  /// ARGB value of the selected colour.
  final int selectedValue;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        for (final option in ProfileColor.palette)
          _Option(
            label: S.current.colorName(option.name),
            selected: option.color.toARGB32() == selectedValue,
            onTap: () => onSelected(option.color.toARGB32()),
            builder: (selected) => AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: option.color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: kTextPrimary, width: 2.5)
                    : null,
              ),
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      size: 18,
                      color:
                          ThemeData.estimateBrightnessForColor(option.color) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Grid of icons for a profile.
class ProfileIconPicker extends StatelessWidget {
  const ProfileIconPicker({
    super.key,
    required this.selectedLabel,
    required this.accent,
    required this.onSelected,
  });

  /// [ProfileIcon.label] of the selected icon.
  final String selectedLabel;
  final Color accent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final option in ProfileIcon.options)
          _Option(
            label: S.current.iconName(option.label),
            selected: option.label == selectedLabel,
            onTap: () => onSelected(option.label),
            builder: (selected) => AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? accent.withValues(alpha: 0.2) : kSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? accent : kBorder),
              ),
              child: Icon(
                option.icon,
                size: 22,
                color: selected ? accent : kTextSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.builder,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget Function(bool selected) builder;

  @override
  Widget build(BuildContext context) {
    void select() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: select,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: select,
        child: SizedBox(
          width: _targetSize,
          height: _targetSize,
          child: Center(child: builder(selected)),
        ),
      ),
    );
  }
}
