/// App-wide constants and configuration
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'GitAlong';
  static const String appVersion = '1.1.0';
  static const String appDescription = 'Find the developer your project is missing';

  // Design Constants
  static const double designWidth = 375.0;
  static const double designHeight = 812.0;

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Border Radius
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusCircle = 100.0;

  // Animation Duration
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String themeKey = 'theme_mode';
  static const String hasSeenOnboardingKey = 'has_seen_onboarding';

  // Hive Boxes
  static const String userBox = 'user_box';
  static const String settingsBox = 'settings_box';

  // Swipe Card Settings
  static const double swipeThreshold = 0.3;
  static const double swipeVelocity = 1000.0;

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
}
