# AI 간 공유 컨텍스트 (SHARED_CONTEXT.md)
> Claude Code와 Cursor가 공통으로 참조하는 단일 진실 공급원(Single Source of Truth)
> 상수값, 엔드포인트, 테이블명 변경 시 반드시 이 파일을 먼저 업데이트하세요.

---

## 🔌 API 엔드포인트 (확정)
```
POST   /knowledge/publish     # 지식 게시
GET    /knowledge/search      # 지식 검색 (벡터)
POST   /knowledge/cite        # 인용 + 포인트 차감
GET    /knowledge/{id}        # 단일 지식 조회
GET    /transaction/history   # 거래 내역 조회
GET    /agents/{id}/balance   # 에이전트 포인트 잔액
```

---

## 📐 공통 상수
```python
# 포인트
DEFAULT_CITATION_PRICE      = 5       # 기본 인용 가격 (포인트)
MIN_CITATION_PRICE          = 1       # 최소 인용 가격
MAX_CITATION_PRICE          = 100     # 최대 인용 가격

# trust_score 가중치
TRUST_WEIGHT_SYSTEM         = 0.4
TRUST_WEIGHT_AGENT_VOTE     = 0.5
TRUST_WEIGHT_ADMIN          = 0.1

# 콘텐츠 제한
MAX_TITLE_LENGTH            = 100     # 글자
MAX_CONTENT_CLAIM_LENGTH    = 500     # 글자
MAX_SUMMARY_LENGTH          = 300     # 글자
MAX_TAGS_COUNT              = 10      # 개

# Rate Limiting
MAX_CALLS_PER_SECOND        = 10      # 에이전트당 초당 최대 호출
MAX_DAILY_BUDGET_POINTS     = 1000    # 에이전트당 일일 최대 지출 포인트

# 검색
DEFAULT_SEARCH_LIMIT        = 20      # 검색 결과 기본 개수
MAX_SEARCH_LIMIT            = 100
```

---

## 🗄️ DB 테이블명 (변경 금지)
```
knowledge       # 지식 게시물
transaction     # 포인트 거래 내역
agents          # 에이전트 계정 (추후 추가 예정)
```

---

## 📊 상태값 Enum (양측 동일하게 사용)
```
# knowledge.status
unverified      # 기본값, 검증 전
verified        # 검증 완료
disputed        # 검증 이의 제기 중
rejected        # 거부됨

# transaction.status
pending         # 처리 중
completed       # 완료
failed          # 실패

# transaction.type
cite            # 인용료
publish_reward  # 게시 보상
admin_grant     # 관리자 지급
```

---

## 🔐 환경변수 키 이름 (통일)
```
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_KEY
MCP_SECRET_KEY
RAILWAY_TOKEN
FLUTTER_API_BASE_URL
```

---

## 🎨 UI 상수 (Flutter)
```dart
// Colors
primaryColor    = Color(0xFF1E3A5F)
accentColor     = Color(0xFF2E6DA4)
backgroundColor = Color(0xFFF5F8FC)
successColor    = Color(0xFF27AE60)
errorColor      = Color(0xFFE74C3C)
warningColor    = Color(0xFFF39C12)

// Typography
fontFamily      = 'Noto Sans KR'
```

---

## 📡 MCP Tool 파라미터 정의
```json
publish_knowledge: {
  "title": "string (max 100)",
  "content_claim": "string (max 500)",
  "summary": "string (max 300)",
  "evidence": [{"type": "string", "value": "string", "source_url": "string"}],
  "source_urls": ["string"],
  "tags": ["string"],
  "citation_price": "int (1~100, default 5)"
}

search_knowledge: {
  "query": "string",
  "limit": "int (default 20, max 100)",
  "status_filter": "verified | unverified | all (default: all)"
}

cite_knowledge: {
  "knowledge_id": "string",
  "citing_agent_id": "string",
  "context": "string (인용 맥락, optional)"
}
```

---

## 📅 마지막 업데이트
- 날짜: 2026-04-22
- 업데이트 내용: 초기 컨텍스트 작성
- 업데이트 주체: 기획 단계
