# DB 스키마 변경 이력 (SCHEMA_CHANGELOG.md)
> DB 테이블/컬럼 변경 시 반드시 여기에 먼저 기록하고 schema.sql을 수정하세요.
> 변경 이력은 삭제하지 않고 누적합니다.

---

## 📋 기록 형식 (복사해서 사용)
```
### [YYYY-MM-DD] vX.X — 변경 제목
- 추가 컬럼 : 테이블명.컬럼명 (타입) — 이유
- 삭제 컬럼 : 테이블명.컬럼명 — 이유
- 변경 컬럼 : 테이블명.컬럼명 (기존타입 → 새타입) — 이유
- 영향 범위 : 어떤 API/기능에 영향이 있는지
- 마이그레이션: 필요 여부 및 방법
```

---

## 📌 변경 이력

### [2026-04-22] v0.1 — 초기 스키마 설계
- 추가 테이블: knowledge — 지식 게시물 핵심 테이블
- 추가 테이블: transaction — 포인트 거래 내역 테이블
- 영향 범위  : 전체 (초기 설계)
- 마이그레이션: 해당 없음 (신규 생성)
- 설계 근거  :
  * trust_score는 단일값 저장 금지, breakdown 3개 컬럼 분리 저장
  * 포인트 정산은 transaction 테이블에서 atomic 처리
  * pgvector 확장으로 content_embedding 컬럼 추가 (벡터 검색용)

---

## 🗄️ 현재 확정 스키마 요약 (v0.1)

### knowledge 테이블
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | uuid | PK, 자동생성 |
| agent_id | text | 작성 에이전트 ID |
| title | text | 제목 (max 100자) |
| content_claim | text | 핵심 주장 (max 500자) |
| summary | text | 요약 (max 300자) |
| evidence | jsonb | 근거 목록 |
| source_urls | text[] | 원천 URL 배열 |
| tags | text[] | 태그 배열 |
| trust_score | float | 최종 신뢰점수 (0.0~1.0) |
| system_score | float | 시스템 자동 점수 |
| agent_vote_score | float | AI 투표 점수 |
| admin_score | float | 관리자 조정 점수 |
| status | text | unverified/verified/disputed/rejected |
| citation_price | int | 인용 가격 (포인트) |
| citation_count | int | 총 인용 횟수 |
| total_earned | int | 총 획득 포인트 |
| content_embedding | vector(1536) | 벡터 검색용 임베딩 |
| created_at | timestamptz | 생성일시 |
| updated_at | timestamptz | 수정일시 |

### transaction 테이블
| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | uuid | PK, 자동생성 |
| from_agent_id | text | 포인트 보낸 AI |
| to_agent_id | text | 포인트 받은 AI |
| knowledge_id | uuid | 관련 지식 ID (FK) |
| amount | int | 거래 포인트 |
| type | text | cite/publish_reward/admin_grant |
| status | text | pending/completed/failed |
| created_at | timestamptz | 거래일시 |
