import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unspend/config/router.dart';
import 'package:unspend/core/constants/strings.dart';
import 'package:unspend/core/theme/app_theme.dart';
import 'package:unspend/core/theme/design_tokens.dart';
import 'package:unspend/features/app_blocker/presentation/widgets/app_lifecycle_host.dart';
import 'package:unspend/shared/providers/locale_provider.dart';
import 'package:unspend/shared/providers/theme_mode_provider.dart';

/// Text never gets smaller than this or larger than [kMaxTextScale] times
/// its designed size. The system setting goes much further (over 3×), where
/// a phone-sized layout stops being usable; 1.6× keeps every screen intact
/// while still honouring a clear preference for larger text.
const kMinTextScale = 0.9;
const kMaxTextScale = 1.6;

class UnspendApp extends ConsumerWidget {
  const UnspendApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the locale rebuilds the whole tree on a language switch.
    final langCode = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'Unspend',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: kMinTextScale,
              maxScaleFactor: kMaxTextScale,
            ),
          ),
          child: _TokenBrightnessSync(
            brightness: Theme.of(context).brightness,
            child: AppLifecycleHost(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
      locale: Locale(langCode),
      supportedLocales: [for (final code in S.supportedLocales) Locale(code)],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Keeps the colour tokens in `design_tokens.dart` on the resolved
/// brightness.
///
/// The tokens are plain getters, so widgets do not know to rebuild when the
/// brightness changes (for example when iOS switches to dark mode at
/// sunset). When it does, every widget below is asked to rebuild once.
class _TokenBrightnessSync extends StatefulWidget {
  const _TokenBrightnessSync({required this.brightness, required this.child});

  final Brightness brightness;
  final Widget child;

  @override
  State<_TokenBrightnessSync> createState() => _TokenBrightnessSyncState();
}

class _TokenBrightnessSyncState extends State<_TokenBrightnessSync> {
  @override
  void initState() {
    super.initState();
    updateTokenBrightness(widget.brightness);
  }

  @override
  void didUpdateWidget(_TokenBrightnessSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brightness == widget.brightness) return;
    updateTokenBrightness(widget.brightness);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rebuild(context as Element);
    });
  }

  static void _rebuild(Element element) {
    element.markNeedsBuild();
    element.visitChildren(_rebuild);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
