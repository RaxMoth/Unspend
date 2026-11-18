import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/core/providers.dart';
import 'package:unspend/core/theme/theme.dart';
import 'package:unspend/core/widgets/widgets.dart';

import '../../data/datasources/method_channel_screen_time_datasource.dart';
import '../providers/app_version_provider.dart';

/// What the OS side currently knows and the last rule evaluations by the
/// app and its monitor extension. This is the only window into what the
/// extension did while the app was closed, so it is what to look at when a
/// block does not start or end when expected.
///
/// A tool for the developer and for support, reached by a long press on the
/// version line in Settings — in every build, because a debug build cannot
/// be reopened from the Home Screen of a real iPhone. Nothing on screen
/// points to it, which is why it is in English only.
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
  late Future<String> _report = _load();
  bool _copied = false;

  Future<String> _load() async {
    final data = await ref.read(screenTimeDatasourceProvider).diagnostics();
    final version = await ref.read(appVersionProvider.future);
    final system = ref.read(appPlatformProvider) == AppPlatform.android
        ? 'Android'
        : 'iOS';

    String list(List<String> items) => items.isEmpty ? '–' : items.join('\n');
    return [
      'Unspend ${version.isEmpty ? '?' : version}',
      '$system ${Platform.operatingSystemVersion.replaceFirst('Version ', '')}',
      'Read at ${DateTime.now().toIso8601String()}',
      '',
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
  }

  void _refresh() => setState(() {
    _report = _load();
    _copied = false;
  });

  Future<void> _copy(String report) async {
    await Clipboard.setData(ClipboardData(text: report));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return FutureBuilder<String>(
      future: _report,
      builder: (context, snapshot) {
        final report = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppLoader();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              report ?? 'Could not read the state: ${snapshot.error}',
              style: text.caption.copyWith(fontFamily: 'Menlo', height: 1.4),
            ),
            Gap.vMd,
            if (report != null)
              TextButton(
                onPressed: () => _copy(report),
                child: Text(_copied ? 'Copied' : 'Copy'),
              ),
            TextButton(onPressed: _refresh, child: const Text('Refresh')),
          ],
        );
      },
    );
  }
}
