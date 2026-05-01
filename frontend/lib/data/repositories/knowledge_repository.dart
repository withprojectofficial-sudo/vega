/// 파일명: knowledge_repository.dart
/// 위치: frontend/lib/data/repositories/knowledge_repository.dart
/// 레이어: Data (지식 리포지토리)
/// 역할: 지식 검색, 상세조회, 인용, 발행 API 호출을 캡슐화한다.
/// 작성일: 2026-05-01

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/knowledge_model.dart';

/// 지식 관련 백엔드 API 호출 리포지토리
final class KnowledgeRepository {
  const KnowledgeRepository();

  /// 시맨틱 검색 (GET /knowledge/search)
  /// [query] 자연어 쿼리
  /// [domain] 도메인 필터 (선택)
  /// [limit] 결과 수 (기본 10)
  /// [threshold] 최소 유사도 (기본 0.5)
  Future<List<KnowledgeItem>> search({
    required String query,
    KnowledgeDomain? domain,
    int limit = 10,
    double threshold = 0.5,
  }) async {
    try {
      final response = await ApiClient.instance.get<Map<String, dynamic>>(
        '/knowledge/search',
        queryParameters: <String, dynamic>{
          'query': query,
          if (domain != null) 'domain': domain.value,
          'limit': limit,
          'threshold': threshold,
        },
      );
      final data = response.data!;
      final items = (data['items'] as List<dynamic>)
          .map((e) => KnowledgeItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return items;
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  /// 지식 상세 조회 (GET /knowledge/{id})
  Future<KnowledgeDetail> getDetail(String knowledgeId) async {
    try {
      final response = await ApiClient.instance.get<Map<String, dynamic>>(
        '/knowledge/$knowledgeId',
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return KnowledgeDetail.fromJson(data);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  /// 지식 인용 — 원자적 트랜잭션 (POST /knowledge/cite, 인증 필요)
  Future<KnowledgeCiteResult> cite({
    required String knowledgeId,
    required String apiKey,
  }) async {
    try {
      final response = await ApiClient.withApiKey(apiKey).post<Map<String, dynamic>>(
        '/knowledge/cite',
        data: <String, String>{'knowledge_id': knowledgeId},
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return KnowledgeCiteResult.fromJson(data);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  /// 지식 발행 (POST /knowledge/publish, 인증 필요)
  Future<KnowledgePublishResult> publish({
    required KnowledgePublishRequest request,
    required String apiKey,
  }) async {
    try {
      final response = await ApiClient.withApiKey(apiKey).post<Map<String, dynamic>>(
        '/knowledge/publish',
        data: request.toJson(),
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return KnowledgePublishResult.fromJson(data);
    } on DioException catch (e) {
      _rethrow(e);
    }
  }

  /// DioException을 VegaApiException 또는 VegaNetworkException으로 재발생
  Never _rethrow(DioException e) {
    final error = e.error;
    if (error is VegaApiException) throw error;
    if (error is VegaNetworkException) throw error;
    throw VegaNetworkException(e.message ?? '네트워크 오류가 발생했습니다.');
  }
}
