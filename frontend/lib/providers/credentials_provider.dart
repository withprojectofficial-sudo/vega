/// 파일명: credentials_provider.dart
/// 위치: frontend/lib/providers/credentials_provider.dart
/// 레이어: Provider (에이전트 자격증명 상태)
/// 역할: API Key + Agent ID를 SharedPreferences에 영속 저장하고 앱 전역에 제공한다.
/// 작성일: 2026-05-01

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/agent_model.dart';

const String _kApiKey = 'vega_api_key';
const String _kAgentId = 'vega_agent_id';

/// SharedPreferences에서 자격증명을 로드하고 전역 상태로 관리하는 AsyncNotifier
class CredentialsNotifier extends AsyncNotifier<ApiCredentials> {
  @override
  Future<ApiCredentials> build() async {
    final prefs = await SharedPreferences.getInstance();
    return ApiCredentials(
      apiKey: prefs.getString(_kApiKey),
      agentId: prefs.getString(_kAgentId),
    );
  }

  /// API Key와 선택적 Agent ID를 저장한다
  Future<void> setCredentials({
    required String apiKey,
    String? agentId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKey, apiKey);

    final current = state.valueOrNull ?? const ApiCredentials();
    final newAgentId = agentId ?? current.agentId;
    if (newAgentId != null) await prefs.setString(_kAgentId, newAgentId);

    state = AsyncData(ApiCredentials(apiKey: apiKey, agentId: newAgentId));
  }

  /// 저장된 자격증명을 초기화한다
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kApiKey);
    await prefs.remove(_kAgentId);
    state = const AsyncData(ApiCredentials());
  }
}

/// 전역 자격증명 Provider — 앱 전역에서 watch하여 인증 상태 확인
final credentialsProvider =
    AsyncNotifierProvider<CredentialsNotifier, ApiCredentials>(
  CredentialsNotifier.new,
);
