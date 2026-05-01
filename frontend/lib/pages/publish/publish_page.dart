/// 파일명: publish_page.dart
/// 위치: frontend/lib/pages/publish/publish_page.dart
/// 레이어: UI (지식 발행 폼)
/// 역할: 제목·핵심주장·본문·도메인·태그·인용가격 입력 폼 + 발행 완료 피드백.
/// 작성일: 2026-05-01

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/knowledge_model.dart';
import '../../data/repositories/knowledge_repository.dart';
import '../../providers/credentials_provider.dart';

/// 지식 발행 화면
class PublishPage extends ConsumerStatefulWidget {
  const PublishPage({super.key});

  @override
  ConsumerState<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends ConsumerState<PublishPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _claimCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  KnowledgeDomain _domain = KnowledgeDomain.other;
  final List<String> _tags = [];
  int _citationPrice = 10;
  bool _submitting = false;
  KnowledgePublishResult? _result;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _claimCtrl.dispose();
    _bodyCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim();
    if (tag.isEmpty || _tags.contains(tag) || _tags.length >= 10) return;
    setState(() { _tags.add(tag); _tagCtrl.clear(); });
  }

  void _removeTag(String tag) => setState(() => _tags.remove(tag));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final credentials = ref.read(credentialsProvider).valueOrNull;
    if (credentials == null || !credentials.hasKey) {
      setState(() => _error = '에이전트 탭에서 API Key를 먼저 등록해주세요.');
      return;
    }

    setState(() { _submitting = true; _error = null; });

    try {
      final result = await const KnowledgeRepository().publish(
        request: KnowledgePublishRequest(
          title: _titleCtrl.text.trim(),
          contentClaim: _claimCtrl.text.trim(),
          contentBody: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
          domain: _domain,
          tags: List.from(_tags),
          citationPrice: _citationPrice,
        ),
        apiKey: credentials.apiKey!,
      );
      if (mounted) setState(() { _result = result; _submitting = false; });
    } on VegaApiException catch (e) {
      if (mounted) setState(() { _error = e.userMessage; _submitting = false; });
    } on VegaNetworkException catch (e) {
      if (mounted) setState(() { _error = e.message; _submitting = false; });
    } catch (_) {
      if (mounted) setState(() { _error = '알 수 없는 오류가 발생했습니다.'; _submitting = false; });
    }
  }

  void _reset() {
    setState(() {
      _result = null;
      _error = null;
      _titleCtrl.clear();
      _claimCtrl.clear();
      _bodyCtrl.clear();
      _tags.clear();
      _domain = KnowledgeDomain.other;
      _citationPrice = 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _buildSuccessView();
    return _buildFormView();
  }

  Widget _buildSuccessView() {
    final r = _result!;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 40,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '발행 완료!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '지식이 성공적으로 발행되었습니다.\nLLM 품질 평가 후 active 상태로 전환됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      _InfoRow('지식 ID', r.knowledgeId, copyable: true),
                      const SizedBox(height: 8),
                      _InfoRow('현재 상태', r.status.label),
                      const SizedBox(height: 8),
                      _InfoRow('메시지', r.message),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI 검토는 보통 수분 내 완료됩니다. 검색에서 지식 ID로 확인하세요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('새 지식 발행하기'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    final credentials = ref.watch(credentialsProvider).valueOrNull;
    final hasKey = credentials?.hasKey ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          '지식 발행',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: const Color(0xFFE5E7EB),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // API Key 미등록 경고
            if (!hasKey) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: Color(0xFFDC2626)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '발행하려면 에이전트 탭에서 API Key를 먼저 등록하세요.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            _FormSection(
              label: '제목',
              child: TextFormField(
                controller: _titleCtrl,
                maxLength: 200,
                decoration: _inputDecoration('지식의 제목을 입력하세요 (5~200자)'),
                validator: (v) {
                  if (v == null || v.trim().length < 5) return '제목은 5자 이상 입력해주세요.';
                  return null;
                },
              ),
            ),

            _FormSection(
              label: '핵심 주장',
              hint: '임베딩 대상입니다. 간결하고 명확하게 핵심을 서술하세요.',
              child: TextFormField(
                controller: _claimCtrl,
                maxLength: 1000,
                maxLines: 4,
                decoration: _inputDecoration('이 지식의 핵심 주장을 입력하세요 (10~1000자)'),
                validator: (v) {
                  if (v == null || v.trim().length < 10) return '핵심 주장은 10자 이상 입력해주세요.';
                  return null;
                },
              ),
            ),

            _FormSection(
              label: '상세 내용 (선택)',
              hint: '핵심 주장을 보충하는 상세 내용입니다.',
              child: TextFormField(
                controller: _bodyCtrl,
                maxLength: 10000,
                maxLines: 8,
                decoration: _inputDecoration('부연 설명, 근거, 참고자료 등을 입력하세요'),
              ),
            ),

            _FormSection(
              label: '도메인',
              child: DropdownButton<KnowledgeDomain>(
                value: _domain,
                isExpanded: true,
                onChanged: (v) { if (v != null) setState(() => _domain = v); },
                items: KnowledgeDomain.values.map((d) {
                  return DropdownMenuItem(
                    value: d,
                    child: Text(d.label),
                  );
                }).toList(),
                underline: const SizedBox.shrink(),
              ),
            ),

            _FormSection(
              label: '태그 (최대 10개)',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagCtrl,
                          decoration: _inputDecoration('#태그 입력 후 추가').copyWith(
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add_circle_rounded,
                                  color: Color(0xFF4F46E5)),
                              onPressed: _addTag,
                            ),
                          ),
                          onSubmitted: (_) => _addTag(),
                        ),
                      ),
                    ],
                  ),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _tags.map((tag) => Chip(
                        label: Text(
                          '#$tag',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onDeleted: () => _removeTag(tag),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        backgroundColor: const Color(0xFFEEF2FF),
                        labelStyle: const TextStyle(color: Color(0xFF4F46E5)),
                        deleteIconColor: const Color(0xFF6B7280),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),

            _FormSection(
              label: '인용 가격 (포인트)',
              hint: '다른 에이전트가 이 지식을 인용할 때 지불할 포인트 (1~1000)',
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '$_citationPrice pt',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _citationPrice.toDouble(),
                    min: 1,
                    max: 100,
                    divisions: 99,
                    activeColor: const Color(0xFF4F46E5),
                    inactiveColor: const Color(0xFFE5E7EB),
                    onChanged: (v) => setState(() => _citationPrice = v.round()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('1pt', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                      Text('100pt', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_submitting || !hasKey) ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.publish_rounded, size: 18),
                label: Text(_submitting ? '발행 중...' : '지식 발행하기'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 13,
        color: Color(0xFFADB5BD),
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.label, required this.child, this.hint});

  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 3),
            Text(
              hint!,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.copyable = false});

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
            textAlign: TextAlign.end,
          ),
        ),
        if (copyable)
          GestureDetector(
            onTap: () => Clipboard.setData(ClipboardData(text: value)),
            child: const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFFADB5BD)),
            ),
          ),
      ],
    );
  }
}
