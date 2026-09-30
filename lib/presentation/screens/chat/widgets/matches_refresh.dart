import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../bloc/matches/matches_bloc.dart';
import '../../../bloc/matches/matches_event.dart';

/// Pull-to-refresh for the shared [MatchesBloc] (Matches and Chats tabs).
///
/// Asks for a silent refresh and keeps the spinner up until new data lands,
/// or for a moment when nothing changed (the bloc doesn't re-emit an
/// identical list, and a failed refresh keeps the current one).
Future<void> refreshMatchesSilently(MatchesBloc matchesBloc) async {
  if (matchesBloc.isClosed) return;
  matchesBloc.add(RefreshMatchesEvent());
  try {
    await Future.any<void>([
      matchesBloc.stream.first.then((_) {}),
      Future<void>.delayed(const Duration(milliseconds: 1200)),
    ]);
  } catch (_) {
    // Closed while waiting: nothing left to wait for.
  }
}

/// A full-height, pull-to-refreshable area with [child] centred in it, for
/// empty and error states (`EmptyState` brings its own padding).
class RefreshableFill extends StatelessWidget {
  const RefreshableFill({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.green,
      backgroundColor: context.palette.card,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}
