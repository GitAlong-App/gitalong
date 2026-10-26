// Boots the real GitAlong app (real DI config, blocs, router and screens)
// on top of [FakeBackend], without Supabase, dotenv or a network.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:gitalong/core/auth/auth_session.dart';
import 'package:gitalong/core/constants/app_constants.dart';
import 'package:gitalong/core/di/injection.config.dart';
import 'package:gitalong/core/di/injection.dart';
import 'package:gitalong/core/router/app_router.dart';
import 'package:gitalong/data/services/backend_api_client.dart';
import 'package:gitalong/domain/repositories/auth_repository.dart';
import 'package:gitalong/domain/repositories/chat_repository.dart';
import 'package:gitalong/domain/repositories/match_repository.dart';
import 'package:gitalong/domain/repositories/notification_repository.dart';
import 'package:gitalong/domain/repositories/progress_repository.dart';
import 'package:gitalong/domain/repositories/swipe_repository.dart';
import 'package:gitalong/domain/repositories/user_repository.dart';
import 'package:gitalong/main.dart';
import 'package:gitalong/presentation/bloc/auth/auth_bloc.dart';
import 'package:gitalong/presentation/bloc/auth/auth_event.dart';

import 'fake_backend.dart';

/// Running under `flutter test` on the host (flutter_tester), as opposed to
/// an integration test on a device, where the real plugins and assets exist.
bool get isHostTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// One-time host setup: plugin channels and fonts that flutter_tester
/// doesn't provide. Safe to call repeatedly.
void setUpTestEnvironment() {
  PackageInfo.setMockInitialValues(
    appName: 'GitAlong',
    packageName: 'app.gitalong',
    version: '1.1.0',
    buildNumber: '2',
    buildSignature: '',
  );
  if (!isHostTest) return;

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // app_links: no launch link and no incoming links (so GitAlongApp never
  // reaches for Supabase to exchange a deep-link session).
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.app_links/messages'),
    (call) async => null,
  );
  messenger.setMockStreamHandler(
    const EventChannel('com.llfbandit.app_links/events'),
    MockStreamHandler.inline(onListen: (arguments, events) {}),
  );

  _serveGoogleFontsFromTestAssets(messenger);
}

/// google_fonts would download Nunito / JetBrains Mono over HTTP (which
/// flutter_tester answers with 400, failing the test with an uncaught
/// error). Pretend the fonts are bundled: a fake manifest lists them and the
/// asset channel answers for them.
void _serveGoogleFontsFromTestAssets(TestDefaultBinaryMessenger messenger) {
  final assetDir = Platform.environment['UNIT_TEST_ASSETS'];
  if (assetDir == null) return;
  final appName = Platform.environment['APP_NAME'] ?? 'gitalong';
  final packagePrefix = 'packages/$appName/';
  const fontPrefix = 'google_fonts/';

  File assetFile(String key) => File('$assetDir/$key');

  // Empty data: the engine ignores the unreadable font and text keeps the
  // test font. (Registering a real font here would change text metrics
  // between layout and paint and trip TextPainter's debug checks.)
  final fontData = Uint8List(0);

  google_fonts.assetManifest = _GoogleFontsManifest(
    families: const ['Nunito', 'JetBrainsMono'],
    prefix: fontPrefix,
  );

  // Same behaviour as flutter_test's own asset mock, plus the fonts.
  messenger.setMockMessageHandler('flutter/assets', (message) {
    var key = utf8.decode(message!.buffer.asUint8List());
    if (key.startsWith(fontPrefix)) {
      return SynchronousFuture<ByteData>(fontData.buffer.asByteData());
    }
    var file = assetFile(key);
    if (!file.existsSync()) {
      if (!key.startsWith(packagePrefix)) return null;
      key = key.replaceFirst(packagePrefix, '');
      file = assetFile(key);
      if (!file.existsSync()) return null;
    }
    final bytes = Uint8List.fromList(file.readAsBytesSync());
    return SynchronousFuture<ByteData>(bytes.buffer.asByteData());
  });
}

class _GoogleFontsManifest implements AssetManifest {
  _GoogleFontsManifest({required List<String> families, required String prefix})
      : _assets = [
          for (final family in families)
            for (final weight in _weights)
              for (final italic in [false, true])
                '$prefix$family-${_variant(weight, italic)}.ttf',
        ];

  static const _weights = [
    'Thin',
    'ExtraLight',
    'Light',
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
    'Black',
  ];

  static String _variant(String weight, bool italic) {
    if (weight == 'Regular') return italic ? 'Italic' : 'Regular';
    return italic ? '${weight}Italic' : weight;
  }

  final List<String> _assets;

  @override
  List<String> listAssets() => _assets;

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

/// Replaces the service locator with the real generated config, minus every
/// Supabase-backed registration (swapped for [backend]'s fakes). Supabase
/// itself is never initialized or resolved.
Future<void> configureTestDependencies(FakeBackend backend) async {
  await getIt.reset();
  getIt.allowReassignment = true;
  getIt.init();
  getIt
    ..registerSingleton<AuthSession>(backend.session)
    ..registerSingleton<AuthRepository>(backend.auth)
    ..registerSingleton<UserRepository>(backend.users)
    ..registerSingleton<SwipeRepository>(backend.swipes)
    ..registerSingleton<MatchRepository>(backend.matches)
    ..registerSingleton<ChatRepository>(backend.chat)
    ..registerSingleton<NotificationRepository>(backend.notifications)
    ..registerSingleton<ProgressRepository>(backend.progressRepository)
    ..registerSingleton<BackendApiClient>(backend.backendApi);
  getIt.allowReassignment = false;
}

/// A fresh in-memory settings box (the router reads the onboarding flag from
/// it synchronously, so it must be open before the router exists).
Future<void> openSettingsBox({bool hasSeenOnboarding = false}) async {
  if (Hive.isBoxOpen(AppConstants.settingsBox)) {
    await Hive.box(AppConstants.settingsBox).close();
  }
  final box = await Hive.openBox(AppConstants.settingsBox, bytes: Uint8List(0));
  if (hasSeenOnboarding) {
    await box.put(AppConstants.hasSeenOnboardingKey, true);
  }
}

/// Phone-sized surface (390 x 844 logical) on the host.
void usePhoneSurface(WidgetTester tester) {
  if (!isHostTest) return;
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Boots [GitAlongApp] exactly like `main()` does after its platform setup:
/// AuthBloc from DI checks the session, the router follows it.
Future<void> bootApp(
  WidgetTester tester,
  FakeBackend backend, {
  bool hasSeenOnboarding = false,
}) async {
  usePhoneSurface(tester);
  // Hive's in-memory box and get_it use real futures: set up outside the
  // fake-async zone.
  await tester.runAsync(() async {
    await openSettingsBox(hasSeenOnboarding: hasSeenOnboarding);
    await configureTestDependencies(backend);
  });

  final authBloc = getIt<AuthBloc>()..add(AuthCheckRequested());
  final router = AppRouter.createRouter(authBloc);
  addTearDown(router.dispose);

  // Only the first frame: callers wait for the screen they expect.
  await tester.pumpWidget(GitAlongApp(authBloc: authBloc, router: router));
}

/// Tears the app down and lets pending timers (toasts, delayed entrances)
/// run out, so the test ends without pending timers.
Future<void> shutDownApp(WidgetTester tester, FakeBackend backend) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 30));
  await tester.runAsync(() async {
    await getIt<AuthBloc>().close();
    await backend.dispose();
    await getIt.reset();
  });
}

// ── Pumping helpers ──────────────────────────────────────────────────────

/// Pumps frames for [duration] (the app has looping animations, so
/// `pumpAndSettle` would never return).
Future<void> settle(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 1500),
]) async {
  const step = Duration(milliseconds: 50);
  var elapsed = Duration.zero;
  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}

/// Pumps until [finder] matches something, failing after [timeout].
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  const step = Duration(milliseconds: 50);
  var elapsed = Duration.zero;
  while (finder.evaluate().isEmpty) {
    if (elapsed >= timeout) {
      throw TestFailure('Timed out after $timeout waiting for $finder');
    }
    await tester.pump(step);
    elapsed += step;
  }
}

/// Pumps until [finder] matches nothing, failing after [timeout].
Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  const step = Duration(milliseconds: 50);
  var elapsed = Duration.zero;
  while (finder.evaluate().isNotEmpty) {
    if (elapsed >= timeout) {
      throw TestFailure('Timed out after $timeout waiting for $finder to go');
    }
    await tester.pump(step);
    elapsed += step;
  }
}

/// Scrolls [finder] into view (if needed) and taps it, then lets the UI
/// react.
Future<void> tapAndSettle(
  WidgetTester tester,
  Finder finder, {
  Duration settleFor = const Duration(milliseconds: 800),
}) async {
  await pumpUntilFound(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first, warnIfMissed: false);
  await settle(tester, settleFor);
}
