import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:heroicons/heroicons.dart';
import 'package:parla/main.dart';
import 'package:parla/riverpod/auth_provider.dart';
import 'package:parla/services/firestore_service.dart';
import 'package:parla/utils/encryption/key_generator.dart';
import 'package:parla/utils/logger/app_logger.dart';
import 'package:parla/utils/logger/auth_exception_format.dart';
import 'package:parla/utils/overlay/overlay_util.dart';
import 'package:parla/utils/widgets/google_signin_button.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with TickerProviderStateMixin {
  final usernameSuggestionsProvider = StateProvider<List<String>>((ref) => []);
  final obscureTextProvider = StateProvider<bool>((ref) => true);
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final FAutocompleteController _usernameController;
  final _formKey = GlobalKey<FormState>();
  Timer? _usernameTimer;

  @override
  void initState() {
    super.initState();
    _usernameController = FAutocompleteController(vsync: this);
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onUsernameChanged(String value) async {
    _usernameTimer?.cancel();

    final v = value.trim().toLowerCase();
    if (v.length < 3) {
      ref.read(usernameSuggestionsProvider.notifier).state = [];
      return;
    }

    _usernameTimer = Timer(const Duration(milliseconds: 300), () async {
      final auth = ref.read(authProvider.notifier);
      final available = await auth.isUsernameAvailable(v);

      if (available) {
        ref.read(usernameSuggestionsProvider.notifier).state = [];
        return;
      }

      final suggestions = await auth.generateSuggestions(v);

      ref.read(usernameSuggestionsProvider.notifier).state = suggestions;
    });
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final username = _usernameController.text.trim().toLowerCase();

      try {
        final user = await _createUser(email, password);
        if (user == null) return;

        final publicKey = await KeyGenerator.generateAndStoreKey();
        AppLogger.info(
          name: "Signup Screen",
          message: "Generated public key for user ${user.uid}",
        );

        await FirestoreService.createUserDocument(
          uid: user.uid,
          email: email,
          username: username,
          publicKey: publicKey,
        );
      } catch (e) {
        AppLogger.error(
          name: "Signup Screen",
          message: "Unexpected error during signup",
          exception: e,
        );
        OverlayUtil.showTopOverlay(
          "An unexpected error occurred. Please try again.",
        );
      }
    }
  }

  Future<User?> _createUser(String email, String password) async {
    try {
      final auth = ref.read(authProvider.notifier);
      final user = await auth.createUserWithEmail(email, password);
      AppLogger.info(
        name: "Signup Auth",
        message: "User signed up: ${user.uid}",
      );
      return user;
    } catch (e, st) {
      final formatted = AuthExceptionFormatter.format(e);
      AppLogger.error(
        name: "Signup Auth",
        message: formatted.title,
        exception: e,
        stackTrace: st,
      );
      OverlayUtil.showTopOverlay(formatted.message);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final obscurePassword = ref.watch(obscureTextProvider);
    final suggestions = ref.watch(usernameSuggestionsProvider);

    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AppRoot()),
        );
      });
      return const SizedBox.shrink();
    }

    return FScaffold(
      header: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Sign Up'),
            SizedBox(width: 8),
            HeroIcon(HeroIcons.userPlus, size: 20, style: HeroIconStyle.mini),
          ],
        ),
        centerTitle: false,
      ),
      footer: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16),
        child: Text(
          'By signing up, you agree to our Terms and Conditions.',
          style: FTheme.of(context).typography.sm.copyWith(color: Colors.grey),
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
                    "Create your account",
                    style: FTheme.of(context).typography.xl2,
                  ),
                  Image.asset("assets/logo/Parla.png", height: 200, width: 128),
                ],
              ),
            ),

            FAutocomplete.builder(
              filter: (query) async {
                if (suggestions.isEmpty) {
                  return [query];
                }
                return suggestions;
              },
              contentBuilder: (context, text, items) => [
                for (final i in items) FAutocompleteItem(value: i),
              ],
              controller: _usernameController,
              label: Text(
                "Username",
                style: FTheme.of(context).typography.xs.copyWith(
                  color: FTheme.of(context).colors.mutedForeground,
                ),
              ),
              hint: 'Choose a username',
              prefixBuilder: (context, style, states) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: HeroIcon(HeroIcons.user),
              ),
              suffixBuilder: (context, style, states) => suggestions.isEmpty
                  ? SizedBox.shrink()
                  : HeroIcon(HeroIcons.chevronDown),
              onChange: (value) {
                _onUsernameChanged(value);
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Enter a username";
                }
                final v = value.trim();
                if (v.length < 3) {
                  return "At least 3 characters";
                }
                if (v.length > 25) {
                  return "Maximum 25 characters";
                }
                final regex = RegExp(r'^[a-zA-Z0-9]+$');
                if (!regex.hasMatch(v)) {
                  return "Only letters or digits allowed";
                }
                if (suggestions.isNotEmpty) {
                  return "Username not available";
                }
                return null;
              },

              popoverConstraints: const FAutoWidthPortalConstraints(
                maxHeight: 200,
              ),
              rightArrowToComplete: true,
              clearable: (value) => value.text.isNotEmpty,
            ),

            const SizedBox(height: 12),

            FTextFormField(
              controller: _emailController,
              style: (original) {
                return original.copyWith(
                  contentTextStyle: FWidgetStateMap.all(
                    FTheme.of(context).typography.base,
                  ),
                );
              },
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
                final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!regex.hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

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
                final regex = RegExp(
                  r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
                );
                if (!regex.hasMatch(value)) {
                  return 'Password must contain uppercase, lowercase, number and special character';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FButton(
                  onPress: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AppRoot(),
                        ),
                      );
                    }
                  },
                  style: FButtonStyle.outline(),
                  child: Row(
                    children: [
                      HeroIcon(
                        HeroIcons.arrowLeft,
                        size: 16,
                        style: HeroIconStyle.solid,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Sign in",
                        style: FTheme.of(
                          context,
                        ).typography.xs.copyWith(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                SizedBox(
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
                    child: const Text("Sign up"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const GoogleSignInButton(),
          ],
        ),
      ),
    );
  }
}
