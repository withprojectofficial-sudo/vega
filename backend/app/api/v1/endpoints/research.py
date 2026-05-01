"""
파일명: research.py
위치: backend/app/api/v1/endpoints/research.py
레이어: API (리서치 엔드포인트)
역할: 자연어 질문을 받아 Grok API로 리서치하고 관련 지식을 자동 인용하는 엔드포인트.
      Post-MVP에서 기능이 확장될 예정이다.

엔드포인트:
  POST /api/v1/research  - 질문 → Grok 리서치 + 관련 지식 자동 검색

작성일: 2026-05-01
"""

from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends
from supabase import AsyncClient

import httpx

from app.config import settings
from app.dependencies import get_current_agent, get_db
from app.exceptions import VegaError, VegaErrorCode
from app.schemas.agent import AgentInDB
from app.schemas.common import BaseResponse
from app.schemas.knowledge import KnowledgeItem, KnowledgeDomain
from app.services.embedding_service import embedding_service
from app.utils.logger import get_logger

logger = get_logger(__name__)
router = APIRouter()


# ── 요청/응답 모델 (research 전용) ──

class ResearchRequest(BaseModel):
    """POST /api/v1/research 요청 본문."""

    question: str = Field(
        min_length=10, max_length=1000,
        description="리서치할 질문 (자연어, 10~1000자)"
    )
    domain: KnowledgeDomain | None = Field(
        default=None, description="관련 도메인 필터 (선택)"
    )
    include_related_knowledge: bool = Field(
        default=True, description="관련 Vega 지식 목록 포함 여부"
    )


class ResearchResponse(BaseModel):
    """POST /api/v1/research 성공 응답."""

    question: str = Field(description="원본 질문")
    grok_summary: str = Field(description="Grok AI 리서치 요약 결과")
    related_knowledge: list[KnowledgeItem] = Field(
        default=[], description="관련 Vega 지식 목록 (유사도 순)"
    )
    knowledge_count: int = Field(description="관련 지식 수")


async def _call_grok_research(question: str) -> str:
    """
    Grok API에 리서치 질문을 전송하고 요약 결과를 반환한다.

    Args:
        question: 리서치 질문

    Returns:
        str: Grok AI 요약 결과

    Raises:
        VegaError(VEGA_006): Grok API 호출 실패 시
    """
    system_prompt = (
        "당신은 Vega 플랫폼의 지식 큐레이터입니다. "
        "사용자의 질문에 대해 신뢰할 수 있는 정보를 바탕으로 핵심을 간결하게 요약하세요. "
        "불확실한 정보는 반드시 명시하고, 출처가 필요한 주장은 [출처 필요] 태그를 붙이세요."
    )

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f"{settings.grok_api_base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.GROK_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "grok-3",
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": question},
                    ],
                    "max_tokens": 1000,
                    "temperature": 0.3,  # 낮은 온도 = 일관성 있는 팩트 위주 답변
                },
            )
            response.raise_for_status()
    except httpx.HTTPError as e:
        logger.error("Grok 리서치 API 호출 실패", error=str(e))
        raise VegaError(VegaErrorCode.EMBEDDING_FAILED, "Grok AI 리서치 호출에 실패했습니다.")

    result = response.json()
    return result["choices"][0]["message"]["content"]


@router.post(
    "",
    response_model=BaseResponse[ResearchResponse],
    summary="AI 리서치",
    description=(
        "자연어 질문을 Grok AI로 리서치하고, 관련 Vega 지식을 시맨틱 검색으로 함께 반환합니다.\n\n"
        "API Key 인증이 필요합니다."
    ),
)
async def research(
    request: ResearchRequest,
    current_agent: AgentInDB = Depends(get_current_agent),
    db: AsyncClient = Depends(get_db),
) -> BaseResponse[ResearchResponse]:
    """
    질문에 대해 Grok AI 리서치를 수행하고 관련 Vega 지식을 검색한다.

    처리 순서:
      1. Grok API로 질문 요약 생성
      2. 질문 임베딩 생성
      3. pgvector로 관련 Vega 지식 검색 (선택적)
      4. 요약 + 관련 지식 통합 반환

    Args:
        request: 리서치 요청 (question, domain, include_related_knowledge)
        current_agent: 인증된 에이전트
        db: Supabase 클라이언트

    Returns:
        BaseResponse[ResearchResponse]: Grok 요약 + 관련 지식 목록
    """
    logger.info("리서치 시작", agent_id=current_agent.id, question_length=len(request.question))

    # Grok 리서치 + 임베딩 병렬 실행
    import asyncio
    grok_task = asyncio.create_task(_call_grok_research(request.question))
    embedding_task = asyncio.create_task(
        embedding_service.generate(request.question)
    ) if request.include_related_knowledge else None

    grok_summary = await grok_task
    related_knowledge: list[KnowledgeItem] = []

    # 관련 지식 검색 (임베딩 결과 활용)
    if embedding_task is not None:
        try:
            query_embedding = await embedding_task
            rpc_params: dict = {
                "query_embedding": query_embedding,
                "match_threshold": 0.6,   # 리서치 결과는 더 엄격한 임계값
                "match_count": 5,         # 최대 5개
            }
            if request.domain is not None:
                rpc_params["filter_domain"] = request.domain.value

            search_result = await db.rpc("fn_search_knowledge", rpc_params).execute()

            related_knowledge = [
                KnowledgeItem(
                    id=row["id"],
                    title=row["title"],
                    content_claim=row["content_claim"],
                    domain=KnowledgeDomain(row["domain"]),
                    tags=row.get("tags", []),
                    trust_score=row["trust_score"],
                    citation_price=row["citation_price"],
                    citation_count=row["citation_count"],
                    status=row["status"],
                    publisher_id=row["publisher_id"],
                    publisher_name=row["publisher_name"],
                    publisher_trust_score=row["publisher_trust_score"],
                    created_at=row["created_at"],
                    similarity_score=row.get("similarity"),
                )
                for row in (search_result.data or [])
            ]
        except Exception as e:
            # 관련 지식 검색 실패는 전체 응답 실패로 이어지지 않음
            logger.warning("리서치 관련 지식 검색 실패 (응답에서 제외)", error=str(e))

    logger.info(
        "리서치 완료",
        agent_id=current_agent.id,
        related_count=len(related_knowledge),
    )

    return BaseResponse[ResearchResponse](
        data=ResearchResponse(
            question=request.question,
            grok_summary=grok_summary,
            related_knowledge=related_knowledge,
            knowledge_count=len(related_knowledge),
        )
    )
