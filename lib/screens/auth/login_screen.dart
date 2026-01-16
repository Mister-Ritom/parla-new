import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:heroicons/heroicons.dart';
import 'package:parla/main.dart';
import 'package:parla/riverpod/auth_provider.dart';
import 'package:parla/screens/auth/signup_screen.dart';
import 'package:parla/utils/logger/app_logger.dart';
import 'package:parla/utils/logger/auth_exception_format.dart';
import 'package:parla/utils/overlay/overlay_util.dart';
import 'package:parla/utils/widgets/google_signin_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final obscureTextProvider = StateProvider<bool>((ref) => true);
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  final _formKey = GlobalKey<FormState>();

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();
        final auth = ref.read(authProvider.notifier);
        await auth.signInWithEmail(email, password);
      } catch (e, st) {
        final formattedException = AuthExceptionFormatter.format(e);
        AppLogger.error(
          name: "Login Screen",
          message: formattedException.title,
          exception: e,
          stackTrace: st,
        );
        OverlayUtil.showTopOverlay(formattedException.message);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final obscurePassword = ref.watch(obscureTextProvider);
    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) {
            return AppRoot();
          },
        ),
      );
      return SizedBox.shrink();
    }
    return FScaffold(
      header: AppBar(
        leading: HeroIcon(HeroIcons.userGroup, style: HeroIconStyle.solid),
        title: const Text('Login'),
        centerTitle: false,
      ),
      footer: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16),
        child: Text(
          'By signing in, you agree to our Terms and Conditions.',
          style: FTheme.of(context).typography.sm.copyWith(
            color: FTheme.of(context).colors.mutedForeground,
          ),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Welcome Back!",
                    style: FTheme.of(context).typography.xl2,
                  ),
                  Image.asset("assets/logo/Parla.png", height: 200, width: 128),
                ],
              ),
            ),
            FTextFormField(
              controller: _emailController,
              label: Text(
                "Email Address",
                style: FTheme.of(context).typography.xs.copyWith(
                  color: FTheme.of(context).colors.mutedForeground,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                //Basic email validation
                final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!regex.hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            SizedBox(height: 12),
            FTextFormField(
              controller: _passwordController,
              label: Text(
                "Password",
                style: FTheme.of(context).typography.xs.copyWith(
                  color: FTheme.of(context).colors.mutedForeground,
                ),
              ),
              obscureText: obscurePassword,
              suffixBuilder: (context, style, states) => FButton.icon(
                onPress: () {
                  ref.read(obscureTextProvider.notifier).state = !ref.read(
                    obscureTextProvider,
                  );
                },
                child: Icon(obscurePassword ? FIcons.eyeClosed : FIcons.eye),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 8) {
                  return 'Password must be at least 8 characters long';
                }
                //Password must have at least one uppercase letter, one lowercase letter, one number and one special character
                final regex = RegExp(
                  r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
                );
                if (!regex.hasMatch(value)) {
                  return 'Password must contain uppercase, lowercase, number and special character';
                }
                return null;
              },
            ),
            SizedBox(height: 12),
            //Row of forgot password and sign up button
            SizedBox(
              height: 42,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      "Forgot Password?",
                      style: FTheme.of(context).typography.sm.copyWith(
                        color: FTheme.of(context).colors.mutedForeground,
                      ),
                    ),
                  ),
                  FButton(
                    onPress: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignupScreen(),
                        ),
                      );
                    },
                    style: FButtonStyle.outline(),
                    child: Text(
                      "Sign Up",
                      style: FTheme.of(
                        context,
                      ).typography.xs.copyWith(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 128,
                child: FButton(
                  onPress: _submitForm,
                  style: FButtonStyle.outline((original) {
                    return original.copyWith(
                      decoration: original.decoration.map((box) {
                        return box.copyWith(
                          border: Border.all(
                            color: FTheme.of(context).colors.primary,
                            width: 1.5,
                          ),
                        );
                      }),
                    );
                  }),
                  child: Text("Sign in"),
                ),
              ),
            ),
            SizedBox(height: 24),
            GoogleSignInButton(),
          ],
        ),
      ),
    );
  }
}
