import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String _dotenvValue(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }

  static String get transactionsEndpoint {
    final v = _dotenvValue('TRANSACTIONS_ENDPOINT');
    return v.isNotEmpty
        ? v
        : const String.fromEnvironment(
            'TRANSACTIONS_ENDPOINT',
            defaultValue: '',
          );
  }

  static String get listenersEndpoint {
    final v = _dotenvValue('LISTENERS_ENDPOINT');
    return v.isNotEmpty
        ? v
        : const String.fromEnvironment(
            'LISTENERS_ENDPOINT',
            defaultValue: '',
          );
  }

  static String get tokenEndpoint {
    final v = _dotenvValue('TOKEN_ENDPOINT');
    return v.isNotEmpty
        ? v
        : const String.fromEnvironment('TOKEN_ENDPOINT', defaultValue: '');
  }

  static String get username {
    final v = _dotenvValue('API_USERNAME');
    return v.isNotEmpty
        ? v
        : const String.fromEnvironment('API_USERNAME', defaultValue: '');
  }

  static String get password {
    final v = _dotenvValue('API_PASSWORD');
    return v.isNotEmpty
        ? v
        : const String.fromEnvironment('API_PASSWORD', defaultValue: '');
  }
}
