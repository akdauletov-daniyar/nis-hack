import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/demo_app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';
import '../role_switch/role_selection_page.dart';
import '../shell/role_shell.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);

    if (!controller.isAuthenticated) {
      return const DemoSignInPage();
    }

    if (controller.activeRole == null) {
      return const RoleSelectionPage();
    }

    return RoleShell(
      key: ValueKey(controller.activeRole),
      role: controller.activeRole!,
    );
  }
}

class DemoSignInPage extends ConsumerWidget {
  const DemoSignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Alatau Pulse',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Barrier-Free Alatau keeps residents, responders, city teams, and admins in one mobile command flow.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const PulseSectionCard(
                    title: 'Hackathon MVP focus',
                    subtitle:
                        'A seeded mobile experience with role switching, reporting, incident response, and accessibility-first routing.',
                    child: Column(
                      children: [
                        _BulletLine('Fast resident reporting and SOS'),
                        SizedBox(height: 10),
                        _BulletLine('Emergency queue and status workflow'),
                        SizedBox(height: 10),
                        _BulletLine('Government review, assignment, and alerts'),
                        SizedBox(height: 10),
                        _BulletLine('Admin moderation and role management'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'demo@alatau.city',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: controller.signInDemo,
                    icon: const Icon(Icons.login),
                    label: const Text('Enter Demo Workspace'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: controller.signInDemo,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Quick Start with Multi-Role Account'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'The demo account includes Resident, Emergency Service, Government, and Admin roles so you can switch modes live.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 8),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    );
  }
}
