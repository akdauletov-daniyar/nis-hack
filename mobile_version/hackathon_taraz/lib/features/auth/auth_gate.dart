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
  final _signInFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
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
    final viewportHeight =
        MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.vertical;
    final authSectionMinHeight = viewportHeight > 44
        ? viewportHeight - 44
        : 0.0;

    final authCard = PulseSectionCard(
      title: _isRegisterMode ? 'Create account' : 'Sign in',
      subtitle: _isRegisterMode
          ? 'Residents can register with email, phone, and district details.'
          : 'Use your existing email and password to continue.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.login),
                label: Text('Sign In'),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.person_add_alt_1),
                label: Text('Register'),
              ),
            ],
            selected: {_isRegisterMode},
            onSelectionChanged: (value) {
              setState(() => _isRegisterMode = value.first);
              ref.read(appControllerProvider).dismissMessage();
            },
          ),
          const SizedBox(height: 20),
          if (controller.authError != null)
            _InfoBanner(
              color: const Color(0xFFFDE8E8),
              textColor: const Color(0xFFB42318),
              message: controller.authError!,
            ),
          if (controller.authMessage != null)
            _InfoBanner(
              color: const Color(0xFFE7F6EC),
              textColor: const Color(0xFF166534),
              message: controller.authMessage!,
            ),
          if (_isRegisterMode)
            _RegisterForm(
              formKey: _registerFormKey,
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
                if (!_registerFormKey.currentState!.validate()) {
                  return;
                }
                await ref
                    .read(appControllerProvider)
                    .registerWithEmail(
                      fullName: _nameController.text.trim(),
                      phone: _phoneController.text.trim(),
                      email: _registerEmailController.text.trim(),
                      password: _registerPasswordController.text,
                      district: _selectedDistrict,
                    );
              },
            )
          else
            _SignInForm(
              formKey: _signInFormKey,
              isBusy: controller.isBusy,
              emailController: _signInEmailController,
              passwordController: _signInPasswordController,
              onSubmit: () async {
                if (!_signInFormKey.currentState!.validate()) {
                  return;
                }
                await ref
                    .read(appControllerProvider)
                    .signInWithEmail(
                      email: _signInEmailController.text.trim(),
                      password: _signInPasswordController.text,
                    );
              },
            ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PulseBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: authSectionMinHeight,
                      ),
                      child: Center(child: authCard),
                    ),
                    const SizedBox(height: 18),
                    const PulseSectionCard(
                      title: 'What is already connected',
                      subtitle:
                          'The data layer can stay as-is for now. This pass focuses on the UI and the mobile experience.',
                      child: PulseWrapGrid(
                        minItemWidth: 180,
                        children: [
                          PulseActionTile(
                            title: 'Role switching',
                            subtitle:
                                'One account can move between resident, emergency, government, and admin views.',
                            icon: Icons.swap_horiz_rounded,
                          ),
                          PulseActionTile(
                            title: 'Accessibility routing',
                            subtitle:
                                'Barrier-aware map and route summaries adapt to mobility profiles.',
                            icon: Icons.route_outlined,
                          ),
                          PulseActionTile(
                            title: 'Live workflows',
                            subtitle:
                                'Reports, incidents, alerts, and notifications already load into the interface.',
                            icon: Icons.hub_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
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
    required this.formKey,
    required this.isBusy,
    required this.emailController,
    required this.passwordController,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final bool isBusy;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: emailController,
            enabled: !isBusy,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter your email address.';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Enter a valid email address.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            enabled: !isBusy,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter your password.';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters.';
              }
              return null;
            },
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
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.formKey,
    required this.isBusy,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.passwordController,
    required this.selectedDistrict,
    required this.onDistrictChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
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
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: nameController,
            enabled: !isBusy,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value == null || value.trim().length < 2) {
                return 'Enter your full name.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: phoneController,
            enabled: !isBusy,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Icon(Icons.phone_outlined),
              hintText: '+7 700 123 4567',
            ),
            validator: (value) {
              if (value == null || value.trim().length < 6) {
                return 'Enter a phone number.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: emailController,
            enabled: !isBusy,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter your email address.';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Enter a valid email address.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            enabled: !isBusy,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter a password.';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          PulseDropdownField<String>(
            label: 'District',
            prefixIcon: Icons.location_city_outlined,
            value: selectedDistrict,
            options: AppConstants.districts
                .map(
                  (district) => PulseDropdownOption(
                    value: district,
                    label: district,
                    icon: Icons.location_on_outlined,
                  ),
                )
                .toList(),
            onChanged: isBusy ? null : onDistrictChanged,
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
      ),
    );
  }
}

class SetupRequiredPage extends StatelessWidget {
  const SetupRequiredPage({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PulseBackdrop(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                      const SizedBox(height: 18),
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
        ),
      ),
    );
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PulseBackdrop(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 72,
                width: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading sonar...',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
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
        style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}
