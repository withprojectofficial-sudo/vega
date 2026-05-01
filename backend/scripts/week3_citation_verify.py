"""
Week 3: 인용(cite) RPC·API 무결성 검증.

시나리오:
  1) 발행자·인용자(consumer) 에이전트 등록
  2) 인용자 포인트 충전 (service_role PostgREST PATCH)
  3) 발행자가 지식 발행 (pending)
  4) POST /admin/knowledge/review 로 active 전환 (X-Admin-Token)
  5) 인용 전후 GET /agent/{id}/points 로 잔액 확인
  6) POST /knowledge/cite 로 인용
  7) 동일 지식 재인용 시 VEGA_010 (409) 확인 — 1인용 1차감, 중복 시 추가 차감 없음

사전 조건:
  - backend/.env (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, ADMIN_SECRET_TOKEN)
  - Supabase에 fn_cite_knowledge 가 최신본일 것 (p_consumer_agent_id 인수명)
  - uvicorn 기동: http://127.0.0.1:8000

실행 (backend 디렉터리):
  py -3.11 scripts\\week3_citation_verify.py
"""

from __future__ import annotations

import os
import uuid
from pathlib import Path

import httpx
from dotenv import load_dotenv

_BACKEND_ROOT = Path(__file__).resolve().parent.parent
os.chdir(_BACKEND_ROOT)
load_dotenv(_BACKEND_ROOT / ".env")

API_BASE = os.environ.get("VEGA_API_BASE", "http://127.0.0.1:8000/api/v1")
CHARGE_POINTS = 500


def _rest_headers(service_key: str) -> dict[str, str]:
    return {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json",
    }


def charge_agent_points(
    supabase_url: str,
    service_key: str,
    agent_id: str,
    new_balance: int,
) -> None:
    """service_role로 agent.points 갱신 (로컬 검증용)."""
    base = supabase_url.rstrip("/") + "/rest/v1"
    h = _rest_headers(service_key)
    h["Prefer"] = "return=minimal"
    with httpx.Client(timeout=60.0) as client:
        r = client.patch(
            f"{base}/agent",
            params={"id": f"eq.{agent_id}"},
            headers=h,
            json={"points": new_balance},
        )
        r.raise_for_status()
    print(f"[OK] 인용자 포인트 충전: agent_id={agent_id} -> {new_balance}p")


def activate_knowledge_via_admin_api(
    client: httpx.Client,
    knowledge_id: str,
    admin_token: str,
) -> None:
    """관리자 HTTP API로 pending → active 전환 (로컬 검증용)."""
    r = client.post(
        f"{API_BASE}/admin/knowledge/review",
        headers={
            "X-Admin-Token": admin_token,
            "Content-Type": "application/json",
        },
        json={
            "knowledge_id": knowledge_id,
            "new_status": "active",
            "new_system_score": 0.5,
        },
    )
    r.raise_for_status()
    body = r.json()
    if body.get("success") is False:
        raise RuntimeError(body)
    print(f"[OK] 지식 active 전환(API): knowledge_id={knowledge_id}")


def fetch_points(client: httpx.Client, agent_id: str, api_key: str) -> int:
    r = client.get(
        f"{API_BASE}/agent/{agent_id}/points",
        headers={"Authorization": f"Bearer {api_key}"},
    )
    r.raise_for_status()
    body = r.json()
    if body.get("success") is False:
        raise RuntimeError(body)
    return int(body["data"]["points"])


def main() -> None:
    supabase_url = os.environ.get("SUPABASE_URL", "").strip()
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not supabase_url or not service_key:
        print("[FAIL] SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 가 .env 에 없습니다.")
        raise SystemExit(1)

    admin_token = os.environ.get("ADMIN_SECRET_TOKEN", "").strip()
    if not admin_token:
        print("[FAIL] ADMIN_SECRET_TOKEN 이 .env 에 없습니다. 관리자 승인 API 호출에 필요합니다.")
        raise SystemExit(1)

    tag = uuid.uuid4().hex[:6]
    with httpx.Client(timeout=180.0) as client:
        pub_reg = client.post(
            f"{API_BASE}/agent/register",
            json={
                "name": f"Wk3발행자_{tag}",
                "type": "human",
                "bio": "week3",
            },
        )
        pub_reg.raise_for_status()
        pub_j = pub_reg.json()
        if pub_j.get("success") is False:
            raise RuntimeError(pub_j)
        pub_id = str(pub_j["data"]["agent_id"])
        pub_key = str(pub_j["data"]["api_key"])
        print(f"[OK] 발행자 등록 agent_id={pub_id}")

        con_reg = client.post(
            f"{API_BASE}/agent/register",
            json={
                "name": f"Wk3인용자_{tag}",
                "type": "ai",
                "bio": "week3_consumer",
            },
        )
        con_reg.raise_for_status()
        con_j = con_reg.json()
        if con_j.get("success") is False:
            raise RuntimeError(con_j)
        con_id = str(con_j["data"]["agent_id"])
        con_key = str(con_j["data"]["api_key"])
        print(f"[OK] 인용자(consumer) 등록 agent_id={con_id}")

        before_consumer = fetch_points(client, con_id, con_key)
        charge_agent_points(supabase_url, service_key, con_id, before_consumer + CHARGE_POINTS)
        after_charge = fetch_points(client, con_id, con_key)
        print(f"[OK] 인용자 잔액: 충전 후 {after_charge}p (기대: {before_consumer + CHARGE_POINTS})")

        pub = client.post(
            f"{API_BASE}/knowledge/publish",
            headers={"Authorization": f"Bearer {pub_key}"},
            json={
                "title": f"Week3 인용 검증 지식 {tag}",
                "content_claim": "Vega 인용 RPC는 단일 트랜잭션으로 포인트와 인용 이력을 처리한다.",
                "domain": "other",
                "tags": ["week3"],
                "citation_price": 10,
            },
        )
        pub.raise_for_status()
        pk_j = pub.json()
        if pk_j.get("success") is False:
            raise RuntimeError(pk_j)
        kid = str(pk_j["data"]["knowledge_id"])
        print(f"[OK] 지식 발행 knowledge_id={kid} (pending)")

        activate_knowledge_via_admin_api(client, kid, admin_token)

        pub_pts_before = fetch_points(client, pub_id, pub_key)
        con_pts_before = fetch_points(client, con_id, con_key)
        print(f"[인용 직전] 발행자 {pub_pts_before}p, 인용자 {con_pts_before}p")

        cite = client.post(
            f"{API_BASE}/knowledge/cite",
            headers={"Authorization": f"Bearer {con_key}"},
            json={"knowledge_id": kid},
        )
        cite.raise_for_status()
        cj = cite.json()
        if cj.get("success") is False:
            raise RuntimeError(cj)
        data = cj["data"]
        print(
            "[OK] 인용 성공 "
            f"transaction_id={data['transaction_id']} "
            f"citer_remaining={data['citer_remaining_points']}p "
            f"publisher_earned={data['publisher_earned_points']}p"
        )

        pub_pts_after = fetch_points(client, pub_id, pub_key)
        con_pts_after = fetch_points(client, con_id, con_key)
        print(f"[인용 직후] 발행자 {pub_pts_after}p, 인용자 {con_pts_after}p")

        expected_pub = pub_pts_before + 10
        expected_con = con_pts_before - 10
        if pub_pts_after != expected_pub or con_pts_after != expected_con:
            print(
                f"[FAIL] 포인트 불일치. 기대 발행자 {expected_pub}, 인용자 {expected_con} "
                f"/ 실제 발행자 {pub_pts_after}, 인용자 {con_pts_after}"
            )
            raise SystemExit(2)

        cite2 = client.post(
            f"{API_BASE}/knowledge/cite",
            headers={"Authorization": f"Bearer {con_key}"},
            json={"knowledge_id": kid},
        )
        if cite2.status_code != 409:
            print(f"[FAIL] 중복 인용은 409 예상, 실제 {cite2.status_code} body={cite2.text[:400]}")
            raise SystemExit(3)
        err = cite2.json()
        if err.get("error_code") != "VEGA_010":
            print(f"[FAIL] 중복 인용 에러코드 기대 VEGA_010, 실제 {err}")
            raise SystemExit(4)
        print("[OK] 동일 지식 재인용 거부 VEGA_010 (추가 포인트 차감 없음)")

    print("\nWeek3 인용 검증 통과.")


if __name__ == "__main__":
    main()
