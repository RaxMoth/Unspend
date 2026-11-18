import 'package:flutter/material.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/design_tokens.dart';
import 'package:unspend/core/widgets/app_sheet.dart';

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          S.current.createProfileDescription,
          style: TextStyle(color: kTextSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 40,
          style: TextStyle(color: kTextPrimary, fontSize: 16),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: S.current.profileNameHint,
            hintStyle: TextStyle(
              color: kTextSecondary.withValues(alpha: 0.6),
              fontSize: 15,
            ),
            counterText: '',
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _submit,
          child: Text(
            S.current.create,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
