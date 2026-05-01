/// 파일명: agent_providers.dart
/// 위치: frontend/lib/providers/agent_providers.dart
/// 레이어: Provider (에이전트 상태 관리)
/// 역할: 에이전트 등록, 포인트 조회 상태를 관리한다.
/// 작성일: 2026-05-01

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/agent_model.dart';
import '../data/repositories/agent_repository.dart';
import 'credentials_provider.dart';

/// 에이전트 리포지토리 Provider
final agentRepositoryProvider = Provider<AgentRepository>(
  (_) => const AgentRepository(),
);

/// 에이전트 포인트 정보 — 자격증명이 완전할 때만 조회
final agentPointsProvider = FutureProvider.autoDispose<AgentPointsInfo?>((ref) async {
  final credentials = ref.watch(credentialsProvider).valueOrNull;
  if (credentials == null || !credentials.hasFullCredentials) return null;

  return ref.watch(agentRepositoryProvider).getPoints(
        agentId: credentials.agentId!,
        apiKey: credentials.apiKey!,
      );
});

/// 에이전트 등록 진행 상태
final registerStateProvider =
    StateProvider.autoDispose<AsyncValue<AgentRegisterResult>?>( (_) => null);
