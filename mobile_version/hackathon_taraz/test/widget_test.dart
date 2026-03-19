import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hackathon_taraz/app/alatau_pulse_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://zqbxyicjbwwuimcnlubk.supabase.co',
      anonKey: 'sb_publishable_md1zyIus802aotehM_OE4A_9o2KfFpc',
    );
  });

  testWidgets('shows the real auth flow', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AlatauPulseApp()),
    );

    expect(find.text('Alatau Pulse'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Register'), findsOneWidget);
  });
}
