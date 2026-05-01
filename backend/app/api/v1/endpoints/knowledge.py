"""
파일명: knowledge.py
위치: backend/app/api/v1/endpoints/knowledge.py
레이어: API (지식 엔드포인트)
역할: 지식 발행, 검색, 상세 조회, 인용 HTTP 엔드포인트를 정의한다.
      비즈니스 로직은 knowledge_service.py, citation_service.py에 위임한다.

엔드포인트:
  POST /api/v1/knowledge/publish  - 지식 발행 + 임베딩 생성 (인증 필요)
  GET  /api/v1/knowledge/search   - 시맨틱 검색 (인증 불필요)
  POST /api/v1/knowledge/cite     - 지식 인용 원자적 트랜잭션 (인증 필요)
  GET  /api/v1/knowledge/{id}     - 지식 상세 조회 (인증 불필요)

작성일: 2026-05-01
"""

from fastapi import APIRouter, Depends, Query, Request
from supabase import AsyncClient

from app.dependencies import get_current_agent, get_db
from app.limiter import limiter
from app.schemas.agent import AgentInDB
from app.schemas.common import BaseResponse, PaginatedResponse
from app.schemas.knowledge import (
    KnowledgeCiteRequest,
    KnowledgeCiteResponse,
    KnowledgeDetailResponse,
    KnowledgeDomain,
    KnowledgeItem,
    KnowledgePublishRequest,
    KnowledgePublishResponse,
    KnowledgeSearchRequest,
)
from app.services import citation_service, knowledge_service

router = APIRouter()


@router.post(
    "/publish",
    response_model=BaseResponse[KnowledgePublishResponse],
    status_code=201,
    summary="지식 발행",
    description=(
        "지식을 발행하고 content_claim에 대한 임베딩을 자동 생성합니다.\n\n"
        "발행 직후 상태는 `pending`이며, LLM(Groq) 품질 평가 완료 후 `active`로 전환됩니다."
    ),
)
@limiter.limit("3/minute")
async def publish_knowledge(
    request: Request,
    body: KnowledgePublishRequest,
    current_agent: AgentInDB = Depends(get_current_agent),
    db: AsyncClient = Depends(get_db),
) -> BaseResponse[KnowledgePublishResponse]:
    """
    지식을 발행한다. API Key 인증 필요.

    Args:
        body: 지식 발행 정보 (title, content_claim, domain, tags 등)
        current_agent: 인증된 발행자 에이전트
        db: Supabase 클라이언트

    Returns:
        BaseResponse[KnowledgePublishResponse]: knowledge_id + pending 상태
    """
    result = await knowledge_service.publish_knowledge(body, current_agent, db)
    return BaseResponse[KnowledgePublishResponse](data=result)


@router.get(
    "/search",
    response_model=PaginatedResponse[KnowledgeItem],
    summary="지식 시맨틱 검색",
    description="pgvector cosine similarity 기반 시맨틱 검색. 인증 불필요.",
)
async def search_knowledge(
    query: str = Query(min_length=2, max_length=500, description="검색 쿼리 (자연어)"),
    domain: KnowledgeDomain | None = Query(default=None, description="도메인 필터"),
    limit: int = Query(default=10, ge=1, le=50, description="결과 수"),
    threshold: float = Query(default=0.5, ge=0.0, le=1.0, description="최소 유사도"),
    db: AsyncClient = Depends(get_db),
) -> PaginatedResponse[KnowledgeItem]:
    """
    pgvector 기반 시맨틱 지식 검색을 수행한다. 인증 불필요.

    Args:
        query: 자연어 검색 쿼리
        domain: 도메인 필터 (선택)
        limit: 최대 결과 수 (1~50)
        threshold: 최소 cosine similarity (0.0~1.0)
        db: Supabase 클라이언트

    Returns:
        PaginatedResponse[KnowledgeItem]: 유사도 순 정렬된 지식 목록
    """
    request = KnowledgeSearchRequest(
        query=query, domain=domain, limit=limit, threshold=threshold
    )
    return await knowledge_service.search_knowledge(request, db)


@router.post(
    "/cite",
    response_model=BaseResponse[KnowledgeCiteResponse],
    summary="지식 인용 (⚡ 원자적 트랜잭션)",
    description=(
        "지식을 인용하고 포인트를 정산합니다.\n\n"
        "⚡ **포인트 차감·지급·카운트 증가가 단일 DB 트랜잭션으로 처리됩니다.**\n\n"
        "- 포인트 부족 시 인용 거부 (VEGA_002)\n"
        "- 자기 인용 불가 (VEGA_009)\n"
        "- 동일 지식 중복 인용 불가 (VEGA_010)"
    ),
)
async def cite_knowledge(
    request: KnowledgeCiteRequest,
    current_agent: AgentInDB = Depends(get_current_agent),
    db: AsyncClient = Depends(get_db),
) -> BaseResponse[KnowledgeCiteResponse]:
    """
    지식을 인용하고 포인트를 원자적으로 정산한다. API Key 인증 필요.

    Args:
        request: 인용 요청 (knowledge_id)
        current_agent: 인증된 인용자(consumer) 에이전트
        db: Supabase 클라이언트

    Returns:
        BaseResponse[KnowledgeCiteResponse]: 트랜잭션 결과 (잔여 포인트, 갱신된 카운트 등)
    """
    result = await citation_service.cite_knowledge(
        request.knowledge_id, current_agent, db
    )
    return BaseResponse[KnowledgeCiteResponse](data=result)


@router.get(
    "/{knowledge_id}",
    response_model=BaseResponse[KnowledgeDetailResponse],
    summary="지식 상세 조회",
    description="지식 상세 정보와 신뢰점수 구성요소를 조회합니다. 인증 불필요.",
)
async def get_knowledge_detail(
    knowledge_id: str,
    db: AsyncClient = Depends(get_db),
) -> BaseResponse[KnowledgeDetailResponse]:
    """
    지식 상세 정보를 조회한다. 인증 불필요.

    Args:
        knowledge_id: 조회할 지식 UUID
        db: Supabase 클라이언트

    Returns:
        BaseResponse[KnowledgeDetailResponse]: 지식 상세 + 신뢰점수 구성요소 + 발행자 정보
    """
    result = await knowledge_service.get_knowledge_detail(knowledge_id, db)
    return BaseResponse[KnowledgeDetailResponse](data=result)
