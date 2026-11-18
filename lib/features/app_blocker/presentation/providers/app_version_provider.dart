import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/method_channel_screen_time_datasource.dart';
import '../../data/datasources/screen_time_datasource.dart';

/// Version and build number of the running app, as `1.0.0 (1)`. Empty when
/// it cannot be read.
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    return await ref.watch(screenTimeDatasourceProvider).appVersion();
  } on ScreenTimeException {
    return '';
  }
});
