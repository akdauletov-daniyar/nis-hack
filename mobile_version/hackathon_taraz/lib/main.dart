import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/alatau_pulse_app.dart';

const _supabaseUrl = 'https://zqbxyicjbwwuimcnlubk.supabase.co';
const _supabasePublishableKey =
    'sb_publishable_md1zyIus802aotehM_OE4A_9o2KfFpc';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabasePublishableKey,
  );

  runApp(const ProviderScope(child: AlatauPulseApp()));
}
