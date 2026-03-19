import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

class RoleSelectionPage extends ConsumerWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final user = controller.currentUser;
    final roles = controller.availableRoles;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PulseBackdrop(
        child: SafeArea(
          child: PulsePageScroll(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose a mode',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await ref.read(appControllerProvider).signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PulseHeroCard(
                eyebrow: 'Multi-role access',
                title: 'Welcome back, ${user?.name ?? 'Operator'}',
                description:
                    'This account can work in multiple parts of the platform. Pick the workspace you want to enter now.',
                icon: Icons.layers_outlined,
                tags: [
                  PulseTag(
                    user?.district ?? 'Alatau Central',
                    icon: Icons.location_on_outlined,
                    backgroundColor: const Color(0x2BFFFFFF),
                    foregroundColor: Colors.white,
                  ),
                  PulseTag(
                    '${roles.length} roles available',
                    icon: Icons.badge_outlined,
                    backgroundColor: const Color(0x2BFFFFFF),
                    foregroundColor: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              PulseWrapGrid(
                minItemWidth: 220,
                children: roles.map((role) => _RoleCard(role: role)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends ConsumerWidget {
  const _RoleCard({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = _roleAccent(role);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => ref.read(appControllerProvider).selectRole(role),
        child: Container(
          constraints: const BoxConstraints(minHeight: 230),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0A0F1C),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(_roleIcon(role), color: accent),
              ),
              const SizedBox(height: 20),
              PulseTag(
                switch (role) {
                  UserRole.resident => 'Community',
                  UserRole.emergencyService => 'Rapid response',
                  UserRole.government => 'Coordination',
                  UserRole.admin => 'Platform control',
                },
                backgroundColor: accent.withValues(alpha: 0.10),
                foregroundColor: accent,
              ),
              const SizedBox(height: 14),
              Text(
                role.label,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                role.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Open workspace',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _roleAccent(UserRole role) {
  return switch (role) {
    UserRole.resident => AppConstants.secondaryAccentColor,
    UserRole.emergencyService => AppConstants.accent2Color,
    UserRole.government => AppConstants.mainAccentColor,
    UserRole.admin => const Color(0xFF111827),
  };
}

IconData _roleIcon(UserRole role) {
  return switch (role) {
    UserRole.resident => Icons.home_work_outlined,
    UserRole.emergencyService => Icons.health_and_safety_outlined,
    UserRole.government => Icons.apartment_outlined,
    UserRole.admin => Icons.admin_panel_settings_outlined,
  };
}
