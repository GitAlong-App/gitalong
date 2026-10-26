// On a device or emulator:
//   flutter test integration_test/app_flow_test.dart -d <device-id>
// Headless (no device), the same flows run via:
//   flutter test test/integration_flows_test.dart

import 'package:integration_test/integration_test.dart';

import 'flows/app_flows.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  defineAppFlows();
}
