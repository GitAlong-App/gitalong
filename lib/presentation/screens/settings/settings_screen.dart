import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/illustrations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/feedback_service.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/theme/theme_cubit.dart';
import '../../widgets/ui/ui.dart';
import 'widgets/settings_dialog.dart';
import 'widgets/settings_group.dart';

/// Which confirmed auth action is running (for the button spinner).
enum _PendingAction { none, signOut, deleteAccount }

/// Settings: account, preferences (dark mode), legal links, sign out and a
/// danger zone for deleting the account.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  _PendingAction _pending = _PendingAction.none;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _version = '${info.version}+${info.buildNumber}');
      }
    });
  }

  void _onAuthState(BuildContext context, AuthState state) {
    if (state is! AuthLoading && _pending != _PendingAction.none) {
      setState(() => _pending = _PendingAction.none);
    }
    // e.g. account deletion failed: nothing was deleted, say so.
    if (state is AuthError) {
      FeedbackService.errorBuzz();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.message,
            style: AppTextStyles.bodySm(Colors.white),
          ),
          backgroundColor: AppColors.dangerEdge,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: _onAuthState,
      builder: (context, authState) => _buildScaffold(
        context,
        busy: authState is AuthLoading,
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, {required bool busy}) {
    const sectionGap = SizedBox(height: 28);
    const headerGap = SizedBox(height: AppTokens.space12);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.gutter,
            AppTokens.space8,
            AppTokens.gutter,
            AppTokens.space32,
          ),
          children: [
            const SectionHeader(title: 'Account'),
            headerGap,
            SettingsGroup(
              children: [
                SettingsRow(
                  leading: Illustration(Illustrations.technologist, size: 32),
                  title: 'Edit profile',
                  subtitle: 'Name, pitch, skills and more',
                  onTap: () => context.push(RoutePaths.editProfile),
                ),
              ],
            ),
            sectionGap,
            const SectionHeader(title: 'Preferences'),
            headerGap,
            BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, mode) => _preferences(context, mode),
            ),
            sectionGap,
            const SectionHeader(title: 'About'),
            headerGap,
            SettingsGroup(
              children: [
                SettingsRow(
                  leading: Illustration(Illustrations.octopus, size: 32),
                  title: 'About GitAlong',
                  subtitle: _version.isEmpty ? null : 'Version $_version',
                  onTap: _showAbout,
                ),
                SettingsRow(
                  leading: Illustration(Illustrations.memo, size: 32),
                  title: 'Terms of Service',
                  onTap: () => context.push(RoutePaths.termsOfService),
                ),
                SettingsRow(
                  leading: Illustration(Illustrations.shield, size: 32),
                  title: 'Privacy Policy',
                  onTap: () => context.push(RoutePaths.privacyPolicy),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space32),
            PressableButton(
              label: 'Sign out',
              variant: PressableVariant.secondary,
              icon: PhosphorIconsBold.signOut,
              loading: busy && _pending == _PendingAction.signOut,
              onPressed: _confirmSignOut,
            ),
            const SizedBox(height: AppTokens.space32),
            const SectionHeader(title: 'Danger zone'),
            headerGap,
            _DangerZone(
              deleting: busy && _pending == _PendingAction.deleteAccount,
              onDelete: _confirmDeleteAccount,
            ),
            const SizedBox(height: AppTokens.space24),
            Center(
              child: Text(
                _version.isEmpty
                    ? AppConstants.appName
                    : '${AppConstants.appName} v$_version',
                style: AppTextStyles.bodySmall(context.palette.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preferences(BuildContext context, ThemeMode mode) {
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark =
        mode == ThemeMode.dark || (mode == ThemeMode.system && platformDark);
    final followsDevice = mode == ThemeMode.system;
    final themeCubit = context.read<ThemeCubit>();

    return SettingsGroup(
      children: [
        SettingsSwitchRow(
          leading: const SettingsIconBadge(
            icon: PhosphorIconsFill.moon,
            tone: AppTone.purple,
          ),
          title: 'Dark mode',
          subtitle: followsDevice ? 'Following your device' : null,
          value: isDark,
          onChanged: (dark) => themeCubit
              .setThemeMode(dark ? ThemeMode.dark : ThemeMode.light),
        ),
        SettingsSwitchRow(
          leading: const SettingsIconBadge(
            icon: PhosphorIconsFill.deviceMobile,
            tone: AppTone.sky,
          ),
          title: 'Match device theme',
          subtitle: 'Switch with your system setting',
          value: followsDevice,
          // Turning it off keeps the current look.
          onChanged: (follow) => themeCubit.setThemeMode(
            follow
                ? ThemeMode.system
                : (platformDark ? ThemeMode.dark : ThemeMode.light),
          ),
        ),
      ],
    );
  }

  void _showAbout() {
    showSettingsDialog(
      context,
      illustration: Illustrations.octopus,
      title: AppConstants.appName,
      message: '${AppConstants.appDescription}.\n'
          'Version ${_version.isEmpty ? AppConstants.appVersion : _version}',
      confirmLabel: 'Close',
    );
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showSettingsDialog(
      context,
      illustration: Illustrations.wavingHand,
      title: 'Sign out?',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign out',
      confirmVariant: PressableVariant.danger,
      confirmIcon: PhosphorIconsBold.signOut,
      cancelLabel: 'Cancel',
    );
    if (!confirmed || !mounted) return;
    setState(() => _pending = _PendingAction.signOut);
    context.read<AuthBloc>().add(SignOutEvent());
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showSettingsDialog(
      context,
      icon: PhosphorIconsFill.warningCircle,
      iconTone: AppTone.danger,
      title: 'Delete your account?',
      message: 'Are you sure you want to permanently delete your account? '
          'This action cannot be undone and will delete all your data, '
          'matches, and messages.',
      confirmLabel: 'Delete account',
      confirmVariant: PressableVariant.danger,
      confirmIcon: PhosphorIconsBold.trash,
      cancelLabel: 'Cancel',
    );
    if (!confirmed || !mounted) return;
    setState(() => _pending = _PendingAction.deleteAccount);
    context.read<AuthBloc>().add(DeleteAccountEvent());
  }
}

/// A danger-tinted tile explaining account deletion, with the red button.
class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.deleting, required this.onDelete});

  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dangerText = palette.toneText(AppTone.danger);

    return GaTile(
      tone: AppTone.danger,
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsFill.warningCircle, size: 24, color: dangerText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Delete account',
                  style: AppTextStyles.h3(dangerText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Permanently deletes your profile, matches and messages. "
            "This can't be undone.",
            style: AppTextStyles.bodySm(palette.ink),
          ),
          const SizedBox(height: AppTokens.space16),
          PressableButton(
            label: 'Delete account',
            variant: PressableVariant.danger,
            icon: PhosphorIconsBold.trash,
            loading: deleting,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
