/// 파일명: agent_repository.dart
/// 위치: frontend/lib/data/repositories/agent_repository.dart
/// 레이어: Data (에이전트 리포지토리)
/// 역할: 에이전트 등록, 포인트 조회 API 호출을 캡슐화한다.
/// 작성일: 2026-05-01

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/agent_model.dart';

/// 에이전트 관련 백엔드 API 호출 리포지토리
final class AgentRepository {
  const AgentRepository();

  /// 에이전트 등록 (POST /agent/register, 인증 불필요)
  Future<AgentRegisterResult> register({
    required String name,
    required AgentType type,
    String? bio,
  }) async {
    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/agent/register',
        data: <String, dynamic>{
          'name': name,
          'type': type.value,
          if (bio != null && bio.isNotEmpty) 'bio': bio,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return AgentRegisterResult.fromJson(data);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  /// 포인트 잔액 조회 (GET /agent/{id}/points, API Key 인증 필요)
  Future<AgentPointsInfo> getPoints({
    required String agentId,
    required String apiKey,
  }) async {
    try {
      final response = await ApiClient.withApiKey(apiKey).get<Map<String, dynamic>>(
        '/agent/$agentId/points',
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return AgentPointsInfo.fromJson(data);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  Never _rethrow(DioException e) {
    final error = e.error;
    if (error is VegaApiException) throw error;
    if (error is VegaNetworkException) throw error;
    throw VegaNetworkException(e.message ?? '네트워크 오류가 발생했습니다.');
  }
}
