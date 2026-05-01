/// 파일명: knowledge_model.dart
/// 위치: frontend/lib/data/models/knowledge_model.dart
/// 레이어: Data (지식 도메인 모델)
/// 역할: 백엔드 KnowledgeItem, KnowledgeDetailResponse, Cite/Publish 응답을 Dart 불변 모델로 정의.
/// 작성일: 2026-05-01

/// 지식 도메인 열거형 (백엔드 KnowledgeDomain과 동기화)
enum KnowledgeDomain {
  medical('medical', '의료'),
  economics('economics', '경제'),
  law('law', '법률'),
  science('science', '과학'),
  aiTrends('ai_trends', 'AI 트렌드'),
  businessStrategy('business_strategy', '비즈니스'),
  other('other', '기타');

  const KnowledgeDomain(this.value, this.label);

  final String value;
  final String label;

  static KnowledgeDomain fromValue(String value) {
    return KnowledgeDomain.values.firstWhere(
      (d) => d.value == value,
      orElse: () => KnowledgeDomain.other,
    );
  }
}

/// 지식 상태 열거형
enum KnowledgeStatus {
  pending('pending', '검토 중'),
  active('active', '인용 가능'),
  rejected('rejected', '기각됨');

  const KnowledgeStatus(this.value, this.label);

  final String value;
  final String label;

  static KnowledgeStatus fromValue(String value) {
    return KnowledgeStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => KnowledgeStatus.pending,
    );
  }
}

/// 검색 결과 단일 지식 아이템 (PaginatedResponse<KnowledgeItem>의 items 요소)
final class KnowledgeItem {
  const KnowledgeItem({
    required this.id,
    required this.title,
    required this.contentClaim,
    required this.domain,
    required this.tags,
    required this.trustScore,
    required this.citationPrice,
    required this.citationCount,
    required this.status,
    required this.publisherId,
    required this.publisherName,
    required this.publisherTrustScore,
    required this.createdAt,
    this.similarityScore,
  });

  final String id;
  final String title;
  final String contentClaim;
  final KnowledgeDomain domain;
  final List<String> tags;
  final double trustScore;
  final int citationPrice;
  final int citationCount;
  final KnowledgeStatus status;
  final String publisherId;
  final String publisherName;
  final double publisherTrustScore;
  final DateTime createdAt;
  final double? similarityScore;

  factory KnowledgeItem.fromJson(Map<String, dynamic> json) {
    return KnowledgeItem(
      id: json['id'] as String,
      title: json['title'] as String,
      contentClaim: json['content_claim'] as String,
      domain: KnowledgeDomain.fromValue(json['domain'] as String),
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      trustScore: (json['trust_score'] as num).toDouble(),
      citationPrice: json['citation_price'] as int,
      citationCount: json['citation_count'] as int,
      status: KnowledgeStatus.fromValue(json['status'] as String),
      publisherId: json['publisher_id'] as String,
      publisherName: json['publisher_name'] as String,
      publisherTrustScore: (json['publisher_trust_score'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      similarityScore: json['similarity_score'] != null
          ? (json['similarity_score'] as num).toDouble()
          : null,
    );
  }
}

/// 지식 상세 응답 (GET /knowledge/{id})
final class KnowledgeDetail {
  const KnowledgeDetail({
    required this.id,
    required this.title,
    required this.contentClaim,
    this.contentBody,
    required this.domain,
    required this.tags,
    required this.trustScore,
    required this.systemScore,
    required this.agentVoteScore,
    required this.adminScore,
    required this.status,
    required this.citationPrice,
    required this.citationCount,
    required this.publisherId,
    required this.publisherName,
    required this.publisherType,
    required this.publisherTrustScore,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? contentBody;
  final String contentClaim;
  final KnowledgeDomain domain;
  final List<String> tags;
  final double trustScore;
  final double systemScore;
  final double agentVoteScore;
  final double adminScore;
  final KnowledgeStatus status;
  final int citationPrice;
  final int citationCount;
  final String publisherId;
  final String publisherName;
  final String publisherType;
  final double publisherTrustScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory KnowledgeDetail.fromJson(Map<String, dynamic> json) {
    return KnowledgeDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      contentClaim: json['content_claim'] as String,
      contentBody: json['content_body'] as String?,
      domain: KnowledgeDomain.fromValue(json['domain'] as String),
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      trustScore: (json['trust_score'] as num).toDouble(),
      systemScore: (json['system_score'] as num).toDouble(),
      agentVoteScore: (json['agent_vote_score'] as num).toDouble(),
      adminScore: (json['admin_score'] as num).toDouble(),
      status: KnowledgeStatus.fromValue(json['status'] as String),
      citationPrice: json['citation_price'] as int,
      citationCount: json['citation_count'] as int,
      publisherId: json['publisher_id'] as String,
      publisherName: json['publisher_name'] as String,
      publisherType: json['publisher_type'] as String,
      publisherTrustScore: (json['publisher_trust_score'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// 인용 트랜잭션 결과 (POST /knowledge/cite)
final class KnowledgeCiteResult {
  const KnowledgeCiteResult({
    required this.transactionId,
    required this.newCitationCount,
    required this.newTrustScore,
    required this.citerRemainingPoints,
    required this.publisherEarnedPoints,
    required this.message,
  });

  final String transactionId;
  final int newCitationCount;
  final double newTrustScore;
  final int citerRemainingPoints;
  final int publisherEarnedPoints;
  final String message;

  factory KnowledgeCiteResult.fromJson(Map<String, dynamic> json) {
    return KnowledgeCiteResult(
      transactionId: json['transaction_id'] as String,
      newCitationCount: json['new_citation_count'] as int,
      newTrustScore: (json['new_trust_score'] as num).toDouble(),
      citerRemainingPoints: json['citer_remaining_points'] as int,
      publisherEarnedPoints: json['publisher_earned_points'] as int,
      message: (json['message'] as String?) ?? '인용이 완료되었습니다.',
    );
  }
}

/// 지식 발행 요청 데이터 (POST /knowledge/publish body)
final class KnowledgePublishRequest {
  const KnowledgePublishRequest({
    required this.title,
    required this.contentClaim,
    this.contentBody,
    required this.domain,
    this.tags = const <String>[],
    this.citationPrice = 10,
  });

  final String title;
  final String contentClaim;
  final String? contentBody;
  final KnowledgeDomain domain;
  final List<String> tags;
  final int citationPrice;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'content_claim': contentClaim,
        if (contentBody != null) 'content_body': contentBody,
        'domain': domain.value,
        'tags': tags,
        'citation_price': citationPrice,
      };
}

/// 지식 발행 결과
final class KnowledgePublishResult {
  const KnowledgePublishResult({
    required this.knowledgeId,
    required this.status,
    required this.message,
  });

  final String knowledgeId;
  final KnowledgeStatus status;
  final String message;

  factory KnowledgePublishResult.fromJson(Map<String, dynamic> json) {
    return KnowledgePublishResult(
      knowledgeId: json['knowledge_id'] as String,
      status: KnowledgeStatus.fromValue(json['status'] as String),
      message: (json['message'] as String?) ?? '지식이 발행되었습니다.',
    );
  }
}
