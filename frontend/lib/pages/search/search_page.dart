/// 파일명: search_page.dart
/// 위치: frontend/lib/pages/search/search_page.dart
/// 레이어: UI (검색 홈 화면)
/// 역할: 시맨틱 검색 UI. 구글 미니멀리즘 + X 타임라인 스타일 카드 피드.
/// 작성일: 2026-05-01

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../providers/knowledge_providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/knowledge_card.dart';

/// 지식 시맨틱 검색 홈 화면
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  bool _hasQuery = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _hasQuery = value.trim().isNotEmpty);
    ref.read(searchNotifierProvider.notifier).search(value);
  }

  void _clearSearch() {
    _controller.clear();
    setState(() => _hasQuery = false);
    ref.read(searchNotifierProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 로고 + 태그라인 (쿼리 없을 때만)
          if (!_hasQuery) ...[
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.hub_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vega',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '인용 기반 지식 신뢰 인프라',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // 검색 바
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF111827),
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: '지식을 검색하세요 (예: 당뇨병과 운동의 관계)',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFADB5BD),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF6B7280),
                  size: 20,
                ),
                suffixIcon: _hasQuery
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF9CA3AF),
                        ),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasQuery) {
      return _buildLandingContent();
    }

    final searchAsync = ref.watch(searchNotifierProvider);

    return searchAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF4F46E5),
          strokeWidth: 2.5,
        ),
      ),
      error: (e, _) {
        final msg = e is VegaApiException
            ? e.userMessage
            : e is VegaNetworkException
                ? e.message
                : '검색 중 오류가 발생했습니다.';
        return ErrorState(
          message: msg,
          onRetry: () => ref
              .read(searchNotifierProvider.notifier)
              .search(_controller.text),
        );
      },
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_rounded,
            title: '검색 결과가 없습니다',
            subtitle: '다른 키워드로 검색하거나\n더 짧은 문장으로 시도해보세요.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                '${items.length}개의 관련 지식',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                padding: const EdgeInsets.only(bottom: 16),
                itemBuilder: (context, index) =>
                    KnowledgeCard(items[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLandingContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            '어떤 지식을 찾고 계신가요?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '자연어로 검색하면 의미 기반으로 관련 지식을 찾아드립니다.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // 추천 검색어
          const Text(
            '추천 검색어',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((s) => _SuggestionChip(
              label: s,
              onTap: () {
                _controller.text = s;
                _onChanged(s);
              },
            )).toList(),
          ),

          const SizedBox(height: 32),

          // 안내 카드들
          _InfoCard(
            icon: Icons.format_quote_rounded,
            color: const Color(0xFF4F46E5),
            title: '인용으로 신뢰가 쌓입니다',
            body: '지식을 인용할 때마다 발행자에게 포인트가 지급되고 신뢰점수가 올라갑니다.',
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.verified_rounded,
            color: const Color(0xFF10B981),
            title: 'LLM이 품질을 평가합니다',
            body: '발행된 지식은 AI 품질 평가를 거쳐 active 상태가 될 때만 인용 가능합니다.',
          ),
        ],
      ),
    );
  }
}

const List<String> _suggestions = [
  '당뇨병 환자의 운동 지침',
  '양자컴퓨팅 최신 동향',
  '스타트업 시리즈A 전략',
  '의료 AI 규제 현황',
  '블록체인 법적 지위',
  '인플레이션 대응 전략',
];

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.north_east_rounded, size: 12, color: Color(0xFF9CA3AF)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
