/// 파일명: knowledge_providers.dart
/// 위치: frontend/lib/providers/knowledge_providers.dart
/// 레이어: Provider (지식 상태 관리)
/// 역할: 검색 StateNotifier, 상세조회 FutureProvider, 인용 상태를 관리한다.
/// 작성일: 2026-05-01

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/knowledge_model.dart';
import '../data/repositories/knowledge_repository.dart';

/// 리포지토리 싱글톤 Provider
final knowledgeRepositoryProvider = Provider<KnowledgeRepository>(
  (_) => const KnowledgeRepository(),
);

// ──────────────────────────────────────────
// 검색
// ──────────────────────────────────────────

/// 검색 결과 상태 (AsyncValue<List<KnowledgeItem>>)
class SearchNotifier extends StateNotifier<AsyncValue<List<KnowledgeItem>>> {
  SearchNotifier(this._repository) : super(const AsyncValue.data([]));

  final KnowledgeRepository _repository;
  Timer? _debounce;
  String _lastQuery = '';

  /// 검색어를 업데이트하고 500ms 디바운스 후 API 호출
  void search(String query) {
    _debounce?.cancel();

    if (query.trim().length < 2) {
      _lastQuery = '';
      state = const AsyncValue.data([]);
      return;
    }

    if (query == _lastQuery) return;

    state = const AsyncValue.loading();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      _lastQuery = query;
      state = await AsyncValue.guard(
        () => _repository.search(query: query, threshold: 0.4),
      );
    });
  }

  void clear() {
    _debounce?.cancel();
    _lastQuery = '';
    state = const AsyncValue.data([]);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/// 검색 StateNotifier Provider
final searchNotifierProvider = StateNotifierProvider.autoDispose<
    SearchNotifier, AsyncValue<List<KnowledgeItem>>>(
  (ref) => SearchNotifier(ref.watch(knowledgeRepositoryProvider)),
);

// ──────────────────────────────────────────
// 지식 상세
// ──────────────────────────────────────────

/// 지식 상세 정보 FutureProvider (id별로 캐시됨)
final knowledgeDetailProvider =
    FutureProvider.autoDispose.family<KnowledgeDetail, String>((ref, id) {
  return ref.watch(knowledgeRepositoryProvider).getDetail(id);
});

// ──────────────────────────────────────────
// 인용 상태
// ──────────────────────────────────────────

/// 인용 진행 상태 (null = 미시작, loading = 진행중, data = 성공, error = 실패)
final citeStateProvider = StateProvider.autoDispose<AsyncValue<KnowledgeCiteResult>?>(
  (_) => null,
);

// ──────────────────────────────────────────
// 발행 상태
// ──────────────────────────────────────────

/// 발행 진행 상태
final publishStateProvider = StateProvider.autoDispose<AsyncValue<KnowledgePublishResult>?>(
  (_) => null,
);
