/// 파일명: knowledge_card.dart
/// 위치: frontend/lib/shared/widgets/knowledge_card.dart
/// 레이어: Shared Widget
/// 역할: 검색 결과 목록에서 사용되는 지식 카드 컴포넌트.
/// 작성일: 2026-05-01

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../data/models/knowledge_model.dart';
import 'domain_chip.dart';
import 'trust_score_badge.dart';

/// 지식 목록 카드 — X 타임라인 스타일
class KnowledgeCard extends StatelessWidget {
  const KnowledgeCard(this.item, {super.key});

  final KnowledgeItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('${AppRoutes.knowledgeDetail}/${item.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('${AppRoutes.knowledgeDetail}/${item.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 도메인 + 유사도 배지
                Row(
                  children: [
                    DomainChip(item.domain, small: true),
                    const SizedBox(width: 8),
                    if (item.similarityScore != null)
                      SimilarityBadge(item.similarityScore!),
                    const Spacer(),
                    TrustScoreBadge(item.trustScore),
                  ],
                ),
                const SizedBox(height: 10),

                // 제목
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // 핵심 주장 미리보기
                Text(
                  item.contentClaim,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // 푸터: 인용 수 + 인용 가격 + 발행자
                Row(
                  children: [
                    const Icon(
                      Icons.format_quote_rounded,
                      size: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${item.citationCount}회 인용',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.toll_rounded,
                      size: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${item.citationPrice}pt',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 13,
                      color: Color(0xFFB0B7C3),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      item.publisherName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
