import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthFormattedException {
  final String code;
  final String title;
  final String message;
  final Object exception;
  final String rawCode;

  AuthFormattedException({
    required this.code,
    required this.title,
    required this.message,
    required this.exception,
    required this.rawCode,
  });
}

class AuthExceptionFormatter {
  static AuthFormattedException format(Object exception) {
    if (exception is FirebaseAuthException) {
      return _fromFirebase(exception);
    }

    if (exception is GoogleSignInException) {
      return _fromGoogleException(exception);
    }

    if (exception is PlatformException) {
      return _fromGooglePlatform(exception);
    }

    final type = exception.runtimeType.toString().toLowerCase();
    if (type.contains("google") && type.contains("sign")) {
      return _fromGoogleUnknown(exception);
    }

    return AuthFormattedException(
      code: "unknown",
      title: "Unexpected Error",
      message: "Something went wrong. Please try again.",
      exception: exception,
      rawCode: "unknown",
    );
  }

  // ---------------------------------------------------------------------------
  // Firebase
  // ---------------------------------------------------------------------------
  static AuthFormattedException _fromFirebase(FirebaseAuthException e) {
    final normalized = _normalizeFirebaseCode(e.code);

    final map = <String, String>{
      "invalid_email": "The email address is invalid.",
      "user_disabled": "Your account has been disabled.",
      "user_not_found": "No account exists with this email.",
      "wrong_password": "The password you entered is incorrect.",
      "email_exists": "An account already exists with this email.",
      "weak_password": "Your password is too weak.",
      "too_many_requests": "Too many attempts. Please try again later.",
      "credential_invalid": "Your credentials are invalid.",
      "network_error": "Please check your internet connection.",
      "user_token_expired": "Your session has expired. Please log in again.",
      "operation_not_allowed": "This sign-in method is not enabled.",
      "verification_failed": "Verification failed. Try again.",
    };

    return AuthFormattedException(
      code: normalized,
      title: _toTitle(normalized),
      message: map[normalized] ?? (e.message ?? "Authentication failed."),
      exception: e,
      rawCode: e.code,
    );
  }

  static String _normalizeFirebaseCode(String code) {
    switch (code) {
      case "invalid-email":
        return "invalid_email";
      case "user-disabled":
        return "user_disabled";
      case "user-not-found":
        return "user_not_found";
      case "wrong-password":
        return "wrong_password";
      case "email-already-in-use":
        return "email_exists";
      case "weak-password":
        return "weak_password";
      case "too-many-requests":
        return "too_many_requests";
      case "invalid-credential":
      case "INVALID_LOGIN_CREDENTIALS":
        return "credential_invalid";
      case "network-request-failed":
        return "network_error";
      case "user-token-expired":
        return "user_token_expired";
      case "operation-not-allowed":
        return "operation_not_allowed";
      case "invalid-verification-code":
      case "invalid-verification-id":
        return "verification_failed";
      default:
        return "firebase_$code";
    }
  }

  // ---------------------------------------------------------------------------
  // Google — New official GoogleSignInException API
  // ---------------------------------------------------------------------------
  static AuthFormattedException _fromGoogleException(GoogleSignInException e) {
    final normalized = _normalizeGoogleEnumCode(e.code);

    final map = <String, String>{
      "google_canceled": "You cancelled Google sign-in.",
      "google_interrupted": "Google sign-in was interrupted.",
      "google_client_config": "Google Sign-In is misconfigured.",
      "google_provider_config": "Google provider configuration is invalid.",
      "google_ui_unavailable": "Google sign-in UI could not be displayed.",
      "google_user_mismatch":
          "You tried to sign in as a different Google account.",
      "google_unknown": "Google sign-in failed unexpectedly.",
    };

    return AuthFormattedException(
      code: normalized,
      title: _toTitle(normalized),
      message: map[normalized] ?? e.description ?? "Google sign-in failed.",
      exception: e,
      rawCode: e.code.name,
    );
  }

  static String _normalizeGoogleEnumCode(GoogleSignInExceptionCode code) {
    switch (code) {
      case GoogleSignInExceptionCode.canceled:
        return "google_canceled";
      case GoogleSignInExceptionCode.interrupted:
        return "google_interrupted";
      case GoogleSignInExceptionCode.clientConfigurationError:
        return "google_client_config";
      case GoogleSignInExceptionCode.providerConfigurationError:
        return "google_provider_config";
      case GoogleSignInExceptionCode.uiUnavailable:
        return "google_ui_unavailable";
      case GoogleSignInExceptionCode.userMismatch:
        return "google_user_mismatch";
      case GoogleSignInExceptionCode.unknownError:
        return "google_unknown";
    }
  }

  // ---------------------------------------------------------------------------
  // Google Sign-in (older PlatformException)
  // ---------------------------------------------------------------------------
  static AuthFormattedException _fromGooglePlatform(PlatformException e) {
    final normalized = _normalizeGooglePlatformCode(e.code);

    final map = <String, String>{
      "google_cancel": "You cancelled Google sign-in.",
      "google_failed": "Google sign-in failed.",
      "network_error": "Please check your internet connection.",
    };

    return AuthFormattedException(
      code: normalized,
      title: _toTitle(normalized),
      message: map[normalized] ?? (e.message ?? "Google sign-in failed."),
      exception: e,
      rawCode: e.code,
    );
  }

  static String _normalizeGooglePlatformCode(String code) {
    switch (code) {
      case "sign_in_canceled":
        return "google_cancel";
      case "sign_in_failed":
        return "google_failed";
      case "network_error":
        return "network_error";
      default:
        return "google_$code";
    }
  }

  // ---------------------------------------------------------------------------
  // Google fallback / unknown class types
  // ---------------------------------------------------------------------------
  static AuthFormattedException _fromGoogleUnknown(Object e) {
    return AuthFormattedException(
      code: "google_unknown",
      title: "Google Sign-In Error",
      message: "Something went wrong while signing in with Google.",
      exception: e,
      rawCode: "unknown",
    );
  }

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------
  static String _toTitle(String code) {
    return code
        .replaceAll("_", " ")
        .split(" ")
        .map((w) => "${w[0].toUpperCase()}${w.substring(1)}")
        .join(" ");
  }
}
