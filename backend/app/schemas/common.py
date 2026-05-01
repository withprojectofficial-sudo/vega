"""
파일명: common.py
위치: backend/app/schemas/common.py
레이어: Schema (공통 응답 모델)
역할: 모든 API 응답에서 공통으로 사용하는 Pydantic v2 모델을 정의한다.
      일관된 응답 구조를 강제해 프론트엔드(Flutter)의 파싱을 단순화한다.
작성일: 2026-05-01
"""

from typing import Generic, TypeVar

from pydantic import BaseModel, Field

# 제네릭 데이터 타입 (응답 데이터의 실제 타입)
DataT = TypeVar("DataT")


class BaseResponse(BaseModel, Generic[DataT]):
    """
    Vega API 표준 성공 응답 래퍼.

    모든 성공 응답은 이 구조를 따른다:
      { "success": true, "data": { ... } }

    사용 예시:
        return BaseResponse[AgentRegisterResponse](data=result)
    """

    success: bool = True
    data: DataT


class ErrorResponse(BaseModel):
    """
    Vega API 표준 오류 응답 구조.

    exceptions.py의 vega_exception_handler가 이 형식으로 응답을 생성한다.
      { "success": false, "error_code": "VEGA_001", "message": "..." }
    """

    success: bool = False
    error_code: str = Field(description="VEGA_XXX 형식의 에러 코드 (CLAUDE.md § 3-3 참조)")
    message: str = Field(description="사용자에게 전달할 한국어 오류 메시지")


class PaginationMeta(BaseModel):
    """
    목록 조회 응답의 페이지네이션 메타데이터.

    지식 검색, 트랜잭션 목록 등 목록 응답에서 사용한다.
    """

    total: int = Field(description="전체 레코드 수")
    limit: int = Field(description="페이지당 레코드 수")
    offset: int = Field(description="현재 페이지 오프셋")
    has_more: bool = Field(description="다음 페이지 존재 여부")


class PaginatedResponse(BaseModel, Generic[DataT]):
    """
    페이지네이션이 포함된 목록 응답 래퍼.

    사용 예시:
        return PaginatedResponse[KnowledgeItem](items=items, meta=meta)
    """

    success: bool = True
    items: list[DataT]
    meta: PaginationMeta
