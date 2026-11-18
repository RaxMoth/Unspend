import 'package:flutter/material.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';

import '../../domain/entities/blocker_profile.dart';

/// Edge length of a colour swatch and of an icon tile. Both sit in a full
/// size tap target.
const double _swatchSize = 36;
const double _iconTileSize = 44;

/// Width of the ring around the selected colour.
const double _selectedRingWidth = 2.5;

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
    final colors = context.colors;
    return Wrap(
      children: [
        for (final option in ProfileColor.palette)
          _Option(
            label: S.current.colorName(option.name),
            selected: option.color.toARGB32() == selectedValue,
            onTap: () => onSelected(option.color.toARGB32()),
            builder: (selected) => AnimatedContainer(
              duration: context.motion(AppDurations.fast),
              width: _swatchSize,
              height: _swatchSize,
              decoration: BoxDecoration(
                color: option.color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(
                        color: colors.textPrimary,
                        width: _selectedRingWidth,
                      )
                    : null,
              ),
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      size: AppSizes.iconSm,
                      color: colors.filled(option.color).onFill,
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
    final colors = context.colors;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final option in ProfileIcon.options)
          _Option(
            label: S.current.iconName(option.label),
            selected: option.label == selectedLabel,
            onTap: () => onSelected(option.label),
            builder: (selected) => AnimatedContainer(
              duration: context.motion(AppDurations.fast),
              width: _iconTileSize,
              height: _iconTileSize,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: AppOpacity.tint)
                    : colors.surface,
                borderRadius: AppRadius.control,
                border: Border.all(
                  color: selected ? colors.readable(accent) : colors.border,
                ),
              ),
              child: Icon(
                option.icon,
                color: selected
                    ? colors.readable(accent)
                    : colors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// One selectable option in a full-size tap target.
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
      AppHaptics.selection();
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
        child: SizedBox.square(
          dimension: AppSizes.tapTarget,
          child: Center(child: builder(selected)),
        ),
      ),
    );
  }
}
