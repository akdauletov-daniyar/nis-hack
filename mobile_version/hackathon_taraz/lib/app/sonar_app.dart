import 'package:flutter/material.dart';

import '../features/auth/auth_gate.dart';
import 'theme/app_theme.dart';

class SonarApp extends StatelessWidget {
  const SonarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SONAR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}
