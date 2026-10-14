import 'dart:developer' as dev;

class AppLogger {
  static final RegExp _apiKeyPattern = RegExp(
    r'(Bearer\s+)([A-Za-z0-9_\-\.]{8,})',
    caseSensitive: false,
  );

  static String sanitize(String message) {
    return message.replaceAllMapped(_apiKeyPattern, (match) {
      final prefix = match.group(1) ?? 'Bearer ';
      final token = match.group(2) ?? '';
      if (token.length <= 6) return '$prefix***';
      return '$prefix${token.substring(0, 3)}...${token.substring(token.length - 3)}';
    });
  }

  static void info(String message, {String? tag, Object? error}) {
    final clean = sanitize(message);
    dev.log(
      clean,
      name: tag ?? 'Foodies',
      error: error != null ? sanitize(error.toString()) : null,
      level: 800,
    );
    print('[${tag ?? "Foodies"}] $clean');
  }

  static void debug(String message, {String? tag}) {
    final clean = sanitize(message);
    dev.log(clean, name: tag ?? 'Foodies:Debug', level: 500);
    print('[${tag ?? "Foodies:Debug"}] $clean');
  }

  static void warn(String message, {String? tag, Object? error}) {
    final clean = sanitize(message);
    dev.log(
      clean,
      name: tag ?? 'Foodies:Warn',
      error: error != null ? sanitize(error.toString()) : null,
      level: 900,
    );
    print('[${tag ?? "Foodies:Warn"}] $clean');
  }

  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final clean = sanitize(message);
    dev.log(
      clean,
      name: tag ?? 'Foodies:Error',
      error: error != null ? sanitize(error.toString()) : null,
      stackTrace: stackTrace,
      level: 1000,
    );
    print('[${tag ?? "Foodies:Error"}] $clean ${error != null ? "($error)" : ""}');
  }

  static void job({
    required String jobId,
    required String stage,
    required String message,
  }) {
    info('[$jobId][$stage] $message', tag: 'ImportJob');
  }
}
