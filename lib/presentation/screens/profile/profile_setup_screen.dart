import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/collab_constants.dart';
import '../../../core/constants/illustrations.dart';
import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/services/backend_api_client.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/auth/get_current_user_usecase.dart';
import '../../../domain/usecases/progress/profile_strength.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart' as app_auth;
import '../../bloc/profile/profile_bloc.dart';
import '../../bloc/profile/profile_event.dart';
import '../../bloc/profile/profile_state.dart';
import '../../bloc/progress/progress_cubit.dart';
import '../../widgets/ui/ui.dart';
import '../onboarding_flow/full_bleed_system_bars.dart';
import 'setup/add_custom_dialog.dart';
import 'setup/chip_picker_step.dart';
import 'setup/intent_step.dart';
import 'setup/pitch_step.dart';

/// First-run profile setup: one question per step, a progress bar and a
/// back arrow on top, one big button at the bottom, and a celebration at
/// the end.
///
/// 1. What brings you here? (intents, required)
/// 2. Languages (pre-filled from GitHub, required)
/// 3. Interests (required)
/// 4. Skills you're looking for (optional)
/// 5. Pitch (optional, ≤ 280 code points)
///
/// Saving goes through [ProfileBloc]; then AuthBloc re-checks the user (the
/// router relies on it), progress refreshes, and the user lands on home.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const int _intentsStep = 0;
  static const int _languagesStep = 1;
  static const int _interestsStep = 2;
  static const int _skillsStep = 3;
  static const int _pitchStep = 4;
  static const int _stepCount = 5;

  /// XP for a complete profile (docs/DESIGN_SYSTEM.md §6).
  static const int _profileCompleteXp = 50;

  final Set<String> _selectedIntents = {};
  final Set<String> _selectedLanguages = {};
  final Set<String> _selectedInterests = {};
  final Set<String> _selectedSeekingSkills = {};
  final TextEditingController _pitchController = TextEditingController();

  /// Languages detected on GitHub (shown next to the standard list).
  List<String> _detectedLanguages = const [];
  List<String> _prefilledInterests = const [];

  /// "Add your own" entries, kept as chips even after being deselected.
  /// Custom languages and skills share one list, like the chip options.
  final List<String> _customLanguages = [];
  final List<String> _customInterests = [];

  late final ProfileBloc _profileBloc;
  UserEntity? _loadedUser;
  bool _prefilled = false;
  bool _languagesTouched = false;
  bool _requestedGitHubSync = false;
  bool _syncingGitHub = false;
  bool _saving = false;

  /// Saved: the celebration is up and home is next.
  bool _finished = false;

  int _step = _intentsStep;

  /// Direction of the last step change, for the slide transition.
  bool _forward = true;

  bool get _busy => _saving || _finished;

  @override
  void initState() {
    super.initState();
    _profileBloc = getIt<ProfileBloc>()..add(LoadProfileEvent());
  }

  @override
  void dispose() {
    _pitchController.dispose();
    _profileBloc.close();
    super.dispose();
  }

  // ── Loading and the GitHub pre-fill ──────────────────────────────────────

  void _applyProfile(UserEntity user) {
    var startGitHubSync = false;
    setState(() {
      _loadedUser = user;
      _detectedLanguages = user.languages;

      if (!_prefilled) {
        _prefilled = true;
        _selectedIntents.addAll(
          user.lookingFor.where(CollabConstants.isValidIntent),
        );
        _selectedInterests.addAll(user.interests);
        _prefilledInterests = user.interests;
        _selectedSeekingSkills
            .addAll(user.seekingSkills.map(CollabConstants.canonicalLanguage));
        // A slow first load must not wipe a pitch typed in the meantime.
        if (_pitchController.text.isEmpty) {
          _pitchController.text = user.pitch ?? '';
        }
      }

      // Pre-fill languages from GitHub until the user edits them.
      if (!_languagesTouched && _selectedLanguages.isEmpty) {
        _selectedLanguages
            .addAll(user.languages.map(CollabConstants.canonicalLanguage));
      }

      // Brand-new account: GitHub hasn't been synced yet, so ask the backend
      // now to pre-fill languages (joins the refresh started at sign-in).
      if (!_requestedGitHubSync && user.githubSyncedAt == null) {
        _requestedGitHubSync = true;
        _syncingGitHub = true;
        startGitHubSync = true;
      }
    });
    if (startGitHubSync) _importFromGitHub();
  }

  /// Best-effort GitHub import for accounts that were never synced. Runs
  /// outside ProfileBloc, so a slow (cold backend: up to 30 s) or failed
  /// refresh never disables Continue and is never mistaken for the save's
  /// result; the pre-fill lands whenever it arrives.
  Future<void> _importFromGitHub() async {
    try {
      await getIt<BackendApiClient>().refreshGitHubStats();
      final synced = await getIt<GetCurrentUserUseCase>().call();
      if (!mounted || synced == null) return;
      setState(() {
        // Later saves carry the GitHub-filled name/bio/location/company.
        _loadedUser = synced;
        _detectedLanguages = synced.languages;
        if (!_languagesTouched && _selectedLanguages.isEmpty) {
          _selectedLanguages
              .addAll(synced.languages.map(CollabConstants.canonicalLanguage));
        }
      });
    } catch (_) {
      // Best-effort: languages can still be picked by hand.
    } finally {
      if (mounted) setState(() => _syncingGitHub = false);
    }
  }

  void _onProfileState(BuildContext context, ProfileState state) {
    if (state is ProfileLoaded) {
      // Only load/save results arrive here (the GitHub import runs outside
      // the bloc). May start the import on the first load.
      _applyProfile(state.user);
      // Bloc events run concurrently, so a slow first load can land while
      // saving; only a profile with the setup answers is the save's result.
      if (_saving && _hasSetupAnswers(state.user)) _onSaved(state.user);
    } else if (state is ProfileError) {
      final wasSaving = _saving;
      setState(() => _saving = false);
      _showSnack(
        wasSaving
            ? "Couldn't save your profile: ${state.message}"
            : 'Error: ${state.message}',
      );
    }
  }

  // ── Answers ──────────────────────────────────────────────────────────────

  /// The standard languages plus everything detected, added or selected
  /// (for languages and wanted skills alike), so every pre-filled value is
  /// visible and can be deselected.
  List<String> get _languageOptions => CollabConstants.languageOptions([
        ..._detectedLanguages,
        ..._customLanguages,
        ..._selectedLanguages,
        ..._selectedSeekingSkills,
      ]);

  /// The standard interests plus the profile's own and the added ones.
  List<String> get _interestOptions => <String>{
        ...CollabConstants.interests,
        ..._prefilledInterests,
        ..._customInterests,
      }.toList();

  bool get _canContinue =>
      _selectedIntents.isNotEmpty &&
      _selectedLanguages.isNotEmpty &&
      _selectedInterests.isNotEmpty;

  /// Whether [user] has every required setup answer (what a save sends).
  static bool _hasSetupAnswers(UserEntity user) =>
      user.lookingFor.isNotEmpty &&
      user.languages.isNotEmpty &&
      user.interests.isNotEmpty;

  bool _isStepComplete(int step) {
    switch (step) {
      case _intentsStep:
        return _selectedIntents.isNotEmpty;
      case _languagesStep:
        return _selectedLanguages.isNotEmpty;
      case _interestsStep:
        return _selectedInterests.isNotEmpty;
      default:
        // Skills and pitch are optional.
        return true;
    }
  }

  void _toggle(Set<String> set, String value) {
    // The chips and cards give their own haptic tick.
    setState(() {
      if (!set.remove(value)) set.add(value);
    });
  }

  /// The option in [options] equal to [value] ignoring case, if any.
  static String? _matchIgnoringCase(Iterable<String> options, String value) {
    final lower = value.toLowerCase();
    for (final option in options) {
      if (option.toLowerCase() == lower) return option;
    }
    return null;
  }

  Future<void> _addCustomLanguage({required bool forSkills}) async {
    final value = await showAddCustomDialog(
      context,
      title: forSkills ? 'Add a skill' : 'Add a language',
      hint: forSkills ? 'e.g. UI design' : 'e.g. Zig',
    );
    if (value == null || !mounted) return;
    final canonical = CollabConstants.canonicalLanguage(value);
    if (canonical.isEmpty) return;
    // Reuse an existing chip ("rust" selects "Rust") instead of duplicating.
    final existing = _matchIgnoringCase(_languageOptions, canonical);
    setState(() {
      if (existing == null) _customLanguages.add(canonical);
      final option = existing ?? canonical;
      if (forSkills) {
        _selectedSeekingSkills.add(option);
      } else {
        _languagesTouched = true;
        _selectedLanguages.add(option);
      }
    });
  }

  Future<void> _addCustomInterest() async {
    final value = await showAddCustomDialog(
      context,
      title: 'Add an interest',
      hint: 'e.g. Robotics',
    );
    if (value == null || !mounted) return;
    final existing = _matchIgnoringCase(_interestOptions, value);
    setState(() {
      if (existing == null) _customInterests.add(value);
      _selectedInterests.add(existing ?? value);
    });
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _goToStep(int step) {
    if (step == _step) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = step > _step;
      _step = step;
    });
  }

  void _onContinue() {
    if (_busy || !_isStepComplete(_step)) return;
    if (_step < _stepCount - 1) {
      _goToStep(_step + 1);
    } else {
      _save();
    }
  }

  void _onBack() {
    if (_busy || _step == _intentsStep) return;
    _goToStep(_step - 1);
  }

  // ── Saving ───────────────────────────────────────────────────────────────

  void _save() {
    if (_busy) return;
    if (!_canContinue) {
      // Each step checks its own answer, so this is only a safety net: go
      // back to the first unanswered question.
      for (final step in const [_intentsStep, _languagesStep, _interestsStep]) {
        if (!_isStepComplete(step)) {
          _goToStep(step);
          break;
        }
      }
      return;
    }

    final pitch = _pitchController.text.trim();
    if (pitch.runes.length > CollabConstants.pitchMaxLength) {
      _showSnack(
        'Keep your pitch to ${CollabConstants.pitchMaxLength} characters '
        'or fewer.',
      );
      return;
    }

    UserEntity? base = _loadedUser;
    if (base == null) {
      final authState = context.read<AuthBloc>().state;
      if (authState is app_auth.AuthAuthenticated) base = authState.user;
    }
    if (base == null) {
      _showSnack('Still loading your profile. Try again in a moment.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final updated = base.withEditableFields(
      name: base.name,
      bio: base.bio,
      location: base.location,
      company: base.company,
      websiteUrl: base.websiteUrl,
      languages: _selectedLanguages.toList(),
      interests: _selectedInterests.toList(),
      lookingFor: CollabConstants.intents
          .map((i) => i.key)
          .where(_selectedIntents.contains)
          .toList(),
      seekingSkills: _selectedSeekingSkills.toList(),
      pitch: pitch.isEmpty ? null : pitch,
    );

    _profileBloc.add(UpdateProfileEvent(updated));
  }

  Future<void> _onSaved(UserEntity saved) async {
    if (_finished) return;
    setState(() {
      _saving = false;
      _finished = true;
    });

    // Keep the signed-in user (used for routing) in sync with the saved
    // profile, and let the progress numbers (profile_complete, XP) catch up.
    // This route isn't under the Home provider, hence the service locator.
    context.read<AuthBloc>().add(AuthCheckRequested());
    unawaited(getIt<ProgressCubit>().refresh());

    final strength = profileStrength(saved);
    final complete = strength.done >= strength.total;
    await showCelebration(
      context,
      title: complete ? "You're all set!" : 'Nice work!',
      message: complete
          ? 'Your profile is complete. Time to meet some builders.'
          : _incompleteMessage(strength.missing),
      illustration:
          complete ? Illustrations.partyPopper : Illustrations.clappingHands,
      xpGained: complete ? _profileCompleteXp : 0,
      ctaLabel: 'Start matching',
    );
    if (!mounted) return;
    context.go(RoutePaths.home);
  }

  /// What's left for a complete profile (and its XP), e.g. after skipping
  /// the pitch or without a GitHub bio.
  static String _incompleteMessage(List<String> missing) {
    final next = missing.isEmpty ? null : ProfileChecks.byKey(missing.first);
    final nextUp = next == null ? '' : ' Next up: ${next.label}.';
    return 'Your profile is live! Finish the checklist on your profile to '
        'earn +$_profileCompleteXp XP.$nextUp';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  /// Starts above zero so the bar never looks empty; full once saved.
  double get _progress => _finished ? 1.0 : (_step + 1) / (_stepCount + 1);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return BlocProvider.value(
      value: _profileBloc,
      child: BlocListener<ProfileBloc, ProfileState>(
        listener: _onProfileState,
        child: PopScope<Object?>(
          // System back walks back through the questions.
          canPop: _step == _intentsStep && !_busy,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _onBack();
          },
          child: FullBleedSystemBars(
            child: Scaffold(
              backgroundColor: p.bg,
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _buildTopBar(context),
                    Expanded(child: _buildStepSwitcher(context)),
                    _buildBottomBar(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final p = context.palette;
    final canGoBack = _step > _intentsStep && !_busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space8,
        AppTokens.space8,
        AppTokens.gutter,
        AppTokens.space4,
      ),
      child: Row(
        children: [
          // Keeps its slot on the first step so the bar never jumps.
          SizedBox.square(
            dimension: AppTokens.minTouchTarget,
            child: canGoBack
                ? IconButton(
                    tooltip: 'Back',
                    onPressed: _onBack,
                    icon: Icon(PhosphorIconsBold.arrowLeft, color: p.inkMuted),
                  )
                : null,
          ),
          const SizedBox(width: AppTokens.space8),
          Expanded(
            child: GaProgressBar(
              value: _progress,
              animateOnMount: true,
              semanticLabel: 'Profile setup progress',
              semanticValue: _finished
                  ? 'Done'
                  : 'Step ${_step + 1} of $_stepCount',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepSwitcher(BuildContext context) {
    final reduceMotion = AppTokens.reduceMotion(context);
    final currentKey = ValueKey<int>(_step);
    final direction = _forward ? 1.0 : -1.0;

    return AnimatedSwitcher(
      duration: AppTokens.medium,
      switchInCurve: AppTokens.curve,
      switchOutCurve: AppTokens.curve,
      // Every step fills the whole area, so short steps stay top-aligned.
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (child, animation) {
        // Reduced motion: a plain cross-fade.
        if (reduceMotion) {
          return FadeTransition(opacity: animation, child: child);
        }
        // Forward: the new step slides in from the right while the old one
        // leaves to the left; mirrored when going back. (The builder is
        // rebuilt with each step, so the outgoing child picks up the
        // "leaving" offset.)
        final incoming = child.key == currentKey;
        final offset = Offset((incoming ? 0.25 : -0.25) * direction, 0);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: offset, end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: currentKey, child: _buildStep()),
    );
  }

  Widget _buildStep() {
    final enabled = !_busy;
    switch (_step) {
      case _intentsStep:
        return IntentStep(
          stepNumber: _intentsStep + 1,
          stepCount: _stepCount,
          selected: _selectedIntents,
          onToggle: (key) => _toggle(_selectedIntents, key),
          enabled: enabled,
        );
      case _languagesStep:
        return ChipPickerStep(
          stepNumber: _languagesStep + 1,
          stepCount: _stepCount,
          title: 'Which languages do you code in?',
          subtitle: _detectedLanguages.isEmpty
              ? 'Pick at least one.'
              : 'Pick at least one. We added the ones we found on your '
                  'GitHub.',
          options: _languageOptions,
          selected: _selectedLanguages,
          onToggle: (language) {
            _languagesTouched = true;
            _toggle(_selectedLanguages, language);
          },
          onAddCustom: () => _addCustomLanguage(forSkills: false),
          addLabel: 'Add a language',
          banner: _syncingGitHub ? const _GitHubImportBanner() : null,
          enabled: enabled,
        );
      case _interestsStep:
        return ChipPickerStep(
          stepNumber: _interestsStep + 1,
          stepCount: _stepCount,
          title: 'What are you into?',
          subtitle: 'Pick at least one. Add your own if something is missing.',
          options: _interestOptions,
          selected: _selectedInterests,
          onToggle: (interest) => _toggle(_selectedInterests, interest),
          onAddCustom: _addCustomInterest,
          addLabel: 'Add an interest',
          enabled: enabled,
        );
      case _skillsStep:
        return ChipPickerStep(
          stepNumber: _skillsStep + 1,
          stepCount: _stepCount,
          title: 'What should your collaborator bring?',
          subtitle: "Pick the skills you're looking for. We'll favour people "
              'who have them.',
          optional: true,
          options: _languageOptions,
          selected: _selectedSeekingSkills,
          onToggle: (skill) => _toggle(_selectedSeekingSkills, skill),
          onAddCustom: () => _addCustomLanguage(forSkills: true),
          addLabel: 'Add a skill',
          enabled: enabled,
        );
      default:
        return PitchStep(
          stepNumber: _pitchStep + 1,
          stepCount: _stepCount,
          controller: _pitchController,
          maxRunes: CollabConstants.pitchMaxLength,
          enabled: enabled,
        );
    }
  }

  Widget _buildBottomBar(BuildContext context) {
    final p = context.palette;
    final isLast = _step == _stepCount - 1;
    final skipping = _step == _skillsStep && _selectedSeekingSkills.isEmpty;

    final String label;
    if (isLast) {
      label = 'Finish';
    } else if (skipping) {
      label = 'Skip for now';
    } else {
      label = 'Continue';
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(
          top: BorderSide(color: p.border, width: AppTokens.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.gutter,
            AppTokens.space12,
            AppTokens.gutter,
            AppTokens.space12,
          ),
          child: PressableButton(
            label: label,
            variant: skipping
                ? PressableVariant.secondary
                : PressableVariant.primary,
            // Stays green with a spinner while saving (taps are ignored).
            loading: _busy,
            onPressed: _isStepComplete(_step) ? _onContinue : null,
          ),
        ),
      ),
    );
  }
}

/// "Importing your languages from GitHub…" while the background import
/// runs. It never blocks Continue.
class _GitHubImportBanner extends StatelessWidget {
  const _GitHubImportBanner();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = p.toneText(AppTone.sky);

    return Semantics(
      container: true,
      liveRegion: true,
      child: GaTile(
        tone: AppTone.sky,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space12,
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: accent),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Text(
                'Importing your languages from GitHub… You can pick them '
                'yourself meanwhile.',
                style: AppTextStyles.bodySm(p.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
