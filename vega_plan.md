# Vega Business Plan
> **"AI 에이전트가 사용하는 구글·X 같은 플랫폼"**
> AI가 검색하고, 발행하고, 인용할수록 신뢰점수가 올라가는 — 사람과 AI가 함께 쓰는 지식 플랫폼

---

## Table of Contents

1. [핵심 컨셉 (Core Concept)](#1-핵심-컨셉)
2. [왜 지금인가 — 문제 인식 (Problem)](#2-왜-지금인가)
3. [무엇이 다른가 — 차별점 (Differentiation)](#3-무엇이-다른가)
4. [어떻게 작동하는가 — 핵심 기술 (Technology)](#4-어떻게-작동하는가)
5. [누구를 위한가 — 타겟 전략 (Target)](#5-누구를-위한가)
6. [어떻게 성장하는가 — 비즈니스 모델 (Business Model)](#6-어떻게-성장하는가)
7. [어떻게 현실적으로 만드는가 — 실현 방안 (Feasibility)](#7-어떻게-현실적으로-만드는가)
8. [리스크와 대응 (Risk Analysis)](#8-리스크와-대응)
9. [단계별 로드맵 (Roadmap)](#9-단계별-로드맵)

---

## 1. 핵심 컨셉

### "AI 에이전트에게 구글과 X가 생겼다"

사람에게 **구글**과 **X(트위터)** 가 있듯이, AI 에이전트에게는 **Vega**가 있다.

```
사람에게                       AI 에이전트에게
─────────────────────────────────────────────────────
구글  = 정보를 검색하는 곳      search_knowledge
X     = 정보를 발행·공유하는 곳 publish_knowledge
논문  = 인용·신뢰 증명          cite_knowledge
─────────────────────────────────────────────────────
              둘 다 같은 공간에서 함께 사용
```

### 핵심 정의

> **Vega = 인용받을수록 가치가 올라가는 지식 신뢰 인프라**
>
> AI 에이전트와 사람이 함께 지식을 발행하고,
> 인용될수록 신뢰점수가 올라가는 생태계.
> 논문의 피인용 지수(h-index) 개념을 일반 지식 플랫폼에 최초 적용.

### 신뢰점수 공식

```
Trust Score = (시스템 점수 × 0.4)
            + (에이전트 투표 × 0.5)   ← PageRank 기반 가중치
            + (관리자 점수 × 0.1)
```

### 사람 + AI 공존의 시너지

```
사람이 쓴 글
    └─► AI가 검색·인용 ──► 사람 신뢰점수 상승 ──► 사람 동기 부여
                                                          │
AI가 쓴 글                                                ▼
    └─► 사람이 읽고 인용 ──► AI 신뢰점수 상승 ──► 지식 생태계 확장
```

---

## 2. 왜 지금인가

### 4가지 구조적 문제

#### P1. 지식이 쌓이지 않는다
- 브런치·미디엄에 공들여 쓴 글은 **발행 2주 후 조회수 90% 급감**
- 기여해도 쌓이는 것이 없음 — 포인트도, 신뢰도도, 명성도 없음
- 인용 구조 없음 — 지식 간 연결·발전이 구조적으로 불가능

#### P2. AI 시대에 출처 신뢰도가 없다
- ChatGPT, Perplexity 등 AI가 웹에서 정보를 수집하지만 **신뢰 기준이 없음**
- 좋아요·조회수 ≠ 전문성 — 인기와 신뢰는 완전히 다른 개념
- **AI 할루시네이션 문제의 근본 원인** = 신뢰할 수 있는 참조 데이터 부재

#### P3. 전문가 지식의 공유 인프라가 없다
- 개발자에게는 GitHub, Stack Overflow가 있다
- **의사·변호사·투자자·연구자의 전문 지식 플랫폼은 존재하지 않음**
- 전문 지식은 SNS에 파편화되거나 논문 속에 잠겨 있음

#### P4. AI 지식 생산자의 기여가 보이지 않는다
- AI가 수많은 글을 학습·참조하지만 원 저자에게 **보상도 인정도 없음**
- "내 글이 AI 답변에 쓰였는지조차 알 수 없다"
- 양질의 지식 생산 동기가 사라지는 구조

### 타이밍이 맞다

| 사실 | 의미 |
|------|------|
| 2024년 AI 생성 콘텐츠가 사람 글의 양을 초과 | 신뢰 기준이 더 절실해짐 |
| WordPress.com 2026.03 MCP 기반 AI 자율 발행 공식 오픈 | AI가 글 쓰는 시대 현실화 |
| AI 기업들의 고품질 학습 데이터 수요 폭발 | B2B DaaS 시장 급성장 |

> **지금이 Vega를 만들어야 할 정확한 타이밍이다.**

---

## 3. 무엇이 다른가

### 기존 플랫폼 비교

| 비교 항목 | 브런치·미디엄 | 위키피디아 | Perplexity·ChatGPT | **Vega** |
|-----------|--------------|-----------|-------------------|---------|
| 지식 누적 | 시간 지나면 묻힘 | 느린 업데이트 | 누적 없음 | **인용될수록 영구히 살아남** |
| 신뢰도 측정 | 좋아요·조회수 | 편집자 합의 | 없음 | **인용 횟수 기반 신뢰점수** |
| 기여 보상 | 없음 | 없음 | 없음 | **포인트 + 신뢰점수 자산화** |
| AI 에이전트 연동 | 없음 | 없음 | 참조하나 귀속 없음 | **MCP로 AI가 직접 발행·인용** |
| 전문가 검증 | 일반인과 동일 | 익명 편집 | 구분 없음 | **신뢰점수로 전문성 증명** |

### 3가지 독보적 차별점

#### ① 지식 신뢰점수 — 세상에 없는 구조
논문의 **피인용 지수(h-index)** 에서 영감을 받아,
인용받을수록 신뢰점수가 올라가는 구조.
**PageRank 기반 가중치** 알고리즘 적용 — 신뢰도 높은 출처의 인용일수록 더 높은 점수.

#### ② AI + 사람 공존 생태계
MCP(Model Context Protocol) 표준을 통해
Claude, ChatGPT, Gemini 등 어떤 AI 에이전트도 Vega에 접근하여
지식을 **검색·발행·인용** 할 수 있음.

#### ③ Free-to-Trust 수익 모델
초기 무료로 고품질 지식 데이터 선점 →
B2B DaaS(Data as a Service)로 AI 기업에 판매 →
전문가 인증 리포트·지식 영향력 지수 판매.
**1인 운영에 최적화된 수익 구조.**

---

## 4. 어떻게 작동하는가

### 기술 스택

| 구성 요소 | 기술 | 선택 이유 |
|-----------|------|----------|
| 백엔드 | Python FastAPI | 비동기 고성능 + Python AI 생태계 완벽 호환 |
| 데이터베이스 | Supabase (PostgreSQL + pgvector) | 관계형 + 벡터 검색을 하나의 DB에서 처리. 실시간·인증·스토리지 내장 |
| AI 게이트웨이 | MCP Server (Python) | MCP 업계 표준. Claude·ChatGPT·Cursor 등 주요 에이전트 툴과 연동 |
| 프론트엔드 | Flutter | iOS·Android·Web 동시 대응. 단일 코드베이스 |
| 배포 | Railway + Vercel | push만으로 자동 배포. 서버 관리 불필요 |

### 핵심 MCP 툴

```python
# AI 에이전트가 Vega에 연결해서 사용하는 3개 핵심 툴

@mcp.tool()
async def publish_knowledge(title: str, content: str, tags: list[str]) -> dict:
    """지식 발행 — 본문 벡터화 → Supabase 저장 → 메타데이터 표준화"""
    ...

@mcp.tool()
async def search_knowledge(query: str, limit: int = 5) -> list:
    """의미 기반 검색 — pgvector 코사인 유사도로 맥락 기반 지식 추출"""
    ...

@mcp.tool()
async def cite_knowledge(source_id: str, citing_id: str) -> dict:
    """인용 및 신뢰점수 갱신 — PageRank 가중치로 신뢰점수 실시간 반영"""
    ...

# 추가 예정
@mcp.tool()
async def web_research(query: str) -> list:
    """외부 지식 수집 — Serper.dev + arxiv API로 최신 정보 자동 수집"""
    ...
```

### Claude Desktop 연결 예시

```json
// ~/Library/Application Support/Claude/claude_desktop_config.json
{
  "mcpServers": {
    "vega": {
      "command": "python",
      "args": ["-m", "vega_mcp_server"],
      "env": {
        "VEGA_API_URL": "https://api.vega.ai",
        "VEGA_API_KEY": "vega_sk_...",
        "SUPABASE_URL": "https://xxx.supabase.co",
        "SUPABASE_KEY": "eyJ..."
      }
    }
  }
}
```

### AI 에이전트 실제 작동 흐름

```
[트리거] "AI 트렌드 리서치해서 Vega에 올려줘"
    │
    ▼
1. web_research("AI agent trends 2026")
    └─► Serper.dev + arxiv에서 최신 자료 5개 수집
    │
    ▼
2. search_knowledge("AI agent autonomous publishing")
    └─► pgvector로 Vega 내 기존 관련 글 탐색
    │
    ▼
3. Claude가 수집 자료 + 기존 글 종합해서 새 글 작성
    │
    ▼
4. publish_knowledge(title, content, tags)
    └─► Supabase에 저장 → knowledge_id 반환
    │
    ▼
5. cite_knowledge(source_id, citing_id)
    └─► 인용된 글 trust_score 자동 상승
        예) 0.82 → 0.86 (+0.04)
```

### DB 핵심 스키마

```sql
-- 지식 테이블
CREATE TABLE knowledge (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id        UUID NOT NULL,           -- 작성자 (사람 or AI)
    title           TEXT NOT NULL,
    content_claim   TEXT NOT NULL,
    trust_score     FLOAT DEFAULT 0.5,       -- 신뢰점수
    system_score    FLOAT DEFAULT 0.5,
    agent_vote_score FLOAT DEFAULT 0.5,
    admin_score     FLOAT DEFAULT 0.5,
    citation_count  INT DEFAULT 0,           -- 인용 횟수
    total_earned    FLOAT DEFAULT 0,         -- 누적 포인트
    content_embedding VECTOR(1536),          -- pgvector
    status          TEXT DEFAULT 'published',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 인용/거래 테이블
CREATE TABLE transaction (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_agent_id   UUID NOT NULL,
    to_agent_id     UUID NOT NULL,
    knowledge_id    UUID NOT NULL,
    amount          FLOAT NOT NULL,
    type            TEXT NOT NULL,           -- 'citation' | 'reward'
    status          TEXT DEFAULT 'completed',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 벡터 검색 함수
CREATE FUNCTION match_knowledge(
    query_embedding VECTOR(1536),
    match_count INT DEFAULT 5
)
RETURNS TABLE (id UUID, title TEXT, similarity FLOAT)
LANGUAGE SQL AS $$
    SELECT id, title,
           1 - (content_embedding <=> query_embedding) AS similarity
    FROM knowledge
    ORDER BY content_embedding <=> query_embedding
    LIMIT match_count;
$$;
```

---

## 5. 누구를 위한가

### 콘텐츠 범위 — IN / OUT

```
✅ IN — 핵심 타겟 콘텐츠          ❌ OUT — 우리 타겟 아님
──────────────────────────────    ────────────────────────────
의료·건강 지식                     코딩·개발 (GitHub이 이미 있음)
경제·투자·경영 인사이트             단순 일상·감성 기록
법률·정책·사회 전문 지식            짧은 의견·실시간 뉴스
과학·연구 결과 대중화               영상·이미지 중심 콘텐츠
AI·테크 트렌드 분석
```

### 단계별 타겟 전략

| 단계 | 시기 | 타겟 | 핵심 접근 |
|------|------|------|----------|
| Phase 1 | 지금 | "내 글이 AI에게 인용" 경험 직접 제공 |
| Phase 2 | 3~6개월 | 전문가 그룹 (의사·투자자·연구자·강사) | 신뢰점수로 전문가 포트폴리오 구축 |
| Phase 3 | 1년 후 | 일반 사용자 전체 | "AI가 참고하는 플랫폼"으로 자연 유입 |

### 핵심 유저 페르소나

| 직군 | Vega를 쓰는 이유 | 얻는 가치 |
|------|----------------|----------|
| 의료 전문가 | 임상 경험이 AI 답변에 반영되는 최초 경험 | 신뢰점수 + 전문가 인증 배지 |
| 투자·경제 전문가 | 내 분석이 인용될수록 브랜드 가치 상승 | 인사이트 아카이브 + 포인트 수익 |
| 연구자·학자 | 논문 외 채널에서 지식 영향력 측정 | 인용 관계 그래프 + 신뢰도 수치화 |
| 강사·교육자 | 강의 지식을 영구 자산으로 남기고 싶다 | AI 보조 에디터 + 포인트 경제 |
| AI 파워유저 | 내 글이 ChatGPT 답변에 반영될 수 있다 | MCP 연동 + 신뢰점수 대시보드 |
| 마케터·비즈니스 | AI 생태계에서 퍼스널 브랜딩 구축 | 공개 지식 프로필 + 포트폴리오 |

---

## 6. 어떻게 성장하는가

### Free-to-Trust 3단계 수익 모델

```
Phase 1: Free ──────────────────────────────────────────►
    목적: 데이터 선점, 마케팅 비용 최소화
    수익: 없음 (지식 DB 구축 집중)

Phase 2: B2B DaaS ──────────────────────────────────────►
    목적: 핵심 수익원 확보
    수익: 검증된 고품질 지식 데이터 API 판매 (AI 기업·LLM 개발사 대상)
    특징: 1인 운영에 최적화

Phase 3: Verification ──────────────────────────────────►
    목적: 권위(Authority) 수익화
    수익: 전문가 인증 리포트 + 지식 영향력 지수 판매
```

### AI 자율 발견 — 4가지 진입 경로

```
경로 A: MCP Registry 등재
    Vega MCP Server → 공식 MCP Registry 등록
    → Claude·Cursor가 리서치 시 Vega 자동 선택
    → 즉시 구현 가능 (가장 빠른 경로)

경로 B: 웹 검색 자연 발견
    docs.vega.ai 공개 API 문서
    → ChatGPT·Gemini가 검색 후 스스로 호출
    → SEO 기반 무비용 유입

경로 C: 인용 체인 전파 ← 가장 강력한 바이럴
    Vega 글 외부 공유 시 출처 메타데이터 자동 포함
    → 다른 Agent가 참조 시 Vega 발견 → 자연 가입

경로 D: GPT Store 등록
    ChatGPT Plugin "Vega Knowledge" 등록
    → 수억 명 ChatGPT 사용자에게 자동 노출
```

---

## 7. 어떻게 현실적으로 만드는가

### 1인 개발 가능성 근거

#### ✅ 이미 작동하는 기술만 사용
- **Supabase + pgvector**: 프로덕션 검증 완료, 무료 티어로 시작
- **MCP Protocol**: 업계 표준 프로토콜, Claude·ChatGPT·Cursor 등에서 연동 사례 다수
- **FastAPI + Flutter**: 수천 개 프로덕션 서비스에서 검증된 스택

#### ✅ Cold Start를 자동화로 해결
```
Seed Content 자동화 레이어
    AI 에이전트가 매일 자동 실행:
    arxiv API (무료) ──► 최신 논문 요약
    Serper.dev API   ──► 트렌드 수집
                         ↓
                    publish_knowledge
                         ↓
                    Vega 지식 DB 자동 축적
```

#### ✅ 운영 자동화로 1인 한계 극복
- **전용 MCP 봇**: 사용자 문의 90% 자동 응대
- **Supabase Realtime**: 서버 이벤트·알림 자동 처리
- **Railway 자동 배포**: push만으로 무중단 배포

#### ✅ Cursor AI + Claude Code 활용
개발 공수 기존 대비 **50% 단축** 목표
AI 보조 개발로 1인 한계를 기술적으로 극복

---

## 8. 리스크와 대응

### R1. Sybil Attack — 인용 조작
- **문제**: 가짜 계정·에이전트로 특정 글의 인용 수를 조작
- **대응**: 인용 주체의 신뢰점수에 비례하여 인용 점수를 차등 반영
  - 저신뢰 계정의 인용 = 낮은 가중치

```python
# 가중치 기반 인용 점수 계산
def calculate_citation_weight(citing_agent_trust_score: float) -> float:
    """인용자의 신뢰점수에 비례한 가중치 반환"""
    return citing_agent_trust_score * CITATION_WEIGHT_FACTOR
```

### R2. Cold Start — 초기 콘텐츠 부족
- **문제**: 지식 DB가 비어있어 신규 사용자가 가치를 못 느낌
- **대응**:
  - Seed Content 자동화 레이어 (AI 에이전트 자동 발행)
  - 발행 즉시 신뢰점수 부여로 동기 제공

### R3. 1인 운영 한계
- **문제**: CS·서버 유지보수·콘텐츠 검수 부담
- **대응**:
  - MCP 봇으로 사용자 문의 90% 자동 응대
  - Supabase 내장 모니터링으로 서버 관리 최소화

---

## 9. 단계별 로드맵

```
Timeline ──────────────────────────────────────────────────────────►

[1단계] Core Infra & MCP          ~1개월
    ├─ Supabase DB 설계 (pgvector 활성화)
    ├─ FastAPI MCP Server 구축
    ├─ publish / search / cite 3개 툴 완성
    └─ ✅ 완료 기준: Claude Desktop에서 자동 발행 작동

[2단계] Web & Client              ~1개월
    ├─ Flutter 웹·모바일 MVP
    ├─ AI 보조 에디터 (글 작성 시 관련 글 추천)
    ├─ 신뢰점수 대시보드 + 인용 알림 시스템
    └─ ✅ 완료 기준: 얼리어답터 50명 온보딩

[3단계] Ecosystem & Alpha         ~2개월
    ├─ web_research 툴 (Serper.dev + arxiv)
    ├─ 인용 관계 그래프 시각화
    ├─ 신뢰점수 알고리즘 고도화
    └─ ✅ 완료 기준: 월 활성 사용자 500명

[4단계] Scale & Revenue           이후
    ├─ B2B DaaS API 출시
    ├─ GPT Store / Gemini Extension 등록
    ├─ 포인트 경제 시스템
    └─ ✅ 완료 기준: 첫 B2B 계약 + AI Agent 자율 이용
```

### 핵심 개발 우선순위

| 우선순위 | 기능 | 상태 |
|---------|------|------|
| 🔴 지금 | Supabase pgvector + MCP 3툴 | 구현 예정 |
| 🔴 지금 | AI 보조 에디터 | 구현 예정 |
| 🔴 지금 | 신뢰점수 대시보드 + 인용 알림 | 구현 예정 |
| 🟡 다음 | web_research 툴 | 추가 예정 |
| 🟡 다음 | 인용 관계 그래프 | 추가 예정 |
| 🟡 다음 | 포인트 경제 시스템 | 추가 예정 |
| 🟢 나중 | 공개 Agent API (ChatGPT·Gemini) | 계획 중 |
| 🟢 나중 | B2B DaaS API | 계획 중 |

---

## 최종 비전

> **"지식이 자산이 되고, AI가 신뢰하는**
> **세상의 표준 지식 인프라를 만듭니다"**

지금 전문가 50명의 지식이 — 미래 모든 AI의 신뢰 원천이 됩니다.

```
현재 MVP          1년 후              3년 후
────────────      ─────────────────   ───────────────────────────
사람이 이용 →     전문가·일반인 모두 → AI Agent가 자율 이용하는
하는 지식 플랫폼  사용하는 생태계      지식 인프라 표준
                                      "AI 시대의 Wikipedia"
```

---

*Vega Project | 이하늘 | 2026.04*
*1인 개발 Micro-SaaS + 지식 DaaS (Data as a Service)*
