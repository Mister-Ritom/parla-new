import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreFormattedException {
  final String code;
  final String title;
  final String message;
  final Object exception;
  final String rawCode;

  FirestoreFormattedException({
    required this.code,
    required this.title,
    required this.message,
    required this.exception,
    required this.rawCode,
  });
}

class FirestoreExceptionFormatter {
  static FirestoreFormattedException format(Object exception) {
    if (exception is FirebaseException &&
        exception.plugin == "cloud_firestore") {
      return _fromFirebaseFirestore(exception);
    }

    return FirestoreFormattedException(
      code: "unknown",
      title: "Unexpected Error",
      message: "Something went wrong. Please try again.",
      exception: exception,
      rawCode: "unknown",
    );
  }

  // ---------------------------------------------------------------------------
  // Firestore
  // ---------------------------------------------------------------------------
  static FirestoreFormattedException _fromFirebaseFirestore(
    FirebaseException e,
  ) {
    final normalized = _normalizeFirestoreCode(e.code);

    final map = <String, String>{
      "cancelled": "The operation was cancelled.",
      "unknown": "An unknown Firestore error occurred.",
      "invalid_argument": "An invalid value was provided.",
      "deadline_exceeded": "The request took too long. Try again.",
      "not_found": "The requested document was not found.",
      "already_exists": "This document already exists.",
      "permission_denied": "You don't have permission to perform this action.",
      "unauthenticated": "You must be signed in to perform this action.",
      "resource_exhausted": "Firestore resource limits exceeded.",
      "failed_precondition": "Operation failed due to a precondition.",
      "aborted": "The operation was aborted due to a conflict.",
      "out_of_range": "A value was out of allowed range.",
      "unimplemented": "This operation is not implemented.",
      "internal": "A Firestore internal error occurred.",
      "unavailable": "Firestore is temporarily unavailable.",
      "data_loss": "Data loss occurred. Please try again.",
    };

    return FirestoreFormattedException(
      code: normalized,
      title: _toTitle(normalized),
      message: map[normalized] ?? (e.message ?? "Firestore error occurred."),
      exception: e,
      rawCode: e.code,
    );
  }

  static String _normalizeFirestoreCode(String code) {
    switch (code) {
      case "cancelled":
        return "cancelled";
      case "unknown":
        return "unknown";
      case "invalid-argument":
        return "invalid_argument";
      case "deadline-exceeded":
        return "deadline_exceeded";
      case "not-found":
        return "not_found";
      case "already-exists":
        return "already_exists";
      case "permission-denied":
        return "permission_denied";
      case "unauthenticated":
        return "unauthenticated";
      case "resource-exhausted":
        return "resource_exhausted";
      case "failed-precondition":
        return "failed_precondition";
      case "aborted":
        return "aborted";
      case "out-of-range":
        return "out_of_range";
      case "unimplemented":
        return "unimplemented";
      case "internal":
        return "internal";
      case "unavailable":
        return "unavailable";
      case "data-loss":
        return "data_loss";
      default:
        return "firestore_$code";
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  static String _toTitle(String code) {
    return code
        .replaceAll("_", " ")
        .split(" ")
        .map((w) => "${w[0].toUpperCase()}${w.substring(1)}")
        .join(" ");
  }
}
