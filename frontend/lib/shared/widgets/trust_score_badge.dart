/// 파일명: trust_score_badge.dart
/// 위치: frontend/lib/shared/widgets/trust_score_badge.dart
/// 레이어: Shared Widget
/// 역할: 신뢰점수(0.0~1.0)를 색상 있는 배지와 바 형태로 시각화한다.
/// 작성일: 2026-05-01

import 'package:flutter/material.dart';

/// 신뢰점수 점수대별 색상 반환
Color _scoreColor(double score) {
  if (score >= 0.8) return const Color(0xFF10B981); // Emerald
  if (score >= 0.6) return const Color(0xFF3B82F6); // Blue
  if (score >= 0.4) return const Color(0xFFF59E0B); // Amber
  return const Color(0xFFEF4444); // Red
}

/// 신뢰점수를 간결한 배지로 표시
class TrustScoreBadge extends StatelessWidget {
  const TrustScoreBadge(this.score, {super.key});

  final double score;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);
    final pct = (score * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(77), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            '$pct',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 신뢰점수를 라벨+진행바 형태로 상세 표시
class TrustScoreBar extends StatelessWidget {
  const TrustScoreBar({
    super.key,
    required this.label,
    required this.score,
  });

  final String label;
  final double score;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);
    final pct = (score * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

/// 유사도 점수 뱃지 (검색 결과용)
class SimilarityBadge extends StatelessWidget {
  const SimilarityBadge(this.score, {super.key});

  final double score;

  @override
  Widget build(BuildContext context) {
    final pct = (score * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '유사도 $pct%',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4F46E5),
        ),
      ),
    );
  }
}
