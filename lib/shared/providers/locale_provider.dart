import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/core/constants/strings.dart';

/// The app's language code ('en', 'de', …).
///
/// Strings are read from the global [S.current]; widgets watch this provider
/// so they rebuild when the language changes.
final localeProvider = NotifierProvider<LocaleNotifier, String>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<String> {
  @override
  String build() => S.langCode;

  /// Switches the language at once and remembers the choice.
  Future<void> setLocale(String langCode) async {
    final saving = S.setLocale(langCode);
    state = langCode;
    await saving;
  }
}
