import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/collab_constants.dart';
import '../../../core/constants/illustrations.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/feedback_service.dart';
import '../../../domain/entities/user_entity.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/profile/profile_bloc.dart';
import '../../bloc/profile/profile_event.dart';
import '../../bloc/profile/profile_state.dart';
import '../../bloc/progress/progress_cubit.dart';
import '../../widgets/ui/ui.dart';
import 'widgets/edit_section.dart';
import 'widgets/intent_art.dart';
import 'widgets/tag_picker.dart';

/// Edit profile: grouped tiles for who you are, why you're here, your pitch,
/// languages, interests, wanted skills and details, with a sticky 3D save
/// button.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Used to scroll to the first problem when saving fails validation.
  final _nameFieldKey = GlobalKey<FormFieldState<String>>();
  final _bioFieldKey = GlobalKey<FormFieldState<String>>();
  final _pitchFieldKey = GlobalKey<FormFieldState<String>>();
  final _locationFieldKey = GlobalKey<FormFieldState<String>>();
  final _companyFieldKey = GlobalKey<FormFieldState<String>>();
  final _websiteFieldKey = GlobalKey<FormFieldState<String>>();
  final _intentSectionKey = GlobalKey();
  final _languageSectionKey = GlobalKey();
  final _interestSectionKey = GlobalKey();

  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _pitchCtrl = TextEditingController();

  final Set<String> _lookingFor = {};

  // Selections, in order, unique ignoring case.
  final List<String> _languages = [];
  final List<String> _interests = [];
  final List<String> _seekingSkills = [];

  // Entries outside the standard lists, kept as options when deselected.
  final List<String> _languageExtras = [];
  final List<String> _interestExtras = [];
  final List<String> _skillExtras = [];

  late final ProfileBloc _profileBloc;
  UserEntity? _originalUser;
  bool _saving = false;

  /// A save was attempted: fields re-validate as they change.
  bool _submitted = false;
  bool _showIntentError = false;
  bool _showLanguageError = false;
  bool _showInterestError = false;

  @override
  void initState() {
    super.initState();
    _profileBloc = getIt<ProfileBloc>()..add(LoadProfileEvent());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _companyCtrl.dispose();
    _websiteCtrl.dispose();
    _pitchCtrl.dispose();
    _profileBloc.close();
    super.dispose();
  }

  // ── List helpers (case-insensitive) ───────────────────────────────────────

  static bool _containsIgnoreCase(List<String> list, String value) {
    final lower = value.toLowerCase();
    return list.any((entry) => entry.toLowerCase() == lower);
  }

  static void _addUnique(List<String> list, String value) {
    if (value.isEmpty || _containsIgnoreCase(list, value)) return;
    list.add(value);
  }

  static void _toggleIn(List<String> list, String value) {
    final lower = value.toLowerCase();
    final index = list.indexWhere((entry) => entry.toLowerCase() == lower);
    if (index >= 0) {
      list.removeAt(index);
    } else {
      list.add(value);
    }
  }

  /// The standard spelling of [interest] when it matches one of
  /// [CollabConstants.interests] ignoring case, otherwise the trimmed input.
  static String _canonicalInterest(String interest) {
    final trimmed = interest.trim();
    final lower = trimmed.toLowerCase();
    for (final standard in CollabConstants.interests) {
      if (standard.toLowerCase() == lower) return standard;
    }
    return trimmed;
  }

  List<String> get _languageOptions =>
      CollabConstants.languageOptions(_languageExtras);

  List<String> get _interestOptions {
    final options = List<String>.of(CollabConstants.interests);
    for (final extra in _interestExtras) {
      _addUnique(options, extra);
    }
    return options;
  }

  List<String> get _skillOptions =>
      CollabConstants.languageOptions([..._languages, ..._skillExtras]);

  // ── Populate / edit ───────────────────────────────────────────────────────

  void _populateFields(UserEntity user) {
    if (_originalUser != null) return;
    _originalUser = user;
    _nameCtrl.text = user.name ?? '';
    _bioCtrl.text = user.bio ?? '';
    _locationCtrl.text = user.location ?? '';
    _companyCtrl.text = user.company ?? '';
    _websiteCtrl.text = user.websiteUrl ?? '';
    _pitchCtrl.text = user.pitch ?? '';
    setState(() {
      _lookingFor
        ..clear()
        ..addAll(user.lookingFor.where(CollabConstants.isValidIntent));
      _languages.clear();
      for (final language in user.languages) {
        _addUnique(_languages, CollabConstants.canonicalLanguage(language));
      }
      _interests.clear();
      for (final interest in user.interests) {
        _addUnique(_interests, _canonicalInterest(interest));
      }
      _seekingSkills.clear();
      for (final skill in user.seekingSkills) {
        _addUnique(_seekingSkills, CollabConstants.canonicalLanguage(skill));
      }
      _languageExtras
        ..clear()
        ..addAll(_languages);
      _interestExtras
        ..clear()
        ..addAll(_interests);
      _skillExtras
        ..clear()
        ..addAll(_seekingSkills);
    });
  }

  void _toggleIntent(String key) {
    setState(() {
      if (!_lookingFor.remove(key)) _lookingFor.add(key);
      if (_lookingFor.isNotEmpty) _showIntentError = false;
    });
  }

  void _toggleLanguage(String language) {
    setState(() {
      _toggleIn(_languages, language);
      if (_languages.isNotEmpty) _showLanguageError = false;
    });
  }

  /// Adds one or more comma-separated languages.
  void _addLanguages(String input) {
    setState(() {
      for (final part in input.split(',')) {
        final language = CollabConstants.canonicalLanguage(part);
        _addUnique(_languageExtras, language);
        _addUnique(_languages, language);
      }
      if (_languages.isNotEmpty) _showLanguageError = false;
    });
  }

  void _toggleInterest(String interest) {
    setState(() {
      _toggleIn(_interests, interest);
      if (_interests.isNotEmpty) _showInterestError = false;
    });
  }

  void _addInterests(String input) {
    setState(() {
      for (final part in input.split(',')) {
        final interest = _canonicalInterest(part);
        _addUnique(_interestExtras, interest);
        _addUnique(_interests, interest);
      }
      if (_interests.isNotEmpty) _showInterestError = false;
    });
  }

  void _toggleSkill(String skill) {
    setState(() => _toggleIn(_seekingSkills, skill));
  }

  void _addSkills(String input) {
    setState(() {
      for (final part in input.split(',')) {
        final skill = CollabConstants.canonicalLanguage(part);
        _addUnique(_skillExtras, skill);
        _addUnique(_seekingSkills, skill);
      }
    });
  }

  /// Empty text clears the field (sent as an explicit null).
  static String? _orNull(TextEditingController ctrl) {
    final text = ctrl.text.trim();
    return text.isEmpty ? null : text;
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  void _save() {
    if (_saving) return;
    final formValid = _formKey.currentState?.validate() == true;
    setState(() {
      _submitted = true;
      _showIntentError = _lookingFor.isEmpty;
      _showLanguageError = _languages.isEmpty;
      _showInterestError = _interests.isEmpty;
    });
    if (!formValid ||
        _lookingFor.isEmpty ||
        _languages.isEmpty ||
        _interests.isEmpty) {
      FeedbackService.errorBuzz();
      _scrollToFirstError();
      return;
    }
    final original = _originalUser;
    if (original == null) return;

    final updated = original.withEditableFields(
      name: _orNull(_nameCtrl),
      bio: _orNull(_bioCtrl),
      location: _orNull(_locationCtrl),
      company: _orNull(_companyCtrl),
      websiteUrl: _orNull(_websiteCtrl),
      languages: List<String>.of(_languages),
      interests: List<String>.of(_interests),
      lookingFor: CollabConstants.intents
          .map((i) => i.key)
          .where(_lookingFor.contains)
          .toList(),
      seekingSkills: List<String>.of(_seekingSkills),
      pitch: _orNull(_pitchCtrl),
    );

    setState(() => _saving = true);
    _profileBloc.add(UpdateProfileEvent(updated));
  }

  /// Brings the first invalid field or section into view (top to bottom).
  void _scrollToFirstError() {
    bool invalid(GlobalKey<FormFieldState<String>> key) =>
        key.currentState?.hasError ?? false;

    final targets = <GlobalKey>[
      if (invalid(_nameFieldKey)) _nameFieldKey,
      if (invalid(_bioFieldKey)) _bioFieldKey,
      if (_lookingFor.isEmpty) _intentSectionKey,
      if (invalid(_pitchFieldKey)) _pitchFieldKey,
      if (_languages.isEmpty) _languageSectionKey,
      if (_interests.isEmpty) _interestSectionKey,
      if (invalid(_locationFieldKey)) _locationFieldKey,
      if (invalid(_companyFieldKey)) _companyFieldKey,
      if (invalid(_websiteFieldKey)) _websiteFieldKey,
    ];
    if (targets.isEmpty) return;
    final target = targets.first;

    // After the error texts are laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = target.currentContext;
      if (!mounted || targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.1,
        duration: AppTokens.motion(context, AppTokens.slow),
        curve: AppTokens.curve,
      );
    });
  }

  void _onProfileState(BuildContext context, ProfileState state) {
    if (state is ProfileError) {
      setState(() => _saving = false);
      // A failed first load is shown in place of the form.
      if (_originalUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${state.message}')),
        );
      }
      return;
    }
    if (state is ProfileLoaded) {
      if (_saving) {
        _saving = false;
        // Keep the signed-in user (used for routing and icebreakers) in sync
        // with the saved profile.
        context.read<AuthBloc>().add(AuthCheckRequested());
        // Profile strength feeds XP and the "All set" achievement.
        getIt<ProgressCubit>().refresh();
        showGaToast(
          context,
          title: 'Profile saved',
          message: 'Looking sharp! Your changes are live.',
          illustration: Illustrations.checkMark,
        );
        context.pop();
        return;
      }
      _populateFields(state.user);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _profileBloc,
      child: BlocConsumer<ProfileBloc, ProfileState>(
        listener: _onProfileState,
        builder: (context, state) {
          final isSaving = state is ProfileUpdating || _saving;

          final Widget body;
          if (_originalUser != null) {
            body = _buildForm(isSaving: isSaving);
          } else if (state is ProfileError) {
            body = EmptyState(
              illustration: Illustrations.octopus,
              title: "Couldn't load your profile",
              message: state.message,
              actionLabel: 'Try again',
              onAction: () => _profileBloc.add(LoadProfileEvent()),
            );
          } else {
            body = const _EditSkeleton();
          }

          return Scaffold(
            appBar: AppBar(title: const Text('Edit profile')),
            body: body,
          );
        },
      ),
    );
  }

  Widget _buildForm({required bool isSaving}) {
    const gap = SizedBox(height: AppTokens.space16);

    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            autovalidateMode: _submitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            // Not a lazy list: every field stays mounted, so validate()
            // checks all of them.
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppTokens.gutter,
                AppTokens.space8,
                AppTokens.gutter,
                AppTokens.space32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _aboutSection(),
                  gap,
                  _intentSection(),
                  gap,
                  _pitchSection(),
                  gap,
                  _languageSection(),
                  gap,
                  _interestSection(),
                  gap,
                  _skillsSection(),
                  gap,
                  _detailsSection(),
                ],
              ),
            ),
          ),
        ),
        _SaveBar(saving: isSaving, onSave: _save),
      ],
    );
  }

  Widget _aboutSection() {
    return EditSection(
      illustration: Illustrations.technologist,
      title: 'About you',
      subtitle: 'How other builders will see you.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Display name'),
          TextFormField(
            key: _nameFieldKey,
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(hintText: 'Your full name'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Name is required';
              }
              if (v.trim().length > 100) {
                return 'Name must be under 100 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: AppTokens.space16),
          const FieldLabel('Bio', optional: true),
          TextFormField(
            key: _bioFieldKey,
            controller: _bioCtrl,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Tell developers about yourself...',
            ),
            validator: (v) {
              if (v != null && v.length > 500) {
                return 'Bio must be under 500 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _intentSection() {
    const intents = CollabConstants.intents;
    return EditSection(
      key: _intentSectionKey,
      illustration: Illustrations.handshake,
      title: 'What brings you here?',
      subtitle: 'Pick all that apply.',
      errorText: _showIntentError ? 'Pick at least one' : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < intents.length; i++) ...[
            if (i > 0) const SizedBox(height: AppTokens.space8),
            OptionCard(
              title: intents[i].label,
              illustration: intentIllustration(intents[i].key),
              illustrationSize: 40,
              selected: _lookingFor.contains(intents[i].key),
              onTap: () => _toggleIntent(intents[i].key),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pitchSection() {
    final palette = context.palette;
    return EditSection(
      illustration: Illustrations.rocket,
      title: 'What are you building?',
      subtitle: 'A one-line pitch shown on your card.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: _pitchFieldKey,
            controller: _pitchCtrl,
            minLines: 3,
            maxLines: 5,
            maxLength: CollabConstants.pitchMaxLength,
            // The counter below counts code points, like the database.
            buildCounter: _noCounter,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What are you building, and who do you need?',
            ),
            validator: (v) {
              if (v != null &&
                  v.trim().runes.length > CollabConstants.pitchMaxLength) {
                return 'Pitch must be at most '
                    '${CollabConstants.pitchMaxLength} characters';
              }
              return null;
            },
          ),
          const SizedBox(height: AppTokens.space8),
          _PitchCounter(controller: _pitchCtrl),
          const SizedBox(height: AppTokens.space12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Illustration(Illustrations.lightBulb, size: 22),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: Text(
                  'Tip: name the project and the kind of teammate you need.',
                  style: AppTextStyles.bodySm(palette.inkMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _languageSection() {
    return EditSection(
      key: _languageSectionKey,
      illustration: Illustrations.laptop,
      title: 'Your languages',
      subtitle: 'The languages you code in.',
      errorText: _showLanguageError ? 'Add at least one language' : null,
      child: TagPicker(
        options: _languageOptions,
        isSelected: (option) => _containsIgnoreCase(_languages, option),
        onToggle: _toggleLanguage,
        onAdd: _addLanguages,
        addHint: 'Add another language',
      ),
    );
  }

  Widget _interestSection() {
    return EditSection(
      key: _interestSectionKey,
      illustration: Illustrations.sparkles,
      title: 'Your interests',
      subtitle: 'Topics you care about.',
      errorText: _showInterestError ? 'Add at least one interest' : null,
      child: TagPicker(
        options: _interestOptions,
        isSelected: (option) => _containsIgnoreCase(_interests, option),
        onToggle: _toggleInterest,
        onAdd: _addInterests,
        addHint: 'Add another interest',
      ),
    );
  }

  Widget _skillsSection() {
    return EditSection(
      illustration: Illustrations.magnifyingGlass,
      title: "Skills you're looking for",
      subtitle: 'Optional: what should a collaborator bring?',
      child: TagPicker(
        options: _skillOptions,
        isSelected: (option) => _containsIgnoreCase(_seekingSkills, option),
        onToggle: _toggleSkill,
        onAdd: _addSkills,
        addHint: 'Add another skill',
      ),
    );
  }

  Widget _detailsSection() {
    return EditSection(
      illustration: Illustrations.memo,
      title: 'Details',
      subtitle: 'Optional, but they help people plan.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Location', optional: true),
          TextFormField(
            key: _locationFieldKey,
            controller: _locationCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'City, Country',
              prefixIcon: Icon(PhosphorIconsBold.mapPin, size: 20),
            ),
            validator: (v) {
              if (v != null && v.length > 100) {
                return 'Location must be under 100 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: AppTokens.space16),
          const FieldLabel('Company', optional: true),
          TextFormField(
            key: _companyFieldKey,
            controller: _companyCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Where do you work?',
              prefixIcon: Icon(PhosphorIconsBold.buildings, size: 20),
            ),
            validator: (v) {
              if (v != null && v.length > 100) {
                return 'Company must be under 100 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: AppTokens.space16),
          const FieldLabel('Website', optional: true),
          TextFormField(
            key: _websiteFieldKey,
            controller: _websiteCtrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'https://yoursite.com',
              prefixIcon: Icon(PhosphorIconsBold.link, size: 20),
            ),
            validator: (v) {
              if (v != null && v.trim().isNotEmpty) {
                final uri = Uri.tryParse(v.trim());
                // http(s) only: other schemes (e.g. javascript:) become
                // unsafe links elsewhere.
                if (uri == null ||
                    !(uri.isScheme('http') || uri.isScheme('https')) ||
                    uri.host.isEmpty) {
                  return 'Enter a valid URL (e.g. https://...)';
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  static Widget? _noCounter(
    BuildContext context, {
    required int currentLength,
    required int? maxLength,
    required bool isFocused,
  }) =>
      null;
}

/// Characters used out of 280, counted in code points (`runes`) like the
/// database's `char_length`, with a small bar that turns gold near the
/// limit and red past it.
class _PitchCounter extends StatelessWidget {
  const _PitchCounter({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        const limit = CollabConstants.pitchMaxLength;
        final palette = context.palette;
        final used = value.text.trim().runes.length;
        final over = used > limit;
        final tone = over
            ? AppTone.danger
            : (used >= limit * 0.9 ? AppTone.gold : AppTone.green);
        final textColor =
            over ? palette.toneText(AppTone.danger) : palette.inkMuted;

        return Semantics(
          label: 'Pitch length',
          value: '$used of $limit characters',
          child: ExcludeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: GaProgressBar(
                    value: used / limit,
                    tone: tone,
                    height: 8,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$used / $limit',
                  style: AppTextStyles.bodySm(textColor).copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The sticky bottom bar with the 3D save button. It sits in the body, so
/// it stays visible above the keyboard.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.saving, required this.onSave});

  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.bg,
        border: Border(
          top: BorderSide(color: palette.border, width: AppTokens.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppTokens.gutter,
          AppTokens.space12,
          AppTokens.gutter,
          AppTokens.space12,
        ),
        child: PressableButton(
          label: 'Save changes',
          icon: PhosphorIconsBold.check,
          loading: saving,
          semanticLabel: saving ? 'Saving your profile' : 'Save changes',
          onPressed: onSave,
        ),
      ),
    );
  }
}

/// Placeholder shaped like the form while the profile loads.
class _EditSkeleton extends StatelessWidget {
  const _EditSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading your profile',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppTokens.gutter,
          AppTokens.space8,
          AppTokens.gutter,
          AppTokens.space32,
        ),
        children: [
          GaSkeleton(height: 240, radius: AppTokens.radiusLg),
          const SizedBox(height: AppTokens.space16),
          GaSkeleton(height: 360, radius: AppTokens.radiusLg),
          const SizedBox(height: AppTokens.space16),
          GaSkeleton(height: 200, radius: AppTokens.radiusLg),
        ],
      ),
    );
  }
}
