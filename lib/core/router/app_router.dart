import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';
import '../di/injection.dart';
import '../../presentation/bloc/auth/auth_bloc.dart';
import '../../presentation/bloc/auth/auth_state.dart';
import '../../presentation/bloc/matches/matches_bloc.dart';
import '../../presentation/bloc/matches/matches_event.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/onboarding_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/swipe/swipe_screen.dart';
import '../../presentation/screens/matches/matches_screen.dart';
import '../../presentation/screens/chat/chat_list_screen.dart';
import '../../presentation/screens/chat/chat_detail_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/profile/edit_profile_screen.dart';
import '../../presentation/screens/profile/profile_setup_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/legal/privacy_policy_screen.dart';
import '../../presentation/screens/legal/terms_of_service_screen.dart';
import 'go_router_refresh_stream.dart';

/// App router configuration
class AppRouter {
  AppRouter._();

  /// Read live on every redirect (the settings box is opened in main before
  /// the router is created), so finishing onboarding takes effect without a
  /// restart.
  static bool _hasSeenOnboarding() {
    try {
      if (!Hive.isBoxOpen(AppConstants.settingsBox)) return false;
      final value = Hive.box(AppConstants.settingsBox).get(
        AppConstants.hasSeenOnboardingKey,
        defaultValue: false,
      );
      return value == true;
    } catch (_) {
      return false;
    }
  }

  /// Matches and Chats normally share the HomeScreen's MatchesBloc; when
  /// opened as standalone routes they get their own.
  static Widget _withMatchesBloc(Widget child) {
    return BlocProvider<MatchesBloc>(
      create: (_) => getIt<MatchesBloc>()..add(LoadMatchesEvent()),
      child: child,
    );
  }

  static GoRouter createRouter(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: RoutePaths.splash,
      debugLogDiagnostics: kDebugMode,
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final authState = authBloc.state;

        // Still resolving the session, or a transient error (e.g. a failed
        // sign-in or delete attempt): stay where we are.
        if (authState is AuthInitial ||
            authState is AuthLoading ||
            authState is AuthError) {
          return null;
        }

        final loc = state.matchedLocation;
        // Entry screens a signed-in user is sent away from. The legal pages
        // are deliberately not listed: Settings pushes them while signed in.
        final isAuthEntry = loc == RoutePaths.splash ||
            loc == RoutePaths.login ||
            loc == RoutePaths.onboarding;

        if (authState is AuthAuthenticated) {
          if (loc == RoutePaths.profileSetup) return null;
          if (isAuthEntry) {
            final user = authState.user;
            final needsSetup =
                user.interests.isEmpty || user.lookingFor.isEmpty;
            return needsSetup ? RoutePaths.profileSetup : RoutePaths.home;
          }
          return null;
        }

        // Not authenticated.
        // Already on login or onboarding -- stay there
        if (loc == RoutePaths.login || loc == RoutePaths.onboarding) {
          return null;
        }
        // Legal pages are accessible without auth
        if (loc == RoutePaths.privacyPolicy ||
            loc == RoutePaths.termsOfService) {
          return null;
        }
        // Everything else (splash, protected routes) -> login/onboarding
        return _hasSeenOnboarding() ? RoutePaths.login : RoutePaths.onboarding;
      },
      routes: [
        GoRoute(
          path: RoutePaths.splash,
          name: RouteNames.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: RoutePaths.onboarding,
          name: RouteNames.onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: RoutePaths.login,
          name: RouteNames.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: RoutePaths.home,
          name: RouteNames.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: RoutePaths.swipe,
          name: RouteNames.swipe,
          builder: (context, state) => const SwipeScreen(),
        ),
        GoRoute(
          path: RoutePaths.matches,
          name: RouteNames.matches,
          builder: (context, state) => _withMatchesBloc(const MatchesScreen()),
        ),
        GoRoute(
          path: RoutePaths.chatList,
          name: RouteNames.chatList,
          builder: (context, state) =>
              _withMatchesBloc(const ChatListScreen()),
        ),
        GoRoute(
          path: RoutePaths.chatDetail,
          name: RouteNames.chatDetail,
          builder: (context, state) {
            final matchId = state.pathParameters['matchId'];
            if (matchId == null || matchId.isEmpty) {
              return _withMatchesBloc(const MatchesScreen());
            }
            Map<String, String?>? extra;
            try {
              extra = state.extra as Map<String, String?>?;
            } catch (_) {
              extra = null;
            }
            return ChatDetailScreen(
              matchId: matchId,
              otherUserName: extra?['otherUserName'],
              otherUserAvatar: extra?['otherUserAvatar'],
            );
          },
        ),
        GoRoute(
          path: RoutePaths.profile,
          name: RouteNames.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: RoutePaths.editProfile,
          name: RouteNames.editProfile,
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: RoutePaths.profileSetup,
          name: RouteNames.profileSetup,
          builder: (context, state) => const ProfileSetupScreen(),
        ),
        GoRoute(
          path: RoutePaths.settings,
          name: RouteNames.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: RoutePaths.privacyPolicy,
          name: RouteNames.privacyPolicy,
          builder: (context, state) => const PrivacyPolicyScreen(),
        ),
        GoRoute(
          path: RoutePaths.termsOfService,
          name: RouteNames.termsOfService,
          builder: (context, state) => const TermsOfServiceScreen(),
        ),
      ],
    );
  }
}

/// Route paths
class RoutePaths {
  RoutePaths._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String home = '/home';
  static const String swipe = '/swipe';
  static const String matches = '/matches';
  static const String chatList = '/chats';
  static const String chatDetail = '/chats/:matchId';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String profileSetup = '/profile/setup';
  static const String settings = '/settings';
  static const String privacyPolicy = '/privacy-policy';
  static const String termsOfService = '/terms-of-service';
}

/// Route names
class RouteNames {
  RouteNames._();

  static const String splash = 'splash';
  static const String onboarding = 'onboarding';
  static const String login = 'login';
  static const String home = 'home';
  static const String swipe = 'swipe';
  static const String matches = 'matches';
  static const String chatList = 'chatList';
  static const String chatDetail = 'chatDetail';
  static const String profile = 'profile';
  static const String editProfile = 'editProfile';
  static const String profileSetup = 'profileSetup';
  static const String settings = 'settings';
  static const String privacyPolicy = 'privacyPolicy';
  static const String termsOfService = 'termsOfService';
}
