import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/state/app_controller.dart';
import '../../shared/widgets/pulse_ui.dart';
import '../role_switch/role_selection_page.dart';
import '../shell/role_shell.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);

    if (controller.isHydrating) {
      return const _SplashPage();
    }

    if (!controller.isAuthenticated) {
      return const AuthPage();
    }

    if (controller.currentUser == null) {
      return SetupRequiredPage(message: controller.dataError);
    }

    if (controller.activeRole == null && controller.availableRoles.length > 1) {
      return const RoleSelectionPage();
    }

    return RoleShell(
      key: ValueKey(controller.activeRole ?? controller.availableRoles.first),
      role: controller.activeRole ?? controller.availableRoles.first,
    );
  }
}

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();

  bool _isRegisterMode = false;
  String _selectedDistrict = AppConstants.defaultDistrict;

  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.15),
              theme.colorScheme.surface,
              theme.colorScheme.tertiary.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  elevation: 24,
                  shadowColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Alatau Pulse',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Barrier-Free Alatau is now connected to Supabase. Residents sign in with email and password, while the phone number is saved for later emergency contact.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SegmentedButton<bool>(
                          style: SegmentedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          segments: const [
                            ButtonSegment<bool>(
                              value: false,
                              icon: Icon(Icons.login),
                              label: Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            ButtonSegment<bool>(
                              value: true,
                              icon: Icon(Icons.person_add_alt_1),
                              label: Text('Register', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                          selected: {_isRegisterMode},
                          onSelectionChanged: (value) {
                            setState(() => _isRegisterMode = value.first);
                            ref.read(appControllerProvider).dismissMessage();
                          },
                        ),
                        const SizedBox(height: 32),
                        if (controller.authError != null)
                          _InfoBanner(
                            color: const Color(0xFFFEE2E2),
                            textColor: const Color(0xFFB91C1C),
                            message: controller.authError!,
                          ),
                        if (controller.authMessage != null)
                          _InfoBanner(
                            color: const Color(0xFFDCFCE7),
                            textColor: const Color(0xFF166534),
                            message: controller.authMessage!,
                          ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _isRegisterMode
                              ? _RegisterForm(
                                  isBusy: controller.isBusy,
                                  nameController: _nameController,
                                  phoneController: _phoneController,
                                  emailController: _registerEmailController,
                                  passwordController: _registerPasswordController,
                                  selectedDistrict: _selectedDistrict,
                                  onDistrictChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedDistrict = value);
                                    }
                                  },
                                  onSubmit: () async {
                                    await ref.read(appControllerProvider).registerWithEmail(
                                          fullName: _nameController.text,
                                          phone: _phoneController.text,
                                          email: _registerEmailController.text,
                                          password: _registerPasswordController.text,
                                          district: _selectedDistrict,
                                        );
                                  },
                                )
                              : _SignInForm(
                                  isBusy: controller.isBusy,
                                  emailController: _signInEmailController,
                                  passwordController: _signInPasswordController,
                                  onSubmit: () async {
                                    await ref.read(appControllerProvider).signInWithEmail(
                                          email: _signInEmailController.text,
                                          password: _signInPasswordController.text,
                                        );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInForm extends StatelessWidget {
  const _SignInForm({
    required this.isBusy,
    required this.emailController,
    required this.passwordController,
    required this.onSubmit,
  });

  final bool isBusy;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: isBusy ? null : onSubmit,
          icon: isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: const Text('Sign In'),
        ),
      ],
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.isBusy,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.passwordController,
    required this.selectedDistrict,
    required this.onDistrictChanged,
    required this.onSubmit,
  });

  final bool isBusy;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String selectedDistrict;
  final ValueChanged<String?> onDistrictChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Full name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            prefixIcon: Icon(Icons.phone_outlined),
            hintText: '+7 700 123 4567',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedDistrict,
          decoration: const InputDecoration(
            labelText: 'District',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          items: AppConstants.districts.map((district) {
            return DropdownMenuItem(
              value: district,
              child: Text(district),
            );
          }).toList(),
          onChanged: onDistrictChanged,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: isBusy ? null : onSubmit,
          icon: isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_alt_1),
          label: const Text('Create Account'),
        ),
      ],
    );
  }
}

class SetupRequiredPage extends StatelessWidget {
  const SetupRequiredPage({
    super.key,
    this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: PulseSectionCard(
              title: 'Database setup required',
              subtitle:
                  'The app is connected to Supabase, but the required schema is not available yet.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message ??
                        'Run the SQL from supabase/schema.sql in your Supabase SQL Editor, then sign in again.',
                  ),
                  const SizedBox(height: 16),
                  const SelectableText(
                    '1. Open Supabase Dashboard\n'
                    '2. Go to SQL Editor\n'
                    '3. Run the contents of supabase/schema.sql\n'
                    '4. Relaunch the app',
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

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading Alatau Pulse...'),
          ],
        ),
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet(this.text);

  final String text;

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
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.color,
    required this.textColor,
    required this.message,
  });

  final Color color;
  final Color textColor;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
