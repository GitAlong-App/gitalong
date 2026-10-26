/// Shared harness for the widget tests in `test/widgets/`.
///
/// * [configureWidgetTests] (called by `flutter_test_config.dart`) stops
///   google_fonts from touching the network or failing on missing fonts.
/// * [pumpApp] pumps a widget inside `ScreenUtilInit` + `MaterialApp` with
///   the app's real light or dark theme, on a phone-sized surface.
/// * [settle] advances time in bounded steps, so infinite animations
///   (skeleton shimmer, spinners) can't hang the test like `pumpAndSettle`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/core/constants/app_constants.dart';
import 'package:gitalong/core/theme/app_theme.dart';
import 'package:gitalong/domain/entities/match_entity.dart';
import 'package:gitalong/domain/entities/message_entity.dart';
import 'package:gitalong/domain/entities/user_entity.dart';
import 'package:google_fonts/google_fonts.dart';
// The asset manifest google_fonts consults before fetching; there is no
// public way to point it at test fonts.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_base;

/// The app's design size (AppConstants.designWidth × designHeight).
const Size kDesignSize = Size(
  AppConstants.designWidth,
  AppConstants.designHeight,
);

/// A small phone (iPhone SE 1st gen) for the overflow sweep.
const Size kSmallPhone = Size(320, 568);

/// Prefix of the fake font assets served to google_fonts.
const String _fontAssetDir = 'google_fonts_stub/';

/// The app uses Nunito (UI) and JetBrains Mono (code). The fonts are not
/// bundled in `assets/`, and runtime fetching is off in tests, so
/// google_fonts would throw (asynchronously, failing the test) for every
/// style. Instead it is told these files exist; [_fontAssetHandler] serves
/// them as empty data, which the engine ignores.
///
/// So that text has realistic widths (the default test font draws every
/// glyph as a 1 em square, ~1.7x wider than Nunito, which makes every row
/// "overflow"), [_loadRealisticFonts] registers Roboto from the Flutter
/// SDK under the family names google_fonts asks for. Roboto's metrics are
/// close to Nunito's. Without the SDK fonts the test font is used.
const List<String> _families = ['Nunito', 'JetBrainsMono'];
const List<String> _weights = [
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

final List<String> _stubFontAssets = [
  for (final family in _families)
    for (final weight in _weights) ...[
      '$_fontAssetDir$family-$weight.ttf',
      '$_fontAssetDir$family-${weight == 'Regular' ? '' : weight}Italic.ttf',
    ],
];

class _StubFontManifest implements AssetManifest {
  @override
  List<String> listAssets() => _stubFontAssets;

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

/// Serves the stub font files; everything else goes to the real asset
/// bundle (illustrations etc.).
Future<ByteData?> _fontAssetHandler(ByteData? message) async {
  if (message == null) return null;
  final key = utf8.decode(
    message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes),
  );
  if (Uri.decodeFull(key).startsWith(_fontAssetDir)) {
    return ByteData(0);
  }
  return TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger.delegate
      .send('flutter/assets', message);
}

/// `<flutter>/bin/cache/artifacts/material_fonts`, from FLUTTER_ROOT or
/// the flutter_tester executable's location.
Directory? _materialFontsDir() {
  final candidates = <String>[];
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    candidates.add('$root/bin/cache/artifacts/material_fonts');
  }
  // …/bin/cache/artifacts/engine/<platform>/flutter_tester(.exe)
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 6; i++) {
    candidates.add('${dir.path}/artifacts/material_fonts');
    candidates.add('${dir.path}/material_fonts');
    dir = dir.parent;
  }
  for (final path in candidates) {
    final candidate = Directory(path);
    if (File('${candidate.path}/roboto-regular.ttf').existsSync()) {
      return candidate;
    }
  }
  return null;
}

/// Roboto file for a weight (100–900).
String _robotoFile(int weight, bool italic) {
  final name = switch (weight) {
    <= 200 => 'thin',
    300 => 'light',
    400 => 'regular',
    500 => 'medium',
    <= 700 => 'bold',
    _ => 'black',
  };
  if (!italic) return 'roboto-$name.ttf';
  return name == 'regular' ? 'roboto-italic.ttf' : 'roboto-${name}italic.ttf';
}

Future<void> _loadRealisticFonts() async {
  final dir = _materialFontsDir();
  if (dir == null) return;
  for (final family in _families) {
    for (var weight = 100; weight <= 900; weight += 100) {
      for (final italic in [false, true]) {
        // google_fonts' family name: e.g. Nunito_regular, Nunito_700italic.
        final variant = weight == 400
            ? (italic ? 'italic' : 'regular')
            : '$weight${italic ? 'italic' : ''}';
        final bytes =
            File('${dir.path}/${_robotoFile(weight, italic)}').readAsBytesSync();
        final loader = FontLoader('${family}_$variant')
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      }
    }
  }
}

/// Global setup for every test file in this directory.
void configureWidgetTests() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    google_fonts_base.assetManifest = _StubFontManifest();
    await _loadRealisticFonts();
    // Image.asset resolves through the asset manifest. Load (and cache) it
    // now, with real async: if a test started the load under the fake
    // clock, the cached future could never complete in later tests.
    await AssetManifest.loadFromAssetBundle(rootBundle);
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', _fontAssetHandler);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });
}

/// Pumps [child] the way the app hosts screens: `ScreenUtilInit` with the
/// design size, then `MaterialApp` with [AppTheme.lightTheme] (or
/// [AppTheme.darkTheme] when [dark]) and a `Scaffold`.
///
/// * [surfaceSize] — logical screen size (default: the design size, so
///   `.sp` is 1:1).
/// * [textScale] — the user's text scale (e.g. 1.5 for the overflow sweep).
/// * [reduceMotion] — `MediaQuery.disableAnimations`; the kit then skips
///   entrance animations.
/// * [wrapInScaffold] — false to pump [child] as the `home` directly.
///
/// Pumps one frame; call [settle] to run entrance animations.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  Size surfaceSize = kDesignSize,
  double textScale = 1.0,
  bool reduceMotion = false,
  bool wrapInScaffold = true,
  bool scrollable = false,
}) async {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = surfaceSize * 2.0;
  addTearDown(tester.view.reset);

  Widget body = child;
  if (scrollable) body = SingleChildScrollView(child: body);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: kDesignSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: app!,
        ),
        home: wrapInScaffold ? Scaffold(body: body) : body,
      ),
    ),
  );
}

/// Advances the clock by [total] in [step]s, pumping a frame each time.
///
/// A bounded alternative to `pumpAndSettle`: finite animations (kit
/// entrances, flutter_animate effects, count-ups) finish, while infinite
/// ones (skeleton shimmer, progress spinners) can't time out the test.
Future<void> settle(
  WidgetTester tester, {
  Duration total = const Duration(seconds: 2),
  Duration step = const Duration(milliseconds: 50),
}) async {
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

/// Fails the test if any exception (e.g. a RenderFlex overflow) was
/// reported while building or laying out.
void expectNoExceptions(WidgetTester tester, {String? reason}) {
  final error = tester.takeException();
  expect(error, isNull, reason: reason ?? 'unexpected exception: $error');
}

// ── Sample data ──────────────────────────────────────────────────────────

final DateTime kSampleDate = DateTime(2025, 1, 15, 9, 30);

/// A fully filled-in recommendation, without an avatar URL (network images
/// are not loaded in tests).
UserEntity sampleUser({
  String id = 'u1',
  String username = 'ada-dev',
  String? name = 'Ada Lovelace',
  String? bio = 'Building tools for analytical engines.',
  String? pitch = 'A tiny compiler for punch cards, written in Rust.',
  String? location = 'London, UK',
  String? company = 'Analytical Co',
  String? websiteUrl,
  String? githubUrl = 'https://github.com/ada-dev',
  double? matchScore = 87,
  List<String> lookingFor = const ['cofounder', 'open_source'],
  List<String> languages = const ['Rust', 'Dart', 'Go'],
  List<String> matchReasons = const [
    'You both write Rust',
    'Both looking for open source',
  ],
  int publicRepos = 42,
  int totalStars = 1234,
  int followers = 321,
}) {
  return UserEntity(
    id: id,
    username: username,
    email: '',
    name: name,
    bio: bio,
    pitch: pitch,
    location: location,
    company: company,
    websiteUrl: websiteUrl,
    githubUrl: githubUrl,
    matchScore: matchScore,
    lookingFor: lookingFor,
    languages: languages,
    matchReasons: matchReasons,
    publicRepos: publicRepos,
    totalStars: totalStars,
    followers: followers,
    createdAt: kSampleDate,
  );
}

/// A user whose every text field is very long, to stress layouts.
UserEntity longUser() => sampleUser(
      username: 'a-really-long-github-username-that-keeps-going-and-going',
      name: 'Maximiliana Alexandrina Wolfeschlegelsteinhausen-Bergerdorff',
      bio: 'Bio ' * 60,
      pitch: 'An extremely ambitious distributed systems project ' * 6,
      location: 'Llanfairpwllgwyngyllgogerychwyrndrobwllllantysiliogogogoch, '
          'Wales, United Kingdom',
      company: 'The Very Long Company Name Incorporated International',
      websiteUrl: 'https://www.an-incredibly-long-domain-name-example.dev',
      matchScore: 100,
      lookingFor: const [
        'cofounder',
        'side_project',
        'open_source',
        'hackathon',
        'mentor',
        'mentee',
      ],
      languages: const [
        'TypeScript',
        'JavaScript',
        'Objective-C',
        'Rust',
        'Kotlin',
        'Haskell',
      ],
      matchReasons: const [
        'You both maintain popular open source TypeScript tooling libraries',
        'Both of you are looking for a long-term co-founder in developer tools',
        'You are in compatible time zones and both prefer async collaboration',
      ],
      publicRepos: 123456,
      totalStars: 9876543,
      followers: 45678,
    );

MatchEntity sampleMatch({
  UserEntity? user,
  String? lastMessage = 'Want to pair on the parser this weekend?',
  String? lastMessageSenderId = 'u1',
  bool isRead = false,
  DateTime? lastMessageAt,
}) {
  return MatchEntity(
    id: 'm1',
    user: user ?? sampleUser(),
    matchedAt: kSampleDate,
    lastMessage: lastMessage,
    lastMessageAt: lastMessage == null ? null : (lastMessageAt ?? kSampleDate),
    lastMessageSenderId: lastMessage == null ? null : lastMessageSenderId,
    isRead: isRead,
  );
}

MessageEntity sampleMessage({
  String content = 'Hey! Loved your compiler project.',
  String senderId = 'me',
}) {
  return MessageEntity(
    id: 'msg1',
    matchId: 'm1',
    senderId: senderId,
    receiverId: senderId == 'me' ? 'u1' : 'me',
    content: content,
    sentAt: kSampleDate,
  );
}
