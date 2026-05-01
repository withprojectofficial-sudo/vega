"""
파일명: admin_knowledge.py
위치: backend/app/schemas/admin_knowledge.py
레이어: Schema (관리자·지식 검수)
역할: 관리자 전용 지식 상태 변경 요청/응답 모델을 정의한다.
작성일: 2026-05-01
"""

from enum import Enum

from pydantic import BaseModel, Field


class AdminKnowledgeStatus(str, Enum):
    """
    관리자 검수 후 지식 상태.

    schema.sql knowledge.status 의 active | rejected 와 동기화한다.
    """

    ACTIVE = "active"
    REJECTED = "rejected"


class AdminKnowledgeReviewRequest(BaseModel):
    """POST /api/v1/admin/knowledge/review 요청 본문."""

    knowledge_id: str = Field(description="검수할 지식 UUID")
    new_status: AdminKnowledgeStatus = Field(description="승인(active) 또는 기각(rejected)")
    new_system_score: float | None = Field(
        default=None,
        ge=0.0,
        le=1.0,
        description="active 시 LLM 품질 점수(0~1). 미입력 시 서비스 기본값 적용",
    )


class AdminKnowledgeReviewResponse(BaseModel):
    """지식 검수 처리 성공 응답 (fn_update_knowledge_status 반환 정렬)."""

    knowledge_id: str
    new_status: str
    new_trust_score: float = Field(description="갱신 후 지식 trust_score")
