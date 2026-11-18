import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

import '../../data/datasources/method_channel_screen_time_datasource.dart';
import '../../data/datasources/screen_time_datasource.dart';

/// Debug builds only: what the OS side currently knows and the last rule
/// evaluations by the app and its monitor extension. This is the only window
/// into what the extension did while the app was closed, so it is what to
/// look at when a block does not start or end when expected.
///
/// Not localized: it never ships to users.
Future<void> showDiagnosticsSheet(BuildContext context) => showAppSheet<void>(
  context: context,
  title: 'Diagnostics',
  builder: (_) => const _DiagnosticsView(),
);

class _DiagnosticsView extends ConsumerStatefulWidget {
  const _DiagnosticsView();

  @override
  ConsumerState<_DiagnosticsView> createState() => _DiagnosticsViewState();
}

class _DiagnosticsViewState extends ConsumerState<_DiagnosticsView> {
  late Future<ScreenTimeDiagnostics> _diagnostics = _load();

  Future<ScreenTimeDiagnostics> _load() =>
      ref.read(screenTimeDatasourceProvider).diagnostics();

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return FutureBuilder<ScreenTimeDiagnostics>(
      future: _diagnostics,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            '${snapshot.error}',
            style: text.bodySmall.tone(context.colors.textSecondary),
          );
        }
        final data = snapshot.data;
        if (data == null) return const AppLoader();

        String list(List<String> items) =>
            items.isEmpty ? '–' : items.join('\n');
        final report = [
          'Authorization: ${data.authorization.name}',
          'Deleting apps locked: ${data.removalLocked ? 'yes' : 'no'}',
          '',
          'Active profiles:\n${list(data.activeProfileIds)}',
          '',
          'Shielded now:\n${list(data.shieldedProfileIds)}',
          '',
          'Monitors:\n${list(data.monitoredActivities)}',
          '',
          'Event log (oldest first):\n${list(data.eventLog)}',
        ].join('\n');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              report,
              style: text.caption.copyWith(fontFamily: 'Menlo', height: 1.4),
            ),
            Gap.vMd,
            TextButton(
              onPressed: () => setState(() => _diagnostics = _load()),
              child: const Text('Refresh'),
            ),
          ],
        );
      },
    );
  }
}
