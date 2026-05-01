"""
파일명: admin.py
위치: backend/app/api/v1/endpoints/admin.py
레이어: API (관리자 전용)
역할: X-Admin-Token 인증 하에 지식 검수 등 관리 작업을 노출한다.

엔드포인트:
  POST /api/v1/admin/knowledge/review — 지식 승인(active) / 기각(rejected)

작성일: 2026-05-01
"""

from fastapi import APIRouter, Depends
from supabase import AsyncClient

from app.dependencies import get_admin_token, get_db
from app.schemas.admin_knowledge import (
    AdminKnowledgeReviewRequest,
    AdminKnowledgeReviewResponse,
)
from app.schemas.common import BaseResponse
from app.services import admin_knowledge_service

router = APIRouter(dependencies=[Depends(get_admin_token)])


@router.post(
    "/knowledge/review",
    response_model=BaseResponse[AdminKnowledgeReviewResponse],
    summary="지식 검수 (관리자)",
    description=(
        "pending 지식을 active 또는 rejected로 전환합니다.\n\n"
        "**인증:** `X-Admin-Token` 헤더 필수 (`ADMIN_SECRET_TOKEN`과 일치).\n\n"
        "- `active`: `new_system_score` 미입력 시 0.5로 `fn_recalculate_trust_score` 반영.\n"
        "- `rejected`: 품질 점수 없이 상태만 기각."
    ),
)
async def review_knowledge(
    request: AdminKnowledgeReviewRequest,
    db: AsyncClient = Depends(get_db),
) -> BaseResponse[AdminKnowledgeReviewResponse]:
    """
    관리자가 지식 검수 결과를 반영한다.

    Args:
        request: knowledge_id, new_status, 선택적 new_system_score
        db: Supabase 클라이언트

    Returns:
        BaseResponse: 갱신된 상태 및 trust_score
    """
    data = await admin_knowledge_service.review_knowledge(request, db)
    return BaseResponse[AdminKnowledgeReviewResponse](data=data)
