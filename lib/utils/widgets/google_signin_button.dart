import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:parla/riverpod/auth_provider.dart';
import 'package:parla/services/firestore_service.dart';
import 'package:parla/utils/encryption/key_generator.dart';
import 'package:parla/utils/logger/app_logger.dart';
import 'package:parla/utils/logger/auth_exception_format.dart';
import 'package:parla/utils/overlay/overlay_util.dart';
import 'package:parla/utils/widgets/gradient_text.dart';

class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> handleTap() async {
      try {
        final auth = ref.read(authProvider.notifier);
        final userCred = await auth.signInWithGoogle();
        final user = userCred.user;

        if (user == null) return;

        final isNew = userCred.additionalUserInfo?.isNewUser ?? false;
        if (!isNew) return;
        final name = user.displayName ?? user.email!.split("@")[0];
        String username = name.replaceAll(' ', '').toLowerCase();
        final available = await auth.isUsernameAvailable(username);

        if (!available) {
          final suggestions = await auth.generateSuggestions(username);
          username = suggestions.first;
        }

        final publicKey = await KeyGenerator.generateAndStoreKey();
        AppLogger.info(
          name: "Google Sign-In",
          message: "Generated public key for user ${user.uid}",
        );

        await FirestoreService.createUserDocument(
          uid: user.uid,
          email: user.email!,
          username: username,
          displayName: name,
          photoURL: user.photoURL,
          publicKey: publicKey,
        );
      } catch (e, st) {
        final formatted = AuthExceptionFormatter.format(e);
        AppLogger.error(
          name: "Google Sign-In",
          message: formatted.title,
          exception: e,
          stackTrace: st,
        );
        OverlayUtil.showTopOverlay(formatted.message);
      }
    }

    return GestureDetector(
      onTap: handleTap,
      child: FCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              "assets/logo/google_logo.png",
              width: 24,
              height: 24,
              alignment: Alignment.center,
            ),
            const SizedBox(width: 12),
            Baseline(
              baseline: 18,
              baselineType: TextBaseline.alphabetic,
              child: GradientText(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF4285F4),
                    Color(0xFFEA4335),
                    Color(0xFFFBBC05),
                    Color(0xFF34A853),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                text: "Sign in with Google",
                style: FTheme.of(context).typography.lg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
