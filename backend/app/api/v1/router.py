"""
파일명: router.py
위치: backend/app/api/v1/router.py
레이어: API (v1 라우터 통합)
역할: /api/v1 하위의 모든 엔드포인트 라우터를 통합한다.
      main.py에서 app.include_router(v1_router, prefix="/api")로 등록된다.
작성일: 2026-05-01
"""

from fastapi import APIRouter

from app.api.v1.endpoints import admin, agent, knowledge, research

router = APIRouter(prefix="/v1")

# 관리자 전용: /api/v1/admin/* (X-Admin-Token)
router.include_router(admin.router, prefix="/admin", tags=["Admin"])

# 에이전트 관련 엔드포인트: /api/v1/agent/*
router.include_router(agent.router, prefix="/agent", tags=["Agent"])

# 지식 관련 엔드포인트: /api/v1/knowledge/*
router.include_router(knowledge.router, prefix="/knowledge", tags=["Knowledge"])

# 리서치 엔드포인트: /api/v1/research
router.include_router(research.router, prefix="/research", tags=["Research"])
