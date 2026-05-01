"""
파일명: knowledge_service.py
위치: backend/app/services/knowledge_service.py
레이어: Service (지식 비즈니스 로직)
역할: 지식 발행, 시맨틱 검색, 상세 조회 비즈니스 로직을 처리한다.
      발행 시 로컬 임베딩 생성 → DB 저장 → LLM 품질 평가(관리자 플로우) 순서로 처리한다.
작성일: 2026-05-01
"""

from supabase import AsyncClient

from app.exceptions import VegaError, VegaErrorCode
from app.schemas.agent import AgentInDB
from app.schemas.common import PaginatedResponse, PaginationMeta
from app.schemas.knowledge import (
    KnowledgeDomain,
    KnowledgeDetailResponse,
    KnowledgeItem,
    KnowledgePublishRequest,
    KnowledgePublishResponse,
    KnowledgeSearchRequest,
    KnowledgeStatus,
)
from app.services.embedding_service import embedding_service
from app.utils.logger import get_logger

logger = get_logger(__name__)


async def publish_knowledge(
    request: KnowledgePublishRequest,
    current_agent: AgentInDB,
    db: AsyncClient,
) -> KnowledgePublishResponse:
    """
    지식을 발행하고 임베딩을 생성한 후 DB에 저장한다.

    처리 순서:
      1. content_claim 임베딩 생성 (로컬 sentence-transformers, 무료)
      2. knowledge 레코드 INSERT (status: pending)
      3. 응답 반환 (LLM 품질 평가는 별도 관리자 엔드포인트에서 처리)

    Args:
        request: 지식 발행 요청
        current_agent: 인증된 발행자 에이전트
        db: Supabase 비동기 클라이언트

    Returns:
        KnowledgePublishResponse: 생성된 knowledge_id와 pending 상태

    Raises:
        VegaError(VEGA_006): 임베딩 생성 실패 시 (지식 발행 전체 실패)
        VegaError(VEGA_005): DB 저장 실패 시
    """
    # 임베딩 생성 (실패 시 VEGA_006 — 지식 발행 전체 실패)
    logger.info("임베딩 생성 시작", agent_id=current_agent.id, title=request.title)
    embedding_vector = await embedding_service.generate(request.content_claim)

    # DB에 지식 저장
    try:
        result = await db.table("knowledge").insert({
            "agent_id":          current_agent.id,
            "title":             request.title,
            "content_claim":     request.content_claim,
            "content_body":      request.content_body,
            "domain":            request.domain.value,
            "tags":              request.tags,
            "citation_price":    request.citation_price,
            "content_embedding": embedding_vector,
            # status, trust_score 등은 DB 기본값(pending, 0.0) 사용
        }).execute()
    except Exception as e:
        logger.error("지식 발행 DB 저장 실패", agent_id=current_agent.id, error=str(e))
        raise VegaError(VegaErrorCode.TRANSACTION_FAILED, "지식 저장 중 오류가 발생했습니다.")

    knowledge_id: str = result.data[0]["id"]
    logger.info("지식 발행 완료 (pending 상태)", knowledge_id=knowledge_id, agent_id=current_agent.id)

    return KnowledgePublishResponse(knowledge_id=knowledge_id, status=KnowledgeStatus.PENDING)


async def search_knowledge(
    request: KnowledgeSearchRequest,
    db: AsyncClient,
) -> PaginatedResponse[KnowledgeItem]:
    """
    pgvector cosine similarity 기반 시맨틱 지식 검색을 수행한다.

    처리 순서:
      1. 쿼리 텍스트 임베딩 생성
      2. Supabase RPC로 pgvector 유사도 검색 (active 지식만)
      3. threshold 미만 결과 필터링 후 반환

    Args:
        request: 검색 요청 (query, domain, limit, threshold)
        db: Supabase 비동기 클라이언트

    Returns:
        PaginatedResponse[KnowledgeItem]: 유사도 순 정렬된 지식 목록

    Raises:
        VegaError(VEGA_006): 쿼리 임베딩 생성 실패 시
    """
    # 쿼리 임베딩 생성
    query_embedding = await embedding_service.generate(request.query)

    # pgvector 시맨틱 검색 (Supabase RPC 호출)
    # fn_search_knowledge는 향후 rpc_functions.sql에 추가 예정
    # 현재는 Supabase의 match_documents 패턴을 직접 활용
    try:
        rpc_params: dict = {
            "query_embedding": query_embedding,
            "match_threshold": request.threshold,
            "match_count":     request.limit,
        }
        if request.domain is not None:
            rpc_params["filter_domain"] = request.domain.value

        result = await db.rpc("fn_search_knowledge", rpc_params).execute()
    except Exception as e:
        logger.error("지식 검색 RPC 실패", error=str(e))
        raise VegaError(VegaErrorCode.TRANSACTION_FAILED, "검색 중 오류가 발생했습니다.")

    items = [
        KnowledgeItem(
            id=row["id"],
            title=row["title"],
            content_claim=row["content_claim"],
            domain=KnowledgeDomain(row["domain"]),
            tags=row.get("tags", []),
            trust_score=row["trust_score"],
            citation_price=row["citation_price"],
            citation_count=row["citation_count"],
            status=KnowledgeStatus(row["status"]),
            publisher_id=row["publisher_id"],
            publisher_name=row["publisher_name"],
            publisher_trust_score=row["publisher_trust_score"],
            created_at=row["created_at"],
            similarity_score=row.get("similarity"),
        )
        for row in (result.data or [])
    ]

    return PaginatedResponse[KnowledgeItem](
        items=items,
        meta=PaginationMeta(
            total=len(items),
            limit=request.limit,
            offset=0,
            has_more=len(items) == request.limit,
        ),
    )


async def get_knowledge_detail(
    knowledge_id: str,
    db: AsyncClient,
) -> KnowledgeDetailResponse:
    """
    지식 상세 정보를 조회한다. active 상태가 아닌 지식도 조회 가능.

    Args:
        knowledge_id: 조회할 지식 UUID
        db: Supabase 비동기 클라이언트

    Returns:
        KnowledgeDetailResponse: 지식 상세 정보 (발행자 정보 포함)

    Raises:
        VegaError(VEGA_004): 지식 미존재 시
    """
    try:
        # v_active_knowledge 뷰 대신 직접 JOIN (pending 상태도 조회 가능)
        result = await db.table("knowledge").select(
            "*, agent:agent_id(id, name, type, trust_score)"
        ).eq("id", knowledge_id).maybe_single().execute()
    except Exception as e:
        logger.error("지식 상세 조회 DB 오류", knowledge_id=knowledge_id, error=str(e))
        raise VegaError(VegaErrorCode.KNOWLEDGE_NOT_FOUND, "지식 조회 중 오류가 발생했습니다.")

    if result.data is None:
        raise VegaError(VegaErrorCode.KNOWLEDGE_NOT_FOUND, f"지식({knowledge_id})을 찾을 수 없습니다.")

    row = result.data
    publisher = row["agent"]

    return KnowledgeDetailResponse(
        id=row["id"],
        title=row["title"],
        content_claim=row["content_claim"],
        content_body=row.get("content_body"),
        domain=KnowledgeDomain(row["domain"]),
        tags=row.get("tags", []),
        trust_score=row["trust_score"],
        system_score=row["system_score"],
        agent_vote_score=row["agent_vote_score"],
        admin_score=row["admin_score"],
        status=KnowledgeStatus(row["status"]),
        citation_price=row["citation_price"],
        citation_count=row["citation_count"],
        publisher_id=publisher["id"],
        publisher_name=publisher["name"],
        publisher_type=publisher["type"],
        publisher_trust_score=publisher["trust_score"],
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )
