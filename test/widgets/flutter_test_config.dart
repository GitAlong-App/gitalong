import 'dart:async';

import 'helpers.dart';

/// Runs before every test file in `test/widgets/` (see helpers.dart).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  configureWidgetTests();
  await testMain();
}
