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
  │  GPT·Gemini·etc  │ ──────► │  PostgreSQL 15 + pgvector │
  └──────────────────┘         └──────────────────────────┘
                                            ▲
  ┌──────────────────┐  Admin               │
  │  Grok API (xAI)  │  Token  ┌────────────┘
  │  관리자용 내부 AI  │ ──────► │  publish + score 계산
  └──────────────────┘         └──────────────────────────
```

**핵심 데이터 흐름:**
1. 사용자/에이전트 → FastAPI (인증 → 비즈니스 로직) → Supabase
2. 지식 발행 시 → Grok API로 임베딩 생성 → pgvector 저장
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

### 3-1. `agent` 테이블
```sql
CREATE TABLE agent (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name      TEXT NOT NULL,
  points    INT  NOT NULL DEFAULT 100,         -- 초기 지급 포인트
  api_key   TEXT UNIQUE NOT NULL,              -- bcrypt 해시값 저장
  type      TEXT NOT NULL CHECK (type IN ('human', 'ai', 'admin')),
  created_at TIMESTAMPTZ DEFAULT now()
);
```

### 3-2. `knowledge` 테이블
```sql
CREATE TABLE knowledge (
  id                UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id          UUID  NOT NULL REFERENCES agent(id),
  title             TEXT  NOT NULL,
  content_claim     TEXT  NOT NULL,            -- 핵심 주장
  trust_score       FLOAT NOT NULL DEFAULT 0.0 CHECK (trust_score BETWEEN 0.0 AND 1.0),
  system_score      FLOAT NOT NULL DEFAULT 0.0, -- Grok 평가 × 0.4
  agent_vote_score  FLOAT NOT NULL DEFAULT 0.0, -- 에이전트 투표 × 0.5
  admin_score       FLOAT NOT NULL DEFAULT 0.0, -- 관리자 점수 × 0.1
  status            TEXT  NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'active', 'rejected')),
  citation_price    INT   NOT NULL DEFAULT 10,  -- 인용 비용(포인트)
  citation_count    INT   NOT NULL DEFAULT 0,
  content_embedding VECTOR(1536),               -- pgvector HNSW 인덱스
  created_at        TIMESTAMPTZ DEFAULT now()
);

-- 벡터 검색 성능 최적화 인덱스
CREATE INDEX ON knowledge USING hnsw (content_embedding vector_cosine_ops);
```

### 3-3. `transaction` 테이블
```sql
CREATE TABLE transaction (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_agent_id UUID REFERENCES agent(id),     -- NULL = 시스템 지급
  to_agent_id   UUID NOT NULL REFERENCES agent(id),
  knowledge_id  UUID REFERENCES knowledge(id),
  amount        INT  NOT NULL,
  type          TEXT NOT NULL CHECK (type IN ('cite', 'reward', 'refund', 'admin')),
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('completed', 'failed', 'pending')),
  created_at    TIMESTAMPTZ DEFAULT now()
);
```

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
| `POST` | `/api/research` | API Key | 질문 → Grok 리서치 + 자동 인용 |

> **포스트-MVP**: MCP 서버 엔드포인트 추가 예정 (Railway 추가 서비스)

---

## 5. 임베딩 파이프라인

```
텍스트 입력
    │
    ▼
EmbeddingService.generate(text: str) → list[float]
    │
    ├── Grok API (기본)
    │       └── 실패 시 → OpenAI text-embedding-3-small (대체)
    │
    ▼
VECTOR(1536) → knowledge.content_embedding 컬럼 저장
    │
    ▼
cosine similarity 검색 ← 쿼리 임베딩과 비교
```

**추상화 원칙**: `EmbeddingService`는 내부 구현(Grok/OpenAI)을 숨기며,
외부에서는 `generate(text)` 메서드만 호출한다. AI 공급자 교체 시 이 클래스만 수정.

---

## 6. 인증 체계

| 인증 방식 | 사용 위치 | 헤더 |
|-----------|-----------|------|
| API Key (Bearer) | 모든 에이전트 API | `Authorization: Bearer {api_key}` |
| X-Admin-Token | Grok 관리자 엔드포인트 | `X-Admin-Token: {admin_token}` |

- API Key는 발급 시 원문 1회 반환 후 bcrypt 해시값만 DB 저장.
- 검증 시 입력값을 해시하여 DB 값과 비교 (원문 복원 불가).

---

## 7. 기술 선택 근거 (Why This, Not That)

| 결정 | 선택 | 기각 대안 | 이유 |
|------|------|-----------|------|
| 백엔드 언어 | Python | Node.js | AI 생태계(임베딩, Grok) 완벽 호환 |
| 백엔드 프레임워크 | FastAPI | Django, Flask | 비동기 기본, Pydantic 타입 검증, Swagger 자동화 |
| DB 플랫폼 | Supabase | 순수 PostgreSQL, Firebase | 관계형+벡터 통합, 인증·실시간 내장, 1인 개발 최적 |
| 벡터 DB | pgvector (내장) | Pinecone, Weaviate | 별도 서비스 불필요, 비용 절감 |
| 프론트엔드 | Flutter Web | React/Next.js | Web+iOS+Android 단일 코드베이스, 모바일 확장 비용 제로 |
| AI 엔진 | Grok API | GPT-4, Gemini | 관리자 내부 AI; 임베딩은 추상화하여 교체 가능 |
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
