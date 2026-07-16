import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String _dotenvValue(String key1, [String? key2]) {
    final value1 = dotenv.env[key1]?.trim() ?? '';
    if (value1.isNotEmpty) return value1;

    if (key2 != null) {
      final value2 = dotenv.env[key2]?.trim() ?? '';
      if (value2.isNotEmpty) return value2;
    }

    return '';
  }

  static String get transactionsEndpoint {
    final v = _dotenvValue('TRANSACTIONS_ENDPOINT', 'TRANSACTIONS_ENDPOINT_2');
    return v.isNotEmpty
        ? v
        : const String.fromEnvironment(
            'TRANSACTIONS_ENDPOINT',
            defaultValue: '',
          );
  }

  static String get listenersEndpoint {
    final v = _dotenvValue('LISTENERS_ENDPOINT', 'LISTENERS_ENDPOINT_2');
    return v.isNotEmpty
        ? v
        : const String.fromEnvironment(
            'LISTENERS_ENDPOINT',
            defaultValue: '',
          );
  }

  static String get tokenEndpoint {
    final v = _dotenvValue('TOKEN_ENDPOINT', 'TOKEN_ENDPOINT_2');
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
