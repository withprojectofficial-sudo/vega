"""
Week 2: knowledge 데이터 정리 + HTTP API 검증.

- knowledge 및 연관 citation / knowledge_id가 있는 transaction 행만 삭제 (agent·초기 지급 거래 유지)
- PostgREST(httpx)만 사용 (supabase-py 미사용)

사전 조건:
  1) Supabase SQL Editor에서 sql/patches/week2_integrity_20260501.sql 적용
  2) backend/.env 에 SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY 설정
  3) uvicorn 실행 중 (기본 http://127.0.0.1:8000)

실행 (backend 디렉터리):
  py -3 -m pip install httpx python-dotenv
  py -3 scripts/week2_integration_verify.py
"""

from __future__ import annotations

import os
import sys
import uuid
from pathlib import Path

import httpx
from dotenv import load_dotenv

_BACKEND_ROOT = Path(__file__).resolve().parent.parent
os.chdir(_BACKEND_ROOT)
load_dotenv(_BACKEND_ROOT / ".env")

NIL_UUID = "00000000-0000-0000-0000-000000000000"
API_BASE = os.environ.get("VEGA_API_BASE", "http://127.0.0.1:8000/api/v1")


def _rest_headers(service_key: str) -> dict[str, str]:
    return {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    }


def truncate_knowledge_data_http(supabase_url: str, service_key: str) -> None:
    """PostgREST로 knowledge 및 FK 선행 삭제."""
    base = supabase_url.rstrip("/") + "/rest/v1"
    h = _rest_headers(service_key)
    with httpx.Client(timeout=120.0) as client:
        r1 = client.delete(
            f"{base}/knowledge_citation",
            params={"id": f"neq.{NIL_UUID}"},
            headers=h,
        )
        r1.raise_for_status()

        r2 = client.delete(
            f"{base}/transaction",
            params={"knowledge_id": "not.is.null"},
            headers=h,
        )
        r2.raise_for_status()

        r3 = client.delete(
            f"{base}/knowledge",
            params={"id": f"neq.{NIL_UUID}"},
            headers=h,
        )
        r3.raise_for_status()
    print("[OK] knowledge 및 연관 citation / 지식 연계 거래 삭제 완료")


def main() -> None:
    url = os.environ.get("SUPABASE_URL", "").strip()
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not url or not key:
        print("[FAIL] SUPABASE_URL 또는 SUPABASE_SERVICE_ROLE_KEY가 .env에 없습니다.")
        raise SystemExit(1)

    truncate_knowledge_data_http(url, key)

    with httpx.Client(timeout=180.0) as client:
        reg = client.post(
            f"{API_BASE}/agent/register",
            json={
                "name": f"Week2 검증 {uuid.uuid4().hex[:8]}",
                "type": "ai",
                "bio": "통합 검증용",
            },
        )
        reg.raise_for_status()
        reg_j = reg.json()
        if reg_j.get("success") is False:
            print(reg_j)
            raise SystemExit(1)
        data = reg_j["data"]
        api_key = data["api_key"]
        print("[OK] 에이전트 등록 완료")

        claim = (
            "Vega는 수석 소프트웨어 아키텍트와 비즈니스 전략가의 관점을 결합한 "
            "AI 지능형 에이전트 플랫폼이다."
        )
        pub = client.post(
            f"{API_BASE}/knowledge/publish",
            headers={"Authorization": f"Bearer {api_key}"},
            json={
                "title": "Vega 플랫폼 정체성 (Week2 검증)",
                "content_claim": claim,
                "domain": "business_strategy",
                "tags": ["vega", "week2"],
            },
        )
        pub.raise_for_status()
        pub_j = pub.json()
        if pub_j.get("success") is False:
            print(pub_j)
            raise SystemExit(1)
        kid = pub_j["data"]["knowledge_id"]
        print(f"[OK] 지식 발행 완료 knowledge_id={kid}")

        q = "Vega 플랫폼의 정체성은 뭐야?"
        search = client.get(
            f"{API_BASE}/knowledge/search",
            params={"query": q, "threshold": 0.5, "limit": 10},
        )
        search.raise_for_status()
        sj = search.json()
        items = sj.get("items", [])
        hit = next((it for it in items if it.get("id") == kid), None)
        if hit is None:
            print("[FAIL] 검색 결과에 방금 발행한 지식이 없습니다.")
            print("       Supabase에 sql/patches/week2_integrity_20260501.sql 적용 여부를 확인하세요.")
            raise SystemExit(2)
        sim = float(hit.get("similarity_score") or 0.0)
        print(f"[OK] 검색 히트 similarity={sim:.4f}")
        if sim < 0.7:
            print(
                f"[WARN] 유사도가 0.7 미만 ({sim}). "
                "embedding_service: 1536 패딩 후 L2 정규화, "
                "E5 모델은 query:/passage: 접두사(config) 확인."
            )
            raise SystemExit(3)
        print("[OK] 유사도 0.7 이상 충족")


if __name__ == "__main__":
    main()
