import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/business_rules.dart';
import '../core/l10n.dart';
import '../core/routes.dart';
import '../providers/core_providers.dart';
import '../widgets/common.dart';

class _AuthFrame extends ConsumerWidget {
  final String title, subtitle;
  final List<Widget> children;
  const _AuthFrame({required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider).languageCode;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          gradientHeader(
            context,
            radius: 36,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                child: Column(children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                          textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Colors.white))),
                      child: LangButton(current: lang, onChanged: (c) => ref.read(localeProvider.notifier).set(c)),
                    ),
                  ),
                  const LogoMark(size: 120),
                  const SizedBox(height: 10),
                  Text('Jatoi Bin Trader',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(context.tr('tagline'), style: const TextStyle(color: Color(0xFFE8DFB5))),
                ]),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  ...children,
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final seenOnboarding = ref.read(prefsProvider).getBool('seen_onboarding') ?? false;
      final loggedIn = ref.read(authProvider) != null;
      if (loggedIn) {
        context.go(Routes.products);
        return;
      }
      context.go(seenOnboarding ? Routes.login : Routes.onboarding);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primaryContainer,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LogoMark(size: 120),
                const SizedBox(height: 18),
                Text(
                  'Jatoi Bin Trader',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
        ),
      );
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(prefsProvider).setBool('seen_onboarding', true);
    if (!mounted) return;
    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _OnboardingPage(
        icon: Icons.local_shipping_rounded,
        title: context.tr('onboarding_title_1'),
        subtitle: context.tr('onboarding_sub_1'),
      ),
      _OnboardingPage(
        icon: Icons.timeline_rounded,
        title: context.tr('onboarding_title_2'),
        subtitle: context.tr('onboarding_sub_2'),
      ),
      _OnboardingPage(
        icon: Icons.shield_rounded,
        title: context.tr('onboarding_title_3'),
        subtitle: context.tr('onboarding_sub_3'),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _finish,
                child: Text(context.tr('skip')),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (_, index) => pages[index],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < pages.length; i++)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _currentPage
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () async {
                      if (_currentPage >= pages.length - 1) {
                        await _finish();
                        return;
                      }
                      await _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Text(_currentPage >= pages.length - 1 ? context.tr('get_started') : context.tr('next')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OnboardingPage({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: s.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: s.onPrimaryContainer),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: s.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    final err = await ref.read(authProvider.notifier).login(_email.text, _pass.text);
    if (mounted) setState(() { _busy = false; _error = err; });
  }

  @override
  Widget build(BuildContext context) {
    String? req(String? v) => (v == null || v.trim().isEmpty) ? context.tr('required') : null;
    return _AuthFrame(
      title: context.tr('welcome_back'),
      subtitle: context.tr('login_sub'),
      children: [
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: fieldDec(context, context.tr('email'), icon: Icons.mail_outline),
              validator: req,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pass,
              obscureText: _hide,
              decoration: fieldDec(context, context.tr('password'), icon: Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hide = !_hide)),
              ),
              validator: req,
              onFieldSubmitted: (_) => _submit(),
            ),
          ]),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(context.tr(_error!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 20),
        FullButton(onPressed: _submit, label: context.tr('login'), busy: _busy),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => context.go(Routes.forgotPassword),
            child: Text(context.tr('forgot_password')),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: TextButton(onPressed: () => context.go(Routes.register), child: Text(context.tr('no_account')))),
        const SizedBox(height: 8),
        AppCard(
          color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr('demo_hint'), style: const TextStyle(fontSize: 12.5))),
          ]),
        ),
      ],
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    final err = await ref.read(authProvider.notifier).register(_name.text, _email.text, _pass.text);
    if (mounted) setState(() { _busy = false; _error = err; });
  }

  @override
  Widget build(BuildContext context) {
    String? req(String? v) => (v == null || v.trim().isEmpty) ? context.tr('required') : null;
    return _AuthFrame(
      title: context.tr('register'),
      subtitle: context.tr('register_sub'),
      children: [
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(controller: _name, decoration: fieldDec(context, context.tr('full_name'), icon: Icons.person_outline), validator: req),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: fieldDec(context, context.tr('email'), icon: Icons.mail_outline),
              validator: (v) => (v == null || !isValidEmail(v)) ? context.tr('invalid_email') : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pass,
              obscureText: _hide,
              decoration: fieldDec(context, context.tr('password'), icon: Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hide = !_hide)),
              ),
              validator: (v) => (v == null || v.length < 6) ? context.tr('pass_min') : null,
            ),
          ]),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(context.tr(_error!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 20),
        FullButton(onPressed: _submit, label: context.tr('register'), busy: _busy),
        const SizedBox(height: 8),
        Center(child: TextButton(onPressed: () => context.go(Routes.login), child: Text(context.tr('have_account')))),
      ],
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final message = await ref.read(authProvider.notifier).resetPassword(
      _email.text,
      _password.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (message == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('password_reset_success'))),
      );
      context.go(Routes.login);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr(message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      title: context.tr('forgot_password'),
      subtitle: context.tr('forgot_password_sub'),
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: fieldDec(context, context.tr('email'), icon: Icons.mail_outline),
                validator: (value) => (value == null || !isValidEmail(value.trim()))
                    ? context.tr('invalid_email')
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _hide,
                decoration: fieldDec(context, context.tr('new_password'), icon: Icons.lock_outline).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (value) => (value == null || value.length < 6)
                    ? context.tr('pass_min')
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: _hide,
                decoration: fieldDec(context, context.tr('password'), icon: Icons.lock_outline),
                validator: (value) {
                  if (value == null || value.isEmpty) return context.tr('required');
                  if (value != _password.text) return context.tr('password_mismatch');
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FullButton(
          onPressed: _submit,
          label: context.tr('reset_password'),
          busy: _busy,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => context.go(Routes.login),
            child: Text(context.tr('login')),
          ),
        ),
      ],
    );
  }
}
