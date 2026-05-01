/// 파일명: agent_page.dart
/// 위치: frontend/lib/pages/agent/agent_page.dart
/// 레이어: UI (에이전트 지갑 + 프로필 화면)
/// 역할: 에이전트 등록, API Key 관리, 실시간 포인트 잔액 표시.
/// 작성일: 2026-05-01

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/agent_model.dart';
import '../../data/repositories/agent_repository.dart';
import '../../providers/agent_providers.dart';
import '../../providers/credentials_provider.dart';
import '../../shared/widgets/empty_state.dart';

/// 에이전트 지갑 화면
class AgentPage extends ConsumerWidget {
  const AgentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credAsync = ref.watch(credentialsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: credAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF4F46E5),
              strokeWidth: 2.5,
            ),
          ),
          error: (e, _) => ErrorState(message: e.toString()),
          data: (creds) => creds.hasKey
              ? _WalletView(credentials: creds)
              : _SetupView(),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// 에이전트 미등록 화면: 등록 또는 API Key 입력
// ──────────────────────────────────────────

class _SetupView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends ConsumerState<_SetupView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 헤더
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '에이전트',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Vega 지식 생태계에 참여하세요',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabCtrl,
                labelColor: const Color(0xFF4F46E5),
                unselectedLabelColor: const Color(0xFF9CA3AF),
                indicatorColor: const Color(0xFF4F46E5),
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: const [
                  Tab(text: '신규 등록'),
                  Tab(text: 'API Key 입력'),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _RegisterTab(),
              _ApiKeyTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 신규 등록 탭 ──

class _RegisterTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends ConsumerState<_RegisterTab> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  AgentType _type = AgentType.human;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().length < 2) {
      setState(() => _error = '이름은 2자 이상 입력해주세요.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final result = await const AgentRepository().register(
        name: _nameCtrl.text.trim(),
        type: _type,
        bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      );

      await ref.read(credentialsProvider.notifier).setCredentials(
        apiKey: result.apiKey,
        agentId: result.agentId,
      );

      if (mounted) {
        _showApiKeyDialog(context, result);
      }
    } on VegaApiException catch (e) {
      if (mounted) setState(() { _error = e.userMessage; _loading = false; });
    } on VegaNetworkException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = '등록 중 오류가 발생했습니다.'; _loading = false; });
    }
  }

  void _showApiKeyDialog(BuildContext context, AgentRegisterResult result) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ApiKeyRevealDialog(result: result),
    ).then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FieldLabel('이름 *'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                maxLength: 50,
                decoration: _inputDec('에이전트 이름 (2~50자)'),
              ),
              const SizedBox(height: 14),
              const _FieldLabel('유형'),
              const SizedBox(height: 8),
              Row(
                children: AgentType.values.map((t) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: Container(
                      margin: EdgeInsets.only(right: t == AgentType.human ? 6 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _type == t
                            ? const Color(0xFFEEF2FF)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _type == t
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFFE5E7EB),
                          width: _type == t ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            t == AgentType.human
                                ? Icons.person_rounded
                                : Icons.smart_toy_rounded,
                            size: 22,
                            color: _type == t
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _type == t
                                  ? const Color(0xFF4F46E5)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 14),
              const _FieldLabel('자기소개 (선택)'),
              const SizedBox(height: 8),
              TextField(
                controller: _bioCtrl,
                maxLength: 300,
                maxLines: 3,
                decoration: _inputDec('나는 누구인가, 무엇을 다루는가 (선택)'),
              ),
            ],
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 8),
          _ErrorBanner(_error!),
        ],

        const SizedBox(height: 16),

        // 초기 포인트 안내
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.toll_rounded, color: Color(0xFF059669), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '등록 시 100 포인트 지급',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    Text(
                      '인용 활동을 통해 포인트를 늘려가세요.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loading ? null : _register,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.how_to_reg_rounded, size: 18),
            label: Text(_loading ? '등록 중...' : '에이전트 등록하기'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── API Key 직접 입력 탭 ──

class _ApiKeyTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ApiKeyTab> createState() => _ApiKeyTabState();
}

class _ApiKeyTabState extends ConsumerState<_ApiKeyTab> {
  final _keyCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _keyCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_keyCtrl.text.trim().isEmpty) {
      setState(() => _error = 'API Key를 입력해주세요.');
      return;
    }
    setState(() => _error = null);

    await ref.read(credentialsProvider.notifier).setCredentials(
      apiKey: _keyCtrl.text.trim(),
      agentId: _idCtrl.text.trim().isEmpty ? null : _idCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FieldLabel('API Key *'),
              const SizedBox(height: 8),
              TextField(
                controller: _keyCtrl,
                obscureText: _obscure,
                decoration: _inputDec('vega_...').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 18,
                      color: const Color(0xFF9CA3AF),
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const _FieldLabel('Agent ID (선택 — 포인트 조회에 필요)'),
              const SizedBox(height: 8),
              TextField(
                controller: _idCtrl,
                decoration: _inputDec('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'),
              ),
            ],
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 8),
          _ErrorBanner(_error!),
        ],

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.key_rounded, size: 18),
            label: const Text('저장하기'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────
// 에이전트 지갑 화면 (등록 완료 후)
// ──────────────────────────────────────────

class _WalletView extends ConsumerWidget {
  const _WalletView({required this.credentials});

  final ApiCredentials credentials;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync = ref.watch(agentPointsProvider);

    return RefreshIndicator(
      color: const Color(0xFF4F46E5),
      onRefresh: () => ref.refresh(agentPointsProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 포인트 카드
          _PointsCard(pointsAsync: pointsAsync),
          const SizedBox(height: 16),

          // API Key 관리
          _ApiKeyCard(credentials: credentials, ref: ref),
          const SizedBox(height: 16),

          // 에이전트 정보
          if (credentials.agentId != null)
            _AgentInfoCard(agentId: credentials.agentId!),
          const SizedBox(height: 16),

          // 인용 히스토리 (추후 API 연동)
          _CitationHistoryCard(),
        ],
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.pointsAsync});

  final AsyncValue<AgentPointsInfo?> pointsAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: pointsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '내 지갑',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '포인트 조회 실패',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Agent ID를 등록하면 포인트를 확인할 수 있습니다.',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ],
        ),
        data: (info) {
          if (info == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '내 지갑',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Agent ID를 등록하세요',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'API Key 탭에서 Agent ID를 입력하면\n포인트를 확인할 수 있습니다.',
                  style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.4),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${info.name} · ${info.type.label}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded,
                            size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          '${(info.trustScore * 100).round()}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${info.points}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -2,
                      height: 1,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8, left: 6),
                    child: Text(
                      'pt',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '현재 포인트 잔액',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ApiKeyCard extends StatefulWidget {
  const _ApiKeyCard({required this.credentials, required this.ref});

  final ApiCredentials credentials;
  final WidgetRef ref;

  @override
  State<_ApiKeyCard> createState() => _ApiKeyCardState();
}

class _ApiKeyCardState extends State<_ApiKeyCard> {
  bool _showKey = false;

  @override
  Widget build(BuildContext context) {
    final apiKey = widget.credentials.apiKey ?? '';
    final displayKey = _showKey
        ? apiKey
        : '${apiKey.substring(0, apiKey.length > 8 ? 8 : apiKey.length)}${'•' * 24}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.key_rounded, size: 16, color: Color(0xFF6B7280)),
              SizedBox(width: 6),
              Text(
                'API Key',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    displayKey,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Color(0xFF374151),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _showKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 18,
                  color: const Color(0xFF6B7280),
                ),
                onPressed: () => setState(() => _showKey = !_showKey),
                tooltip: _showKey ? '숨기기' : '보기',
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF6B7280)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: apiKey));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('API Key가 클립보드에 복사되었습니다.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  );
                },
                tooltip: '복사',
              ),
            ],
          ),
          if (widget.credentials.agentId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Agent ID: ',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
                Expanded(
                  child: Text(
                    widget.credentials.agentId!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => Clipboard.setData(
                    ClipboardData(text: widget.credentials.agentId!),
                  ),
                  child: const Icon(Icons.copy_rounded,
                      size: 13, color: Color(0xFFD1D5DB)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout_rounded, size: 15, color: Color(0xFFEF4444)),
            label: const Text(
              '로그아웃 (자격증명 삭제)',
              style: TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('자격증명 삭제', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          '저장된 API Key와 Agent ID가 삭제됩니다.\nVega에서 로그아웃되며, 다시 등록하거나 API Key를 입력해야 합니다.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          FilledButton(
            onPressed: () async {
              await widget.ref.read(credentialsProvider.notifier).clear();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _AgentInfoCard extends StatelessWidget {
  const _AgentInfoCard({required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF6B7280)),
              SizedBox(width: 6),
              Text(
                '에이전트 정보',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetaRow(
            label: '발행 포인트 수익',
            value: '지식 인용 시 포인트 획득',
            icon: Icons.trending_up_rounded,
          ),
          const SizedBox(height: 8),
          _MetaRow(
            label: '인용 비용',
            value: '지식 인용 시 포인트 차감',
            icon: Icons.toll_rounded,
          ),
          const SizedBox(height: 8),
          _MetaRow(
            label: '신뢰점수',
            value: '발행·인용 활동으로 상승',
            icon: Icons.verified_rounded,
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}

class _CitationHistoryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, size: 16, color: Color(0xFF6B7280)),
              SizedBox(width: 6),
              Text(
                '인용 히스토리',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.format_quote_rounded,
                    size: 24,
                    color: Color(0xFFD1D5DB),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '인용 히스토리 API 연동 예정',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Week 5에서 트랜잭션 목록 API와 연동됩니다.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFD1D5DB),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// API Key 발급 다이얼로그 (등록 직후 1회 표시)
// ──────────────────────────────────────────

class _ApiKeyRevealDialog extends StatefulWidget {
  const _ApiKeyRevealDialog({required this.result});

  final AgentRegisterResult result;

  @override
  State<_ApiKeyRevealDialog> createState() => _ApiKeyRevealDialogState();
}

class _ApiKeyRevealDialogState extends State<_ApiKeyRevealDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFD97706), size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'API Key 저장',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠ API Key는 지금 이 화면에서만 확인할 수 있습니다.\n반드시 안전한 곳에 복사해 보관하세요.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF92400E),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _KeyField('Agent ID', widget.result.agentId),
            const SizedBox(height: 8),
            _KeyField('API Key', widget.result.apiKey, isKey: true),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.toll_rounded,
                      size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 6),
                  Text(
                    '초기 포인트 ${widget.result.initialPoints}pt 지급 완료',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _confirmed,
                  onChanged: (v) => setState(() => _confirmed = v ?? false),
                  activeColor: const Color(0xFF4F46E5),
                ),
                const Expanded(
                  child: Text(
                    'API Key를 안전하게 저장했습니다.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _confirmed ? () => Navigator.of(context).pop() : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('확인 및 시작하기'),
        ),
      ],
    );
  }
}

class _KeyField extends StatelessWidget {
  const _KeyField(this.label, this.value, {this.isKey = false});

  final String label;
  final String value;
  final bool isKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isKey ? const Color(0xFF4F46E5) : const Color(0xFF374151),
                    fontWeight: isKey ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label가 복사되었습니다.'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.copy_rounded,
                    size: 16, color: Color(0xFF4F46E5)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 유틸 위젯 ──

Widget _card({required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: child,
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: Color(0xFFEF4444)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDec(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFADB5BD)),
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}
