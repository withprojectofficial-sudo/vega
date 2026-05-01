"""
파일명: knowledge.py
위치: backend/app/schemas/knowledge.py
레이어: Schema (지식 모델)
역할: 지식 발행/검색/인용 관련 요청/응답 Pydantic v2 모델을 정의한다.
      도메인 열거형과 상태 열거형은 schema.sql의 CHECK 제약과 동기화한다.
작성일: 2026-05-01
"""

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field, field_validator


class KnowledgeDomain(str, Enum):
    """
    지식 도메인 열거형.

    PROJECT_CONTEXT.md § 5 타겟 전략 기반.
    schema.sql knowledge.domain CHECK 제약과 동기화 필수.
    """

    MEDICAL    = "medical"     # 의료
    ECONOMICS  = "economics"   # 경제
    LAW        = "law"         # 법률
    SCIENCE    = "science"     # 과학
    AI_TRENDS  = "ai_trends"   # AI 트렌드
    OTHER      = "other"       # 기타 (확장 전 임시)


class KnowledgeStatus(str, Enum):
    """
    지식 생명주기 상태 열거형.

    PROJECT_CONTEXT.md § 4 지식 생명주기 참조.
    schema.sql knowledge.status CHECK 제약과 동기화 필수.
    """

    PENDING  = "pending"   # 발행 직후 (LLM 품질 평가 대기)
    ACTIVE   = "active"    # 인용 가능 (LLM 평가 완료)
    REJECTED = "rejected"  # 인용 불가 (관리자 기각)


# ── 요청 모델 ──

class KnowledgePublishRequest(BaseModel):
    """
    POST /api/knowledge/publish 요청 본문.

    content_claim이 임베딩 대상이므로 간결하게 작성 권장.
    상세 내용은 content_body에 분리.
    """

    title: str = Field(min_length=5, max_length=200, description="지식 제목 (5~200자)")
    content_claim: str = Field(
        min_length=10, max_length=1000,
        description="핵심 주장 — 임베딩 대상. 간결하게 작성 (10~1000자)."
    )
    content_body: str | None = Field(
        default=None, max_length=10000,
        description="부연 설명 (선택, 최대 10000자). 임베딩 제외."
    )
    domain: KnowledgeDomain = Field(default=KnowledgeDomain.OTHER, description="지식 도메인")
    tags: list[str] = Field(default=[], max_length=10, description="태그 목록 (최대 10개)")
    citation_price: int = Field(default=10, ge=1, le=1000, description="인용 비용 포인트 (1~1000)")

    @field_validator("tags")
    @classmethod
    def validate_tags(cls, tags: list[str]) -> list[str]:
        """태그 길이 제한 및 중복 제거."""
        cleaned = list({tag.strip() for tag in tags if tag.strip()})
        if any(len(tag) > 30 for tag in cleaned):
            raise ValueError("각 태그는 30자를 초과할 수 없습니다.")
        return cleaned


class KnowledgeSearchRequest(BaseModel):
    """
    GET /api/knowledge/search 쿼리 파라미터.

    pgvector cosine similarity 기반 시맨틱 검색에 사용한다.
    """

    query: str = Field(min_length=2, max_length=500, description="검색 쿼리 (자연어)")
    domain: KnowledgeDomain | None = Field(default=None, description="도메인 필터 (선택)")
    limit: int = Field(default=10, ge=1, le=50, description="결과 수 (1~50)")
    threshold: float = Field(
        default=0.5, ge=0.0, le=1.0,
        description="최소 유사도 임계값 (0.0~1.0, 높을수록 엄격)"
    )


class KnowledgeCiteRequest(BaseModel):
    """POST /api/knowledge/cite 요청 본문."""

    knowledge_id: str = Field(description="인용할 지식의 UUID")


# ── 응답 모델 ──

class KnowledgePublishResponse(BaseModel):
    """POST /api/knowledge/publish 성공 응답."""

    knowledge_id: str = Field(description="생성된 지식 UUID")
    status: KnowledgeStatus = Field(description="초기 상태 (pending — LLM 품질 평가 대기)")
    message: str = Field(default="지식이 발행되었습니다. LLM 품질 평가 후 active 상태로 전환됩니다.")


class KnowledgeItem(BaseModel):
    """지식 목록/검색 결과의 단일 아이템."""

    id: str
    title: str
    content_claim: str
    domain: KnowledgeDomain
    tags: list[str]
    trust_score: float
    citation_price: int
    citation_count: int
    status: KnowledgeStatus
    publisher_id: str
    publisher_name: str
    publisher_trust_score: float
    created_at: datetime
    # 검색 결과에서만 포함 (일반 목록에서는 None)
    similarity_score: float | None = None


class KnowledgeDetailResponse(BaseModel):
    """GET /api/knowledge/{id} 상세 조회 응답."""

    id: str
    title: str
    content_claim: str
    content_body: str | None
    domain: KnowledgeDomain
    tags: list[str]
    trust_score: float
    system_score: float
    agent_vote_score: float
    admin_score: float
    status: KnowledgeStatus
    citation_price: int
    citation_count: int
    publisher_id: str
    publisher_name: str
    publisher_type: str
    publisher_trust_score: float
    created_at: datetime
    updated_at: datetime


class KnowledgeCiteResponse(BaseModel):
    """POST /api/knowledge/cite 성공 응답."""

    transaction_id: str = Field(description="생성된 포인트 거래 UUID")
    new_citation_count: int = Field(description="갱신된 인용 횟수")
    new_trust_score: float = Field(description="갱신된 지식 신뢰점수")
    citer_remaining_points: int = Field(description="인용 후 인용자의 잔여 포인트")
    publisher_earned_points: int = Field(description="발행자가 획득한 포인트")
    message: str = Field(default="인용이 완료되었습니다.")
