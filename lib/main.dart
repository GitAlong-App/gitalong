import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/logger.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_event.dart';
import 'presentation/bloc/theme/theme_cubit.dart';

void main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      AppLogger.e(
        'FlutterError: ${details.exceptionAsString()}',
        details.exception,
        details.stack,
      );
    };

    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    await Hive.initFlutter();

    await configureDependencies();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );

    // Opened before the router is created: the router reads the onboarding
    // flag from this box synchronously on every redirect.
    await Hive.openBox(AppConstants.settingsBox);

    if (kDebugMode) {
      AppLogger.i('GitAlong app starting...');
      AppLogger.i('Backend: ${dotenv.env['BACKEND_URL']}');
    }

    final authBloc = getIt<AuthBloc>()..add(AuthCheckRequested());
    final router = AppRouter.createRouter(authBloc);

    runApp(GitAlongApp(authBloc: authBloc, router: router));
  }, (error, stack) {
    AppLogger.e('Uncaught zone error', error, stack);
  });
}

class GitAlongApp extends StatefulWidget {
  final AuthBloc authBloc;
  final GoRouter router;

  const GitAlongApp({
    super.key,
    required this.authBloc,
    required this.router,
  });

  @override
  State<GitAlongApp> createState() => _GitAlongAppState();
}

class _GitAlongAppState extends State<GitAlongApp> {
  final _appLinks = AppLinks();
  final _themeCubit = ThemeCubit();

  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
  }

  @override
  void dispose() {
    _themeCubit.close();
    super.dispose();
  }

  void _handleIncomingLinks() {
    _appLinks.uriLinkStream.listen((uri) async {
      if (kDebugMode) AppLogger.i('Deep link received: $uri');
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      } catch (e) {
        AppLogger.e(
            'Error recovering session from deep link', e, StackTrace.current);
      }
    });

    _appLinks.getInitialLink().then((uri) async {
      if (uri != null) {
        if (kDebugMode) AppLogger.i('Initial deep link: $uri');
        try {
          await Supabase.instance.client.auth.getSessionFromUrl(uri);
        } catch (e) {
          AppLogger.e('Error recovering session from initial link', e,
              StackTrace.current);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(
        AppConstants.designWidth,
        AppConstants.designHeight,
      ),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: widget.authBloc),
            BlocProvider.value(value: _themeCubit),
          ],
          child: BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, themeMode) {
              return MaterialApp.router(
                title: AppConstants.appName,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeMode,
                routerConfig: widget.router,
              );
            },
          ),
        );
      },
    );
  }
}
