/// 파일명: api_client.dart
/// 위치: frontend/lib/core/network/api_client.dart
/// 레이어: Network (HTTP 클라이언트)
/// 역할: Dio 싱글톤 + 에러 인터셉터. 인증 헤더 주입 헬퍼 제공.
/// 작성일: 2026-05-01

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'api_exception.dart';

/// Vega HTTP 클라이언트 (Dio 기반)
final class ApiClient {
  ApiClient._();

  static final Dio _base = Dio(
    BaseOptions(
      baseUrl: ApiConfig.v1Prefix,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: <String, Object?>{
        Headers.acceptHeader: Headers.jsonContentType,
        Headers.contentTypeHeader: Headers.jsonContentType,
      },
    ),
  )..interceptors.add(_VegaErrorInterceptor());

  /// 인증 없는 공개 요청용 클라이언트
  static Dio get instance => _base;

  /// API Key를 X-API-Key 헤더에 주입한 인증 클라이언트 반환
  static Dio withApiKey(String apiKey) {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.v1Prefix,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: <String, Object?>{
          Headers.acceptHeader: Headers.jsonContentType,
          Headers.contentTypeHeader: Headers.jsonContentType,
          'X-API-Key': apiKey,
        },
      ),
    )..interceptors.add(_VegaErrorInterceptor());
    return dio;
  }
}

/// Vega 백엔드의 { success: false, error_code, message } 구조를 VegaApiException으로 변환
final class _VegaErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response != null) {
      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == false) {
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: VegaApiException(
              errorCode: (data['error_code'] as String?) ?? 'UNKNOWN',
              message: (data['message'] as String?) ?? '알 수 없는 오류가 발생했습니다.',
              statusCode: response.statusCode ?? 0,
            ),
          ),
        );
        return;
      }
    }

    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          type: err.type,
          error: const VegaNetworkException('서버에 연결할 수 없습니다. 네트워크를 확인해주세요.'),
        ),
      );
      return;
    }

    handler.next(err);
  }
}
