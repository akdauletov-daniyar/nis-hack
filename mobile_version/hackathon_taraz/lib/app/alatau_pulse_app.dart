import 'package:flutter/material.dart';

import '../features/auth/auth_gate.dart';
import 'theme/app_theme.dart';

class AlatauPulseApp extends StatelessWidget {
  const AlatauPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alatau Pulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}
