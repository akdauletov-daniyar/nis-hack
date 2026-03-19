import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hackathon_taraz/app/alatau_pulse_app.dart';

void main() {
  testWidgets('shows the demo sign-in flow', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AlatauPulseApp()),
    );

    expect(find.text('Alatau Pulse'), findsOneWidget);
    expect(find.text('Enter Demo Workspace'), findsOneWidget);
  });
}
