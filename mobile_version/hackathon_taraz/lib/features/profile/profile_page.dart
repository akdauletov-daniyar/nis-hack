import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final user = controller.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PulseSectionCard(
          title: user.name,
          subtitle: '${user.email} • ${user.phone}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.roles
                    .map((role) => Chip(label: Text(role.shortLabel)))
                    .toList(),
              ),
              const SizedBox(height: 12),
              Text('Primary district: ${user.district}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Accessibility preferences',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active profile: ${user.profile.mobilityType.label}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (user.profile.avoidStairs) const Chip(label: Text('Avoid stairs')),
                  if (user.profile.avoidSteepSlopes)
                    const Chip(label: Text('Avoid steep slopes')),
                  if (user.profile.avoidBrokenElevators)
                    const Chip(label: Text('Avoid broken elevators')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PulseSectionCard(
          title: 'Saved places',
          child: Column(
            children: user.savedPlaces
                .map(
                  (place) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.bookmark_outline),
                    ),
                    title: Text(place),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
