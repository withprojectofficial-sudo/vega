/// API 베이스 URL (--dart-define=API_BASE_URL=... 로 주입)
abstract final class ApiConfig {
  /// FastAPI 기본 URL (프로토콜+호스트+포트, 경로 제외)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// `/api/v1` 까지 포함한 prefix (dio BaseOptions용)
  static String get v1Prefix => '$baseUrl/api/v1';
}
