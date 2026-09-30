import 'package:injectable/injectable.dart';

import '../../entities/swipe_entity.dart';
import '../../entities/match_entity.dart';
import '../../repositories/swipe_repository.dart';

/// Swipe user use case
@injectable
class SwipeUserUseCase {
  final SwipeRepository _swipeRepository;

  const SwipeUserUseCase(this._swipeRepository);

  /// Records the swipe and returns the resulting match, if any.
  Future<MatchEntity?> call({
    required String swipedUserId,
    required SwipeAction action,
  }) {
    return _swipeRepository.swipeUser(
      swipedUserId: swipedUserId,
      action: action,
    );
  }
}
