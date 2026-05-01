"""
파일명: agent.py
위치: backend/app/schemas/agent.py
레이어: Schema (에이전트 모델)
역할: 에이전트 관련 요청/응답 Pydantic v2 모델을 정의한다.
      AgentInDB는 내부 전용 모델로 api_key_hash를 포함한다 (응답에 절대 포함 금지).
작성일: 2026-05-01
"""

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field, field_validator


class AgentType(str, Enum):
    """에이전트 유형 열거형. DB schema.sql의 CHECK 제약과 동기화 유지."""

    HUMAN = "human"    # 인간 전문가
    AI    = "ai"       # AI 에이전트
    ADMIN = "admin"    # 관리자 (직접 생성 불가, 시스템 설정)


# ── 요청 모델 ──

class AgentRegisterRequest(BaseModel):
    """
    POST /api/agent/register 요청 본문.

    에이전트 등록 시 클라이언트가 전달하는 정보.
    type은 'human' 또는 'ai'만 허용 (admin은 시스템 내부에서만 설정).
    """

    name: str = Field(min_length=2, max_length=50, description="에이전트 이름 (2~50자)")
    type: AgentType = Field(default=AgentType.HUMAN, description="에이전트 유형")
    bio: str | None = Field(default=None, max_length=300, description="자기소개 (선택, 최대 300자)")

    @field_validator("type")
    @classmethod
    def validate_type(cls, value: AgentType) -> AgentType:
        """admin 타입은 직접 등록 불가."""
        if value == AgentType.ADMIN:
            raise ValueError("admin 타입은 직접 등록할 수 없습니다.")
        return value


# ── 응답 모델 ──

class AgentRegisterResponse(BaseModel):
    """
    POST /api/agent/register 성공 응답.

    api_key는 이 응답에서 1회만 반환되며 이후 복구 불가.
    클라이언트는 반드시 안전한 곳에 저장해야 한다.
    """

    agent_id: str = Field(description="생성된 에이전트 UUID")
    api_key: str = Field(description="⚠ 1회만 반환. 반드시 안전하게 저장하세요.")
    initial_points: int = Field(description="등록 시 지급된 초기 포인트 (기본: 100)")
    message: str = Field(default="에이전트 등록이 완료되었습니다. API Key를 안전하게 보관하세요.")


class AgentPointsResponse(BaseModel):
    """GET /api/agent/{id}/points 성공 응답."""

    agent_id: str
    name: str
    type: AgentType
    points: int = Field(description="현재 포인트 잔액")
    trust_score: float = Field(description="에이전트 신뢰점수 (0.0 ~ 1.0)")


class AgentProfileResponse(BaseModel):
    """에이전트 공개 프로필 (api_key_hash 제외)."""

    agent_id: str
    name: str
    type: AgentType
    bio: str | None
    trust_score: float
    is_active: bool
    created_at: datetime


# ── 내부 전용 모델 ──

class AgentInDB(BaseModel):
    """
    DB에서 조회한 에이전트 전체 데이터를 담는 내부 모델.

    ⚠ 이 모델은 절대 API 응답에 직접 사용하지 않는다.
    api_key_hash가 포함되어 있어 외부 노출 시 보안 취약점 발생.
    dependencies.py의 get_current_agent()에서 내부 전달용으로만 사용한다.
    """

    id: str
    name: str
    bio: str | None = None
    api_key_hash: str       # ⚠ 절대 응답에 포함하지 말 것
    type: AgentType
    points: int
    trust_score: float
    is_active: bool
    created_at: datetime
    updated_at: datetime
