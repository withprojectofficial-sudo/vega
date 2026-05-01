/// 파일명: domain_chip.dart
/// 위치: frontend/lib/shared/widgets/domain_chip.dart
/// 레이어: Shared Widget
/// 역할: 지식 도메인을 색상 있는 Chip으로 표시한다.
/// 작성일: 2026-05-01

import 'package:flutter/material.dart';

import '../../data/models/knowledge_model.dart';

/// 도메인별 배경 색상 매핑
const Map<KnowledgeDomain, Color> _domainColors = {
  KnowledgeDomain.medical: Color(0xFFFFE0E0),
  KnowledgeDomain.economics: Color(0xFFE3F2FD),
  KnowledgeDomain.law: Color(0xFFEDE7F6),
  KnowledgeDomain.science: Color(0xFFE0F7FA),
  KnowledgeDomain.aiTrends: Color(0xFFEEF2FF),
  KnowledgeDomain.businessStrategy: Color(0xFFFFF3E0),
  KnowledgeDomain.other: Color(0xFFF5F5F5),
};

/// 도메인별 텍스트/아이콘 색상 매핑
const Map<KnowledgeDomain, Color> _domainForegroundColors = {
  KnowledgeDomain.medical: Color(0xFFD32F2F),
  KnowledgeDomain.economics: Color(0xFF1565C0),
  KnowledgeDomain.law: Color(0xFF6A1B9A),
  KnowledgeDomain.science: Color(0xFF00695C),
  KnowledgeDomain.aiTrends: Color(0xFF3730A3),
  KnowledgeDomain.businessStrategy: Color(0xFFE65100),
  KnowledgeDomain.other: Color(0xFF616161),
};

/// 도메인 아이콘 매핑
const Map<KnowledgeDomain, IconData> _domainIcons = {
  KnowledgeDomain.medical: Icons.local_hospital_rounded,
  KnowledgeDomain.economics: Icons.show_chart_rounded,
  KnowledgeDomain.law: Icons.gavel_rounded,
  KnowledgeDomain.science: Icons.science_rounded,
  KnowledgeDomain.aiTrends: Icons.auto_awesome_rounded,
  KnowledgeDomain.businessStrategy: Icons.business_center_rounded,
  KnowledgeDomain.other: Icons.category_rounded,
};

/// 지식 도메인 표시 칩 위젯
class DomainChip extends StatelessWidget {
  const DomainChip(this.domain, {super.key, this.small = false});

  final KnowledgeDomain domain;

  /// 소형 모드 (카드 내부 등 공간 제한 상황)
  final bool small;

  @override
  Widget build(BuildContext context) {
    final bg = _domainColors[domain] ?? const Color(0xFFF5F5F5);
    final fg = _domainForegroundColors[domain] ?? const Color(0xFF616161);
    final icon = _domainIcons[domain] ?? Icons.category_rounded;

    if (small) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
            Text(
              domain.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            domain.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
