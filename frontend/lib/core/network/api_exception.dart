/// 파일명: api_exception.dart
/// 위치: frontend/lib/core/network/api_exception.dart
/// 레이어: Network (예외 모델)
/// 역할: Vega 백엔드 VEGA_XXX 에러 응답을 Dart Exception으로 변환한다.
/// 작성일: 2026-05-01

/// Vega 백엔드 에러 코드 상수
abstract final class VegaErrorCode {
  static const String agentAuthFailed = 'VEGA_001';
  static const String insufficientPoints = 'VEGA_002';
  static const String knowledgeStatusError = 'VEGA_003';
  static const String knowledgeNotFound = 'VEGA_004';
  static const String transactionFailed = 'VEGA_005';
  static const String embeddingFailed = 'VEGA_006';
  static const String adminAuthFailed = 'VEGA_007';
  static const String duplicateAgent = 'VEGA_008';
  static const String selfCitation = 'VEGA_009';
  static const String duplicateCitation = 'VEGA_010';
  static const String llmCallFailed = 'VEGA_011';
}

/// Vega 백엔드가 반환하는 구조화된 예외
final class VegaApiException implements Exception {
  const VegaApiException({
    required this.errorCode,
    required this.message,
    this.statusCode = 0,
  });

  final String errorCode;
  final String message;
  final int statusCode;

  /// VEGA 에러 코드에 맞는 사용자 친화적 메시지 반환
  String get userMessage {
    switch (errorCode) {
      case VegaErrorCode.agentAuthFailed:
        return 'API Key 인증에 실패했습니다. Key를 확인해주세요.';
      case VegaErrorCode.insufficientPoints:
        return '포인트가 부족합니다. 지식을 발행하여 포인트를 획득하세요.';
      case VegaErrorCode.knowledgeStatusError:
        return '인용할 수 없는 상태의 지식입니다 (pending/rejected).';
      case VegaErrorCode.knowledgeNotFound:
        return '지식을 찾을 수 없습니다.';
      case VegaErrorCode.transactionFailed:
        return '트랜잭션에 실패했습니다. 잠시 후 다시 시도해주세요.';
      case VegaErrorCode.selfCitation:
        return '자신이 발행한 지식은 인용할 수 없습니다.';
      case VegaErrorCode.duplicateCitation:
        return '이미 인용한 지식입니다.';
      case VegaErrorCode.duplicateAgent:
        return '이미 등록된 에이전트입니다.';
      case VegaErrorCode.llmCallFailed:
        return 'AI 서비스 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      default:
        return message.isNotEmpty ? message : '알 수 없는 오류가 발생했습니다.';
    }
  }

  @override
  String toString() => 'VegaApiException($errorCode): $message';
}

/// 네트워크 연결 실패 등 일반 예외
final class VegaNetworkException implements Exception {
  const VegaNetworkException(this.message);
  final String message;

  @override
  String toString() => 'VegaNetworkException: $message';
}
