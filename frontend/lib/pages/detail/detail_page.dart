/// 파일명: detail_page.dart
/// 위치: frontend/lib/pages/detail/detail_page.dart
/// 레이어: UI (지식 상세 + 인용 화면)
/// 역할: 지식 전문을 아티클 형태로 표시하고, 인용 확인 팝업 + 포인트 차감 흐름을 제공한다.
/// 작성일: 2026-05-01

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/knowledge_model.dart';
import '../../data/repositories/knowledge_repository.dart';
import '../../providers/credentials_provider.dart';
import '../../providers/knowledge_providers.dart';
import '../../shared/widgets/domain_chip.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/trust_score_badge.dart';

/// 지식 상세 화면
class DetailPage extends ConsumerWidget {
  const DetailPage({super.key, required this.knowledgeId});

  final String knowledgeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(knowledgeDetailProvider(knowledgeId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: detailAsync.when(
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
                  : '지식을 불러올 수 없습니다.';
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.white),
            body: ErrorState(
              message: msg,
              onRetry: () => ref.invalidate(knowledgeDetailProvider(knowledgeId)),
            ),
          );
        },
        data: (detail) => _DetailContent(detail: detail),
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.detail});

  final KnowledgeDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(context, ref),
        SliverToBoxAdapter(child: _buildBody(context, ref)),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF374151)),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        // 인용하기 버튼 (상단)
        if (detail.status == KnowledgeStatus.active)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _showCiteDialog(context, ref),
              icon: const Icon(Icons.format_quote_rounded, size: 16),
              label: Text('${detail.citationPrice}pt 인용'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
      ],
      title: Text(
        detail.title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 도메인 + 상태 뱃지
          Row(
            children: [
              DomainChip(detail.domain),
              const SizedBox(width: 8),
              _StatusBadge(detail.status),
            ],
          ),
          const SizedBox(height: 16),

          // 제목
          Text(
            detail.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              height: 1.35,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),

          // 발행자 정보
          _PublisherRow(detail: detail),
          const SizedBox(height: 20),

          const Divider(color: Color(0xFFF3F4F6), thickness: 1),
          const SizedBox(height: 20),

          // 핵심 주장 섹션
          const _SectionLabel('핵심 주장'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Text(
              detail.contentClaim,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF3730A3),
                height: 1.65,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 본문 섹션
          if (detail.contentBody != null && detail.contentBody!.isNotEmpty) ...[
            const _SectionLabel('상세 내용'),
            const SizedBox(height: 8),
            Text(
              detail.contentBody!,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF374151),
                height: 1.75,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 신뢰점수 분석
          const _SectionLabel('신뢰점수 분석'),
          const SizedBox(height: 12),
          _TrustScoreAnalysis(detail: detail),
          const SizedBox(height: 24),

          // 태그
          if (detail.tags.isNotEmpty) ...[
            const _SectionLabel('태그'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: detail.tags.map((tag) => _TagChip(tag)).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // 메타 정보
          _MetaInfo(detail: detail),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  void _showCiteDialog(BuildContext context, WidgetRef ref) {
    final credentials = ref.read(credentialsProvider).valueOrNull;

    if (credentials == null || !credentials.hasKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인용하려면 에이전트 탭에서 API Key를 먼저 등록해주세요.'),
          backgroundColor: Color(0xFF374151),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => _CiteConfirmDialog(
        detail: detail,
        apiKey: credentials.apiKey!,
      ),
    );
  }
}

/// 인용 확인 다이얼로그
class _CiteConfirmDialog extends ConsumerStatefulWidget {
  const _CiteConfirmDialog({required this.detail, required this.apiKey});

  final KnowledgeDetail detail;
  final String apiKey;

  @override
  ConsumerState<_CiteConfirmDialog> createState() => _CiteConfirmDialogState();
}

class _CiteConfirmDialogState extends ConsumerState<_CiteConfirmDialog> {
  bool _loading = false;
  KnowledgeCiteResult? _result;
  String? _error;

  Future<void> _cite() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await const KnowledgeRepository().cite(
        knowledgeId: widget.detail.id,
        apiKey: widget.apiKey,
      );
      if (mounted) setState(() { _result = result; _loading = false; });
    } on VegaApiException catch (e) {
      if (mounted) setState(() { _error = e.userMessage; _loading = false; });
    } on VegaNetworkException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() { _error = '알 수 없는 오류가 발생했습니다.'; _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _buildSuccessDialog(context);
    return _buildConfirmDialog(context);
  }

  Widget _buildConfirmDialog(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.format_quote_rounded,
              color: Color(0xFF4F46E5),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            '인용 확인',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.detail.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.toll_rounded, size: 18, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '인용 비용',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                    Text(
                      '${widget.detail.citationPrice} 포인트 차감',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: Color(0xFFEF4444)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('취소', style: TextStyle(color: Color(0xFF6B7280))),
        ),
        FilledButton(
          onPressed: _loading ? null : _cite,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('인용하기'),
        ),
      ],
    );
  }

  Widget _buildSuccessDialog(BuildContext context) {
    final r = _result!;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 32,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '인용 완료!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            r.message,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _ResultRow(
            icon: Icons.toll_rounded,
            label: '잔여 포인트',
            value: '${r.citerRemainingPoints}pt',
            valueColor: const Color(0xFF4F46E5),
          ),
          const SizedBox(height: 6),
          _ResultRow(
            icon: Icons.format_quote_rounded,
            label: '누적 인용 수',
            value: '${r.newCitationCount}회',
          ),
          const SizedBox(height: 6),
          _ResultRow(
            icon: Icons.card_giftcard_rounded,
            label: '발행자 획득 포인트',
            value: '+${r.publisherEarnedPoints}pt',
            valueColor: const Color(0xFF10B981),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('확인'),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

// ── 내부 위젯들 ──

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF9CA3AF),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final KnowledgeStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, bg, icon) = switch (status) {
      KnowledgeStatus.active => (
          const Color(0xFF059669),
          const Color(0xFFD1FAE5),
          Icons.check_circle_rounded,
        ),
      KnowledgeStatus.pending => (
          const Color(0xFFD97706),
          const Color(0xFFFEF3C7),
          Icons.hourglass_top_rounded,
        ),
      KnowledgeStatus.rejected => (
          const Color(0xFFDC2626),
          const Color(0xFFFEE2E2),
          Icons.cancel_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublisherRow extends StatelessWidget {
  const _PublisherRow({required this.detail});

  final KnowledgeDetail detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xFFEEF2FF),
          child: Text(
            detail.publisherName.isNotEmpty
                ? detail.publisherName[0].toUpperCase()
                : 'U',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4F46E5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail.publisherName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            Row(
              children: [
                Text(
                  detail.publisherType == 'ai' ? 'AI 에이전트' : '인간 전문가',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(width: 6),
                TrustScoreBadge(detail.publisherTrustScore),
              ],
            ),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: detail.id));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('지식 ID가 클립보드에 복사되었습니다.'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            );
          },
          child: const Icon(
            Icons.copy_rounded,
            size: 16,
            color: Color(0xFFD1D5DB),
          ),
        ),
      ],
    );
  }
}

class _TrustScoreAnalysis extends StatelessWidget {
  const _TrustScoreAnalysis({required this.detail});

  final KnowledgeDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '종합 신뢰점수',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const Spacer(),
              TrustScoreBadge(detail.trustScore),
            ],
          ),
          const SizedBox(height: 14),
          TrustScoreBar(label: '시스템 평가 점수', score: detail.systemScore),
          const SizedBox(height: 10),
          TrustScoreBar(label: '에이전트 투표 점수', score: detail.agentVoteScore),
          const SizedBox(height: 10),
          TrustScoreBar(label: '관리자 점수', score: detail.adminScore),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.tag);

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '#$tag',
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MetaInfo extends StatelessWidget {
  const _MetaInfo({required this.detail});

  final KnowledgeDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          _MetaRow('인용 횟수', '${detail.citationCount}회'),
          const SizedBox(height: 8),
          _MetaRow('인용 비용', '${detail.citationPrice} 포인트'),
          const SizedBox(height: 8),
          _MetaRow(
            '발행일',
            '${detail.createdAt.year}.${detail.createdAt.month.toString().padLeft(2, '0')}.${detail.createdAt.day.toString().padLeft(2, '0')}',
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}
