/// 파일명: agent_model.dart
/// 위치: frontend/lib/data/models/agent_model.dart
/// 레이어: Data (에이전트 도메인 모델)
/// 역할: 백엔드 AgentRegisterResponse, AgentPointsResponse를 Dart 불변 모델로 정의.
/// 작성일: 2026-05-01

/// 에이전트 유형 열거형 (백엔드 AgentType과 동기화)
enum AgentType {
  human('human', '인간 전문가'),
  ai('ai', 'AI 에이전트');

  const AgentType(this.value, this.label);

  final String value;
  final String label;

  static AgentType fromValue(String value) {
    return AgentType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => AgentType.human,
    );
  }
}

/// 앱 내 저장 자격증명 상태
final class ApiCredentials {
  const ApiCredentials({this.apiKey, this.agentId});

  final String? apiKey;
  final String? agentId;

  bool get hasKey => apiKey != null && apiKey!.isNotEmpty;
  bool get hasFullCredentials => hasKey && agentId != null && agentId!.isNotEmpty;

  ApiCredentials copyWith({String? apiKey, String? agentId}) {
    return ApiCredentials(
      apiKey: apiKey ?? this.apiKey,
      agentId: agentId ?? this.agentId,
    );
  }
}

/// 에이전트 등록 응답 (POST /agent/register)
final class AgentRegisterResult {
  const AgentRegisterResult({
    required this.agentId,
    required this.apiKey,
    required this.initialPoints,
    required this.message,
  });

  final String agentId;
  final String apiKey;
  final int initialPoints;
  final String message;

  factory AgentRegisterResult.fromJson(Map<String, dynamic> json) {
    return AgentRegisterResult(
      agentId: json['agent_id'] as String,
      apiKey: json['api_key'] as String,
      initialPoints: json['initial_points'] as int,
      message: (json['message'] as String?) ?? '에이전트 등록이 완료되었습니다.',
    );
  }
}

/// 에이전트 포인트 조회 응답 (GET /agent/{id}/points)
final class AgentPointsInfo {
  const AgentPointsInfo({
    required this.agentId,
    required this.name,
    required this.type,
    required this.points,
    required this.trustScore,
  });

  final String agentId;
  final String name;
  final AgentType type;
  final int points;
  final double trustScore;

  factory AgentPointsInfo.fromJson(Map<String, dynamic> json) {
    return AgentPointsInfo(
      agentId: json['agent_id'] as String,
      name: json['name'] as String,
      type: AgentType.fromValue(json['type'] as String),
      points: json['points'] as int,
      trustScore: (json['trust_score'] as num).toDouble(),
    );
  }
}
