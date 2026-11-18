import 'package:flutter/material.dart';

import '../constants/strings.dart';
import '../theme/theme.dart';

/// A text field for a PIN, hidden by default with a show/hide button.
class PinField extends StatefulWidget {
  const PinField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.autofocus = false,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool autofocus;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<PinField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscured,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      style: context.text.bodyLarge,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        suffixIcon: IconButton(
          tooltip: _obscured ? S.current.showPin : S.current.hidePin,
          icon: Icon(
            _obscured ? Icons.visibility_off : Icons.visibility,
            size: AppSizes.iconMd,
          ),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}
