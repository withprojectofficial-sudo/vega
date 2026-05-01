"""
파일명: admin_knowledge_service.py
위치: backend/app/services/admin_knowledge_service.py
레이어: Service (관리자·지식 검수)
역할: fn_update_knowledge_status RPC를 호출해 pending 지식을 active/rejected로 전환한다.
작성일: 2026-05-01
"""

import json
from typing import cast

from supabase import AsyncClient

from app.exceptions import VegaError, VegaErrorCode
from app.schemas.admin_knowledge import (
    AdminKnowledgeReviewRequest,
    AdminKnowledgeReviewResponse,
    AdminKnowledgeStatus,
)
from app.utils.logger import get_logger

logger = get_logger(__name__)

_DEFAULT_SYSTEM_SCORE_FOR_APPROVAL = 0.5

_UPDATE_STATUS_ERROR_MAP: dict[str, VegaErrorCode] = {
    "VEGA_003": VegaErrorCode.KNOWLEDGE_STATUS_INVALID,
    "VEGA_004": VegaErrorCode.KNOWLEDGE_NOT_FOUND,
}


def _unwrap_rpc_json(data: object) -> dict[str, object]:
    """RPC JSON 응답을 dict로 정규화한다."""
    if isinstance(data, str):
        try:
            parsed = json.loads(data)
        except json.JSONDecodeError as e:
            raise VegaError(
                VegaErrorCode.TRANSACTION_FAILED,
                "검수 RPC 응답 JSON 파싱에 실패했습니다.",
            ) from e
        if not isinstance(parsed, dict):
            raise VegaError(
                VegaErrorCode.TRANSACTION_FAILED,
                "검수 RPC 응답 형식이 올바르지 않습니다.",
            )
        return cast(dict[str, object], parsed)
    if isinstance(data, list) and len(data) == 1 and isinstance(data[0], dict):
        return cast(dict[str, object], data[0])
    if isinstance(data, dict):
        return cast(dict[str, object], data)
    raise VegaError(
        VegaErrorCode.TRANSACTION_FAILED,
        "검수 RPC 응답 형식이 올바르지 않습니다.",
    )


def _parse_update_error(msg: str) -> tuple[VegaErrorCode, str]:
    for code_str, err in _UPDATE_STATUS_ERROR_MAP.items():
        if code_str in msg:
            parts = msg.split(":", 1)
            detail = parts[1].strip() if len(parts) > 1 else msg
            return err, detail
    return VegaErrorCode.TRANSACTION_FAILED, "지식 검수 처리 중 오류가 발생했습니다."


def _raw_message(exc: Exception) -> str:
    msg = str(exc)
    m = getattr(exc, "message", None)
    if isinstance(m, str) and m.strip():
        msg = m
    d = getattr(exc, "details", None)
    if isinstance(d, str) and d.strip():
        msg = f"{msg} {d}"
    return msg


async def review_knowledge(
    request: AdminKnowledgeReviewRequest,
    db: AsyncClient,
) -> AdminKnowledgeReviewResponse:
    """
    관리자 검수로 지식 상태를 active 또는 rejected로 변경한다.

    Args:
        request: knowledge_id, new_status, 선택적 system_score
        db: Supabase 클라이언트

    Returns:
        AdminKnowledgeReviewResponse

    Raises:
        VegaError: RPC RAISE 또는 통신 실패 시
    """
    system_score: float | None = request.new_system_score
    if request.new_status == AdminKnowledgeStatus.ACTIVE and system_score is None:
        system_score = _DEFAULT_SYSTEM_SCORE_FOR_APPROVAL
    if request.new_status == AdminKnowledgeStatus.REJECTED:
        system_score = None

    logger.info(
        "지식 검수 RPC 호출",
        knowledge_id=request.knowledge_id,
        new_status=request.new_status.value,
    )
    try:
        result = await db.rpc(
            "fn_update_knowledge_status",
            {
                "p_knowledge_id": request.knowledge_id,
                "p_new_status": request.new_status.value,
                "p_new_system_score": system_score,
            },
        ).execute()
    except Exception as e:
        code, detail = _parse_update_error(_raw_message(e))
        logger.warning(
            "지식 검수 RPC 실패",
            knowledge_id=request.knowledge_id,
            error_code=code.value,
        )
        raise VegaError(code, detail) from e

    raw = _unwrap_rpc_json(result.data)
    return AdminKnowledgeReviewResponse(
        knowledge_id=str(raw["knowledge_id"]),
        new_status=str(raw["new_status"]),
        new_trust_score=float(raw["new_trust_score"]),
    )
