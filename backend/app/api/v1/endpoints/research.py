"""
파일명: research.py
위치: backend/app/api/v1/endpoints/research.py
레이어: API (리서치 엔드포인트)
역할: 자연어 질문을 받아 Groq API(OpenAI 호환)로 리서치하고 관련 지식을 검색하는 엔드포인트.
      Post-MVP에서 기능이 확장될 예정이다.

엔드포인트:
  POST /api/v1/research  - 질문 → Groq LLM 요약 + 관련 지식 시맨틱 검색

작성일: 2026-05-01
수정일: 2026-05-01 (Grok(xAI) → Groq 무료 API)
"""

import asyncio

import httpx
from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field
from supabase import AsyncClient

from app.config import settings
from app.dependencies import get_current_agent, get_db
from app.exceptions import VegaError, VegaErrorCode
from app.limiter import limiter
from app.schemas.agent import AgentInDB
from app.schemas.common import BaseResponse
from app.schemas.knowledge import KnowledgeDomain, KnowledgeItem
from app.services.embedding_service import embedding_service
from app.utils.logger import get_logger

logger = get_logger(__name__)
router = APIRouter()


class ResearchRequest(BaseModel):
    """POST /api/v1/research 요청 본문."""

    question: str = Field(
        min_length=10,
        max_length=1000,
        description="리서치할 질문 (자연어, 10~1000자)",
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
    ai_summary: str = Field(description="Groq LLM 리서치 요약 결과")
    related_knowledge: list[KnowledgeItem] = Field(
        default=[], description="관련 Vega 지식 목록 (유사도 순)"
    )
    knowledge_count: int = Field(description="관련 지식 수")


async def _call_groq_research(question: str) -> str:
    """
    Groq OpenAI 호환 API에 리서치 질문을 전송하고 요약 결과를 반환한다.

    Args:
        question: 리서치 질문

    Returns:
        str: LLM 요약 결과

    Raises:
        VegaError(VEGA_011): Groq API 호출 실패 시
    """
    system_prompt = (
        "당신은 Vega 플랫폼의 지식 큐레이터입니다. "
        "사용자의 질문에 대해 신뢰할 수 있는 정보를 바탕으로 핵심을 간결하게 요약하세요. "
        "불확실한 정보는 반드시 명시하고, 출처가 필요한 주장은 [출처 필요] 태그를 붙이세요."
    )

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f"{settings.groq_api_base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.GROQ_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": settings.GROQ_CHAT_MODEL,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": question},
                    ],
                    "max_tokens": 1000,
                    "temperature": 0.3,
                },
            )
            response.raise_for_status()
    except httpx.RequestError as e:
        logger.error("Groq 리서치 API 호출 실패", error=str(e))
        raise VegaError(
            VegaErrorCode.LLM_PROVIDER_FAILED,
            "Groq AI 리서치 호출에 실패했습니다.",
        ) from e

    try:
        result = response.json()
        return str(result["choices"][0]["message"]["content"])
    except (KeyError, TypeError, ValueError) as e:
        logger.error("Groq 응답 파싱 실패", error=str(e))
        raise VegaError(
            VegaErrorCode.LLM_PROVIDER_FAILED,
            "Groq AI 응답을 처리하지 못했습니다.",
        ) from e


@router.post(
    "",
    response_model=BaseResponse[ResearchResponse],
    summary="AI 리서치",
    description=(
        "자연어 질문을 Groq LLM으로 요약하고, 관련 Vega 지식을 시맨틱 검색으로 함께 반환합니다.\n\n"
        "API Key 인증이 필요합니다."
    ),
)
@limiter.limit("5/minute")
async def research(
    request: Request,
    body: ResearchRequest,
    current_agent: AgentInDB = Depends(get_current_agent),
    db: AsyncClient = Depends(get_db),
) -> BaseResponse[ResearchResponse]:
    """
    질문에 대해 Groq LLM 리서치를 수행하고 관련 Vega 지식을 검색한다.

    처리 순서:
      1. Groq API로 질문 요약 생성
      2. 질문 임베딩 생성 (로컬 모델)
      3. pgvector로 관련 Vega 지식 검색 (선택적)
      4. 요약 + 관련 지식 통합 반환
    """
    logger.info("리서치 시작", agent_id=current_agent.id, question_length=len(body.question))

    llm_task = asyncio.create_task(_call_groq_research(body.question))
    embedding_task: asyncio.Task[list[float]] | None = None
    if body.include_related_knowledge:
        embedding_task = asyncio.create_task(
            embedding_service.generate(body.question, for_query=True),
        )

    ai_summary = await llm_task
    related_knowledge: list[KnowledgeItem] = []

    if embedding_task is not None:
        try:
            query_embedding = await embedding_task
            rpc_params: dict = {
                "query_embedding": query_embedding,
                "match_threshold": 0.6,
                "match_count": 5,
            }
            if body.domain is not None:
                rpc_params["filter_domain"] = body.domain.value

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
            logger.warning("리서치 관련 지식 검색 실패 (응답에서 제외)", error=str(e))

    logger.info(
        "리서치 완료",
        agent_id=current_agent.id,
        related_count=len(related_knowledge),
    )

    return BaseResponse[ResearchResponse](
        data=ResearchResponse(
            question=body.question,
            ai_summary=ai_summary,
            related_knowledge=related_knowledge,
            knowledge_count=len(related_knowledge),
        )
    )
