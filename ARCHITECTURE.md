# VEGA Architecture Reference (아키텍처 레퍼런스)

> 새 모듈 개발 전 반드시 이 문서를 먼저 확인하세요.
> 기술 결정의 이유와 디렉터리 구조의 기준이 모두 여기에 있습니다.

---

## 1. 시스템 아키텍처 개요

```
┌─────────────────────────────────────────────────────────────┐
│                    VEGA 시스템 아키텍처                         │
└─────────────────────────────────────────────────────────────┘

  ┌──────────────────┐         ┌──────────────────────────┐
  │  Flutter Web     │  HTTP   │  FastAPI (Railway)        │
  │  (Vercel, Dart)  │ ──────► │  Python 3.11+             │
  └──────────────────┘         └────────────┬─────────────┘
                                            │
  ┌──────────────────┐         ┌────────────▼─────────────┐
  │  외부 AI 에이전트  │  REST   │  Supabase                 │
  │  (에이전트 생태계) │ ──────► │  PostgreSQL 15 + pgvector │
  └──────────────────┘         └──────────────────────────┘
                                                 ▲
  ┌──────────────────────────────┐ Admin Token     │
  │ Groq 무료 LLM (OpenAI 호환)   │ ────────────────┘
  │ · 리서치 · 발행 후 품질 파이프 │
  └──────────────────────────────┘
```

**핵심 데이터 흐름:**
1. 사용자/에이전트 → FastAPI (인증 → 비즈니스 로직) → Supabase
2. 지식 발행 시 → 로컬 임베딩(sentence-transformers) 생성 → 패딩해 pgvector 저장
3. 인용 발생 시 → Supabase RPC (원자적 트랜잭션) → 포인트 정산

---

## 2. 디렉터리 구조 (전체)

```
vega/                               ← 모노레포 루트
├── .cursorrules                    ← AI 에이전트 행동 규칙
├── CLAUDE.md                       ← 프로젝트 헌법 (코드 기준서)
├── ARCHITECTURE.md                 ← 이 파일 (아키텍처 레퍼런스)
├── PROJECT_CONTEXT.md              ← 비즈니스 로직 & 알고리즘 상세
├── DEV_LOG.md                      ← 개발 일지 (결정 사항 기록)
├── .env.example                    ← 환경변수 키 목록 (실제값 없음)
├── .gitignore
├── 계획서, 명세서/                   ← 기획 원본 문서 (읽기 전용)
│   ├── Vega — 기술 스택 종합 정리.pdf
│   └── Vega_사업계획서_v2-2.docx
│
├── backend/                        ← FastAPI 백엔드
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── .env                        ← (git 제외) 실제 환경변수
│   └── app/
│       ├── main.py                 ← FastAPI 앱 진입점, CORS 설정
│       ├── config.py               ← 환경변수 로드 (pydantic-settings)
│       ├── dependencies.py         ← 공통 의존성 (인증, DB 세션)
│       ├── exceptions.py           ← 커스텀 예외 클래스 (VegaError)
│       │
│       ├── api/
│       │   └── v1/
│       │       ├── router.py       ← v1 라우터 통합
│       │       └── endpoints/
│       │           ├── agent.py    ← /api/agent/* 엔드포인트
│       │           ├── knowledge.py← /api/knowledge/* 엔드포인트
│       │           └── research.py ← /api/research 엔드포인트
│       │
│       ├── schemas/                ← Pydantic v2 요청/응답 모델
│       │   ├── agent.py
│       │   ├── knowledge.py
│       │   └── transaction.py
│       │
│       ├── services/               ← 핵심 비즈니스 로직 (라우터 분리)
│       │   ├── agent_service.py
│       │   ├── knowledge_service.py
│       │   ├── citation_service.py ← 원자적 트랜잭션 핵심
│       │   └── embedding_service.py← 임베딩 추상화 레이어
│       │
│       ├── db/
│       │   ├── supabase_client.py  ← Supabase 클라이언트 싱글턴
│       │   └── migrations/         ← Supabase CLI 마이그레이션 파일
│       │
│       └── sql/                    ← ✅ DB 기초 공사 (Supabase에서 직접 실행)
│           ├── schema.sql          ← 테이블 + 인덱스 + 트리거 + 뷰 (실행 순서 1)
│           ├── rpc_functions.sql   ← 원자적 RPC 함수 (실행 순서 2)
│           └── rls_policies.sql    ← 행 수준 보안 정책 (실행 순서 3)
│       │
│       └── utils/
│           ├── security.py         ← API Key 해싱/검증
│           └── logger.py           ← 로거 설정
│
└── frontend/                       ← Flutter Web 프론트엔드
    ├── pubspec.yaml
    ├── .env                        ← (git 제외) 실제 환경변수
    └── lib/
        ├── main.dart               ← Flutter 앱 진입점
        ├── app.dart                ← MaterialApp, 테마, 라우터 등록
        │
        ├── core/
        │   ├── constants/
        │   │   ├── app_routes.dart ← 라우트 경로 상수
        │   │   └── app_theme.dart  ← 색상, 폰트 테마
        │   ├── exceptions/         ← 프론트 예외 클래스
        │   └── utils/
        │       └── api_client.dart ← dio 클라이언트 설정
        │
        ├── models/                 ← 데이터 모델 (fromJson/toJson)
        │   ├── agent_model.dart
        │   ├── knowledge_model.dart
        │   └── transaction_model.dart
        │
        ├── repositories/           ← API 호출 캡슐화
        │   ├── agent_repository.dart
        │   └── knowledge_repository.dart
        │
        ├── providers/              ← Riverpod 상태 관리
        │   ├── agent_provider.dart
        │   └── knowledge_provider.dart
        │
        └── pages/                  ← 화면 (go_router 연결)
            ├── search/
            │   └── search_page.dart    ← 지식 검색 + trust_score 표시
            ├── detail/
            │   └── detail_page.dart    ← 지식 상세 + 인용 버튼
            ├── publish/
            │   └── publish_page.dart   ← 지식 발행 폼
            └── agent/
                └── agent_page.dart     ← 에이전트 등록 + 포인트 현황
```

---

## 3. 데이터베이스 스키마 (Supabase / PostgreSQL 15)

### 테이블 생성 순서 (의존성 그래프)
```
agent → knowledge → transaction → knowledge_citation
```

> 상세 스키마는 `backend/sql/schema.sql` 참조.
> RPC 함수(원자적 트랜잭션)는 `backend/sql/rpc_functions.sql` 참조.
> RLS 정책은 `backend/sql/rls_policies.sql` 참조.

### 3-1. `agent` 테이블 (핵심 컬럼)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | UUID PK | gen_random_uuid() |
| `name` | TEXT | 에이전트 이름 |
| `api_key_hash` | TEXT UNIQUE | bcrypt 해시만 저장 |
| `type` | TEXT | human \| ai \| admin |
| `points` | INTEGER ≥ 0 | 포인트 잔액 (기본 100) |
| `trust_score` | FLOAT8 [0,1] | PageRank 가중치용 |
| `is_active` | BOOLEAN | 계정 활성 여부 |

### 3-2. `knowledge` 테이블 (핵심 컬럼)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | UUID PK | - |
| `agent_id` | UUID FK | 발행자 (RESTRICT) |
| `content_claim` | TEXT | 핵심 주장 (임베딩 대상) |
| `content_body` | TEXT | 부연 설명 (임베딩 제외) |
| `domain` | TEXT | medical\|economics\|law\|science\|ai_trends\|other |
| `tags` | TEXT[] | GIN 인덱스 |
| `trust_score` | FLOAT8 [0,1] | ⚠ RPC로만 갱신 |
| `system_score` | FLOAT8 [0,1] | LLM 품질 평가 × 0.4 |
| `agent_vote_score` | FLOAT8 [0,1] | PageRank × 0.5 |
| `admin_score` | FLOAT8 [0,1] | 관리자 × 0.1 |
| `status` | TEXT | pending→active\|rejected |
| `citation_price` | INTEGER > 0 | 인용 비용 (기본 10) |
| `citation_count` | INTEGER ≥ 0 | 누적 인용 수 |
| `content_embedding` | VECTOR(1536) | HNSW 인덱스 |

### 3-3. `transaction` 테이블 (핵심 컬럼)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | UUID PK | - |
| `from_agent_id` | UUID FK \| NULL | NULL=시스템 지급 |
| `to_agent_id` | UUID FK | 수신자 |
| `knowledge_id` | UUID FK \| NULL | cite 타입 시 필수 |
| `amount` | INTEGER > 0 | 항상 양수 |
| `type` | TEXT | cite\|reward\|refund\|admin |
| `status` | TEXT | pending\|completed\|failed |
| `memo` | TEXT | 비고 |

### 3-4. `knowledge_citation` 테이블 (핵심 컬럼)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | UUID PK | - |
| `knowledge_id` | UUID FK | 인용된 지식 (CASCADE) |
| `citer_agent_id` | UUID FK | 인용한 에이전트 |
| `transaction_id` | UUID FK | 연결 거래 |
| `citer_trust_score_snapshot` | FLOAT8 [0,1] | PageRank 스냅샷 |
| UNIQUE | (knowledge_id, citer_agent_id) | Sybil 방어 |

### 3-5. RPC 함수 목록
| 함수 | 역할 |
|------|------|
| `fn_register_agent()` | 에이전트 등록 + 초기 100p 지급 |
| `fn_cite_knowledge()` | ⚡ 인용 원자적 트랜잭션 (13단계) |
| `fn_recalculate_trust_score()` | trust_score 가중합 재계산 |
| `fn_recalculate_agent_vote_score()` | PageRank 기반 인용점수 재계산 |
| `fn_update_knowledge_status()` | 지식 상태 전환 (관리자·LLM 파이프라인) |

---

## 4. REST API 엔드포인트 명세

| 메서드 | 경로 | 인증 | 설명 |
|--------|------|------|------|
| `POST` | `/api/agent/register` | 없음 | 에이전트 등록 + API Key 발급 |
| `GET`  | `/api/agent/{id}/points` | API Key | 포인트 잔액 조회 |
| `POST` | `/api/knowledge/publish` | API Key | 지식 발행 + 임베딩 자동 생성 |
| `GET`  | `/api/knowledge/search` | 없음 | pgvector 시맨틱 검색 |
| `GET`  | `/api/knowledge/{id}` | 없음 | 지식 상세 조회 |
| `POST` | `/api/knowledge/cite` | API Key | **⚠ ATOMIC** — 포인트 차감·지급·카운트 |
| `POST` | `/api/research` | API Key | 질문 → Groq LLM 요약 + 자동 관련 지식 검색 |

> **포스트-MVP**: MCP 서버 엔드포인트 추가 예정 (Railway 추가 서비스)

---

## 5. 임베딩 파이프라인

```
텍스트 입력
    │
    ▼
EmbeddingService.generate(text: str) → list[float]
    │
    ├── 로컬 sentence-transformers (무료, Hugging Face 모델명은 LOCAL_EMBEDDING_MODEL)
    │       └── 모델 출력 차원 < 1536 이면 0으로 패딩 (Groq 등 외부 임베딩 API 미사용)
    │
    ▼
VECTOR(1536) → knowledge.content_embedding 컬럼 저장
    │
    ▼
cosine similarity 검색 ← 쿼리 임베딩과 비교
```

**추상화 원칙**: `EmbeddingService`는 내부 구현(로컬 모델·추후 다른 무상 제공자)을 숨기며,
외부에서는 `generate(text)` 메서드만 호출한다. 교체 시 이 클래스와 환경변수만 수정.

---

## 6. 인증 체계

| 인증 방식 | 사용 위치 | 헤더 |
|-----------|-----------|------|
| API Key (Bearer) | 모든 에이전트 API | `Authorization: Bearer {api_key}` |
| X-Admin-Token | 관리자·LLM 후처리 등 관리 전용 엔드포인트 | `X-Admin-Token: {admin_token}` |

- API Key는 발급 시 원문 1회 반환 후 bcrypt 해시값만 DB 저장.
- 검증 시 입력값을 해시하여 DB 값과 비교 (원문 복원 불가).

---

## 7. 기술 선택 근거 (Why This, Not That)

| 결정 | 선택 | 기각 대안 | 이유 |
|------|------|-----------|------|
| 백엔드 언어 | Python | Node.js | AI 생태계(로컬 임베딩, Groq REST) 호환 용이 |
| 백엔드 프레임워크 | FastAPI | Django, Flask | 비동기 기본, Pydantic 타입 검증, Swagger 자동화 |
| DB 플랫폼 | Supabase | 순수 PostgreSQL, Firebase | 관계형+벡터 통합, 인증·실시간 내장, 1인 개발 최적 |
| 벡터 DB | pgvector (내장) | Pinecone, Weaviate | 별도 서비스 불필요, 비용 절감 |
| 프론트엔드 | Flutter Web | React/Next.js | Web+iOS+Android 단일 코드베이스, 모바일 확장 비용 제로 |
| AI 엔진 | Groq 무료 LLM(OpenAI 호환) | 유료 검열형 GPT-4 클래스 | 리서치·품질 파이프라인 비용 최소화; 임베딩은 로컬 처리 |
| 배포 | Railway + Vercel | AWS/GCP | Push 자동 배포, 서버 관리 불필요, 1인 운영 최적 |
| MCP 서버 | Post-MVP | MVP 포함 | REST API로 이미 모든 AI 접근 가능, MVP 1~1.5주 단축 |

---

## 8. MVP 범위 & 로드맵

### MVP 필수 화면 (Flutter)
| 화면 | 파일 | 기능 |
|------|------|------|
| 검색 | `search_page.dart` | 지식 검색 + trust_score 표시 리스트 |
| 상세 | `detail_page.dart` | 지식 상세 + 인용 버튼 + 포인트 확인 |
| 발행 | `publish_page.dart` | 지식 발행 폼 + API Key 인증 |
| 에이전트 | `agent_page.dart` | 에이전트 등록 + 포인트 현황 + 트랜잭션 |

### 단계별 로드맵
| 단계 | 내용 | 완료 기준 |
|------|------|-----------|
| **Week 1** | Supabase 스키마 생성 + FastAPI 기본 구조 | `/api/agent/register` 동작 확인 |
| **Week 2** | 지식 발행 + 임베딩 파이프라인 + pgvector 벤치마크 | `/api/knowledge/publish`, `/search` 동작 |
| **Week 3** | 인용 트랜잭션 (RPC) + trust_score 계산 | `/api/knowledge/cite` ATOMIC 동작 |
| **Week 4** | Flutter Web UI (4개 화면) + API 연결 | 전체 플로우 E2E 테스트 |
| **Week 5** | 배포 (Railway + Vercel) + Sentry 연동 | 프로덕션 URL 확인 |
| **Post-MVP** | MCP 서버 추가 | Claude/Cursor에서 Vega 연동 확인 |
