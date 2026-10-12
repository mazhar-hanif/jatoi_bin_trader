import 'dart:async';
import 'dart:ui' show PlatformDispatcher, PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/l10n.dart';
import 'core/path_strategy_stub.dart'
    if (dart.library.html) 'core/path_strategy_web.dart';
import 'core/theme.dart';
import 'providers/core_providers.dart';
import 'router.dart';
import 'services/resilient_preferences_store.dart';
import 'services/reload_stub.dart'
    if (dart.library.js_interop) 'services/reload_web.dart';

final ValueNotifier<Object?> _startupFailure = ValueNotifier<Object?>(null);
bool _rootAppStarted = false;

Future<void> main() async {
  runZonedGuarded(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();
        FlutterError.onError = (details) {
          FlutterError.presentError(details);
          _reportStartupFailure(details.exception, details.stack);
        };
        PlatformDispatcher.instance.onError = (error, stack) {
          _reportStartupFailure(error, stack);
          return true;
        };
        debugPrint('Startup: configuring URL strategy');
        if (!const bool.fromEnvironment('HASH_URLS')) {
          configurePathUrlStrategy();
        }
        debugPrint('Startup: installing resilient preference storage');
        installResilientPreferencesStore();
        debugPrint(
          'Startup: loading local preferences (5-second storage timeout)',
        );
        final prefs = await openPreferences().timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw TimeoutException(
            'Local preference initialization timed out.',
          ),
        );
        debugPrint('Startup: preferences ready; calling runApp');
        _rootAppStarted = true;
        runApp(_StartupHost(prefs: prefs));
        debugPrint('Startup: runApp called');
      } catch (error, stack) {
        _reportStartupFailure(error, stack);
        if (!_rootAppStarted) {
          _rootAppStarted = true;
          runApp(const _StartupHost());
        }
      }
    },
    (error, stack) {
      _reportStartupFailure(error, stack);
      if (!_rootAppStarted) {
        _rootAppStarted = true;
        runApp(const _StartupHost());
      }
    },
  );
}

void _reportStartupFailure(Object error, StackTrace? stack) {
  debugPrint('Startup/runtime failure: $error');
  if (stack != null) debugPrintStack(stackTrace: stack);
  _startupFailure.value = error;
}

class _StartupHost extends StatelessWidget {
  final SharedPreferences? prefs;

  const _StartupHost({this.prefs});

  @override
  Widget build(BuildContext context) {
    final currentPrefs = prefs;
    return ValueListenableBuilder<Object?>(
      valueListenable: _startupFailure,
      builder: (context, error, _) {
        if (error != null || currentPrefs == null) {
          return StartupFailureApp(error: error);
        }
        return ProviderScope(
          overrides: [prefsProvider.overrideWithValue(currentPrefs)],
          child: const JatoiApp(),
        );
      },
    );
  }
}

class StartupFailureApp extends StatelessWidget {
  final Object? error;

  const StartupFailureApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Jatoi Bin Trader',
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      const Icon(Icons.error_outline, size: 52),
                      const SizedBox(height: 16),
                      const Text(
                        'Jatoi Bin Trader could not start.\n'
                        'تعذر بدء تطبيق جتوي بن تريدر.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        error?.toString() ?? 'Unknown startup error',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: reloadCurrentPage,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reload / إعادة التحميل'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class JatoiApp extends ConsumerWidget {
  const JatoiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    return MaterialApp.router(
      title: 'Jatoi Bin Trader',
      debugShowCheckedModeBanner: false,
      locale: ref.watch(localeProvider),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      scrollBehavior: const AppScrollBehavior(),
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: storageUnavailableListenable,
        builder: (context, unavailable, _) => DemoBannerFrame(
          storageUnavailable:
              unavailable || (prefs.getBool('storage_unavailable') ?? false),
          child: child ?? const SizedBox(),
        ),
      ),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
      };
}

const demoMode = bool.fromEnvironment('DEMO', defaultValue: false);

class DemoBannerFrame extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final bool storageUnavailable;

  const DemoBannerFrame({
    super.key,
    required this.child,
    this.enabled = demoMode,
    this.storageUnavailable = false,
  });

  @override
  State<DemoBannerFrame> createState() => _DemoBannerFrameState();
}

class _DemoBannerFrameState extends State<DemoBannerFrame> {
  late bool _showDemoBanner = widget.enabled;
  late bool _showStorageBanner = widget.storageUnavailable;

  @override
  void didUpdateWidget(covariant DemoBannerFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.storageUnavailable && widget.storageUnavailable) {
      _showStorageBanner = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showDemoBanner && !_showStorageBanner) return widget.child;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      children: [
        if (_showDemoBanner)
          MaterialBanner(
            content: Text(
              isArabic
                  ? 'نسخة تجريبية - تُحفظ البيانات في هذا المتصفح فقط'
                  : 'Demo version - data is stored only in this browser',
            ),
            actions: [
              TextButton(
                onPressed: () => setState(() => _showDemoBanner = false),
                child: Text(isArabic ? 'إغلاق' : 'Dismiss'),
              ),
            ],
          ),
        if (_showStorageBanner)
          MaterialBanner(
            content: Text(context.tr('storage_memory_notice')),
            actions: [
              TextButton(
                onPressed: () => setState(() => _showStorageBanner = false),
                child: Text(isArabic ? 'إغلاق' : 'Dismiss'),
              ),
            ],
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
