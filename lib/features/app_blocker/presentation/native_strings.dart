import '../../../core/constants/strings.dart';
import '../data/datasources/screen_time_datasource.dart';

/// Text handed to the native side, which cannot read the app's in-app
/// language on its own.

/// Labels of the system app picker sheet.
AppPickerLabels appPickerLabels(S s) => AppPickerLabels(
  title: s.pickerTitle,
  cancel: s.cancel,
  save: s.save,
  tooMany: s.pickerTooManyApps,
);

/// Text of the screen iOS shows instead of a blocked app.
ShieldStrings shieldStrings(S s) => ShieldStrings(
  titleTemplate: s.shieldTitleTemplate,
  subtitleTemplate: s.shieldSubtitleTemplate,
  subtitleGeneric: s.shieldSubtitleGeneric,
  button: s.shieldButton,
  appFallback: s.shieldAppFallback,
  websiteFallback: s.shieldWebsiteFallback,
);
