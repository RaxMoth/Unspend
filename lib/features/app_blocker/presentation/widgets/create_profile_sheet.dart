import 'package:flutter/material.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

import '../../domain/entities/blocker_profile.dart';

/// Asks for the name of a new profile. Returns the name, or null when the
/// sheet was dismissed.
Future<String?> showCreateProfileSheet(BuildContext context) =>
    showAppSheet<String>(
      context: context,
      title: S.current.newProfile,
      builder: (_) => const _CreateProfileForm(),
    );

class _CreateProfileForm extends StatefulWidget {
  const _CreateProfileForm();

  @override
  State<_CreateProfileForm> createState() => _CreateProfileFormState();
}

class _CreateProfileFormState extends State<_CreateProfileForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.createProfileDescription,
          style: context.text.bodySmall.tone(context.colors.textSecondary),
        ),
        Gap.vXl,
        TextField(
          controller: _controller,
          autofocus: true,
          maxLength: BlockerProfile.maxNameLength,
          style: context.text.bodyLarge,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: s.profileNameHint,
            counterText: '',
          ),
          onSubmitted: (_) => _submit(),
        ),
        Gap.vLg,
        AppButton.primary(label: s.create, onPressed: _submit),
      ],
    );
  }
}
