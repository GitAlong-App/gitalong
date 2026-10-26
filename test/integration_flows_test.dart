// Headless runner for the end-to-end app flows in integration_test/flows/
// (the real app, router and blocs on in-memory fakes):
//   flutter test test/integration_flows_test.dart

import '../integration_test/flows/app_flows.dart';

void main() => defineAppFlows();
