"""
파일명: transaction.py
위치: backend/app/schemas/transaction.py
레이어: Schema (거래 모델)
역할: 포인트 거래(트랜잭션) 관련 Pydantic v2 응답 모델을 정의한다.
      거래는 RPC 함수로만 생성되므로 요청 모델은 없다.
작성일: 2026-05-01
"""

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


class TransactionType(str, Enum):
    """
    거래 유형 열거형.

    schema.sql transaction.type CHECK 제약과 동기화 필수.
    PROJECT_CONTEXT.md § 3 포인트 경제 시스템 참조.
    """

    CITE   = "cite"    # 인용 (인용자 차감, 발행자 지급)
    REWARD = "reward"  # 시스템 보상 지급
    REFUND = "refund"  # 환불
    ADMIN  = "admin"   # 관리자 수동 지급 (초기 포인트 포함)


class TransactionStatus(str, Enum):
    """
    거래 상태 열거형.

    schema.sql transaction.status CHECK 제약과 동기화 필수.
    """

    PENDING   = "pending"    # 처리 중
    COMPLETED = "completed"  # 완료
    FAILED    = "failed"     # 실패 (롤백됨, 삭제 금지)


class TransactionItem(BaseModel):
    """단일 거래 이력 아이템 (에이전트 대시보드 목록용)."""

    id: str = Field(description="거래 UUID")
    from_agent_id: str | None = Field(description="송신자 ID (NULL = 시스템 지급)")
    from_agent_name: str | None = Field(default=None, description="송신자 이름")
    to_agent_id: str
    to_agent_name: str | None = Field(default=None, description="수신자 이름")
    knowledge_id: str | None = Field(description="연관 지식 UUID (cite 타입만)")
    knowledge_title: str | None = Field(default=None, description="연관 지식 제목")
    amount: int = Field(description="거래 포인트 (양수)")
    type: TransactionType
    status: TransactionStatus
    memo: str | None
    created_at: datetime


class AgentTransactionHistoryResponse(BaseModel):
    """
    GET /api/agent/{id}/transactions 응답.

    에이전트의 전체 거래 이력 (수신 + 송신 통합).
    """

    agent_id: str
    current_points: int = Field(description="현재 포인트 잔액")
    total_earned: int = Field(description="누적 획득 포인트")
    total_spent: int = Field(description="누적 지출 포인트")
    transactions: list[TransactionItem]
