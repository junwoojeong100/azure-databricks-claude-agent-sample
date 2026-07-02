# Azure Databricks Claude Agent Sample

[Microsoft Agent Framework](https://learn.microsoft.com/agent-framework/) (Python)
기반으로 **Azure Databricks Model Serving**에 배포된 **Anthropic Claude Opus 4.8**
모델을 사용하는 최소 샘플입니다.

Databricks Foundation Model API의 Anthropic 모델은 OpenAI Chat Completions와
**동일한 페이로드/응답 스키마**를 가지지만, 호출 경로는
`/serving-endpoints/<name>/invocations`만 받습니다. 본 샘플은 OpenAI SDK가
자동으로 붙이는 `/chat/completions` 경로를 httpx event hook으로 `/invocations`로
리라이트한 뒤, 이 클라이언트를 Agent Framework의 `OpenAIChatCompletionClient`에
주입하는 방식으로 동작합니다.

> 📌 **이 README 하나로 전체 실습(설치·설정·실행·문제 해결)이 완결됩니다.** Databricks vs
> Microsoft Foundry 심화 비교, 관리자 권한(Workspace/Account/Metastore) 모델, 모니터링
> 리소스·비용 등 배경/심화 내용은 참고용 문서
> [docs/databricks-vs-foundry-models.md](docs/databricks-vs-foundry-models.md)에 정리돼 있습니다.

## 0. 원클릭 자동 설정 (선택)

리소스 그룹 생성부터 워크스페이스·PAT·`.env`·엔드포인트 검증·모델 연결
테스트까지 한 번에 자동화하는 멱등(idempotent) 스크립트를 제공합니다. `az login`이
된 상태에서 실행하세요.

```bash
python3.12 -m venv .venv && .venv/bin/pip install -r requirements.txt
scripts/setup_databricks_claude.sh
# 이름/리전 변경: RG=my-rg LOCATION=eastus2 WORKSPACE=my-ws scripts/setup_databricks_claude.sh
```

스크립트는 대상 엔드포인트(`databricks-claude-opus-4-8`) 호출을 테스트하고, 만약
`rate limit of 0`(403)으로 막히면 Anthropic이 이 테넌트/계정에 아직 엔타이틀되지 않은
것이므로([§5 문제 해결](#5-문제-해결-troubleshooting) 참고), Databricks 자체 호스팅 모델로
파이프라인이 정상 동작함을 대신 검증합니다.

## 1. 사전 준비

1. **Azure 구독 + Databricks 워크스페이스**(권장 SKU `premium`). Claude Opus 4.8 서빙
   엔드포인트(`databricks-claude-opus-4-8`)는 워크스페이스에 **기본 배포**돼 있습니다
   (Serving → Endpoints에서 확인). Claude는 Llama·GPT-OSS와 같은 **Databricks-hosted
   Foundation Model**(pay-per-token)입니다.
   - ⚠️ 단, Anthropic Claude는 **계정/지역별 서빙 용량 할당** 대상이라, 할당이 없는
     계정(= Entra ID 테넌트)에서는 호출이 `rate limit of 0`으로 막힙니다 →
     [§5 문제 해결](#5-문제-해결-troubleshooting) 참고.
2. **PAT 발급** — 대상 엔드포인트에 **CAN QUERY** 권한이 있는
   [Databricks Personal Access Token](https://learn.microsoft.com/azure/databricks/dev-tools/auth/pat):
   워크스페이스 → Settings → Developer → Access tokens → Manage → Generate new token.
   (`§0` 자동 스크립트는 Azure 로그인으로 PAT를 자동 발급합니다.)
3. **Python 3.10 이상** (이 저장소는 3.12로 검증).

## 2. 설치

```bash
git clone https://github.com/<your-account>/azure-databricks-claude-agent-sample.git
cd azure-databricks-claude-agent-sample

python3.12 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

> `source .venv/bin/activate` 대신 `.venv/bin/python`을 직접 호출해도 됩니다.

## 3. 환경 변수 설정

`.env.example`을 복사해 `.env`로 만든 뒤 값을 채웁니다.

```bash
cp .env.example .env
```

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `DATABRICKS_HOST` | 워크스페이스 URL (스킴 포함, 끝 슬래시 없음) | `https://adb-1234567890.16.azuredatabricks.net` |
| `DATABRICKS_SERVING_ENDPOINT` | Claude Opus 4.8가 배포된 서빙 엔드포인트 이름 | `databricks-claude-opus-4-8` |
| `DATABRICKS_TOKEN` | Databricks PAT (`dapi...`) | `dapiXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX` |

내부적으로 다음 URL을 호출합니다:

```
{DATABRICKS_HOST}/serving-endpoints/{DATABRICKS_SERVING_ENDPOINT}/invocations
```

## 4. 실행

```bash
.venv/bin/python src/agent_sample.py
```

스크립트 시작 시 `python-dotenv`가 프로젝트 루트의 `.env`를 자동으로 로드합니다.
별도로 `source .env`를 할 필요가 없습니다. 셸 환경 변수가 이미 설정돼 있다면
그 값이 우선합니다.

실행 흐름:

1. 시작과 동시에 한국어 **샘플 질문 3개**(`SAMPLE_QUESTIONS`)가 자동으로 큐에서
   순차 실행됩니다 — 사용자가 입력하지 않아도 곧바로 응답을 확인할 수 있습니다.
   각 샘플 턴은 프롬프트 라인 끝에 `(sample)` 라벨로 표시됩니다.
2. 모델이 첫 토큰을 보내기 전까지 같은 줄에서 브레일 스피너
   (`⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏ 응답 대기 중…`)가 회전합니다. 첫 토큰이 도착하면 스피너가
   사라지고 응답이 스트리밍됩니다.
3. 매 턴마다 사용 토큰이 출력됩니다.
4. 샘플 큐가 비면 자동으로 사용자 입력(stdin) 모드로 전환됩니다. 빈 줄 또는
   Ctrl-D로 종료하면 누적 합계가 출력됩니다.

샘플 질문 목록(스크립트 상단 `SAMPLE_QUESTIONS`에서 자유롭게 수정 가능):

1. Azure Databricks Model Serving이 무엇인지 한 문단으로 설명해줘.
2. Microsoft Agent Framework와 Microsoft Foundry Agent Service의 차이를 비교해줘.
3. 이 샘플처럼 Databricks의 Claude 모델을 호출할 때 주의할 점 3가지를 알려줘.

출력 예시:

```
Databricks Claude Opus 4.8 agent — 대화를 시작합니다.
종료하려면 빈 줄을 입력하거나 Ctrl-D를 누르세요.
먼저 샘플 질문 3개를 자동으로 실행합니다.

[User] Azure Databricks Model Serving이 무엇인지 한 문단으로 설명해줘.  (sample)
⠹ 응답 대기 중…
[Agent] Azure Databricks Model Serving은 …
[Tokens] this turn: input=1458 output=58 total=139
         | cumulative (1 turns): input=1458 output=58 total=139

... (샘플 2, 3 자동 실행) ...

[User]                          ← 여기서부터 직접 입력
============================================================
세션 요약 — 3턴, 총 input=4363, output=182, total=346 tokens
```

> 토큰 카운트는 Databricks/Anthropic이 반환하는 `usage` 필드를 그대로 사용합니다.
> 캐시(cache_read / cache_creation) 토큰이 있을 경우 `total`이 단순히
> `input + output`이 아닐 수 있습니다.

## 5. 문제 해결 (Troubleshooting)

### `403 PERMISSION_DENIED: ... Databricks-set rate limit of 0` (Claude 호출 시)

먼저 사실 정리: Anthropic Claude는 Azure Databricks에서 **"Databricks-hosted" Foundation
Model**입니다(BYO 키를 쓰는 external 모델이 아님 — 릴리스 노트가 "Databricks-hosted model"로
명시). Llama·GPT-OSS와 동일하게 `/serving-endpoints/<name>/invocations`로 호출하고,
`system.ai` 카탈로그·DBU 과금·동일한 pay-per-token 한도(**200,000 ITPM**)를 따릅니다.
정상 한도 초과 시 반환은 **429**입니다.

따라서 `403 ... rate limit of 0`은 **정상 rate-limit이 아니라**, 이 계정에 대해 Databricks가
Claude 서빙 한도를 **0으로 막아 둔 상태**입니다. 공식 리전 표는 Claude를
*"supported based on GPU availability"* 로 표기합니다 — 즉 **Anthropic(라이선스 파트너)
모델은 계정별 서빙 용량 활성화 대상**이라, 완전 오픈 모델(Llama 등)과 달리 활성화되지 않은
계정에서는 이렇게 막힙니다. 같은 Entra 테넌트(= 같은 Databricks 계정)면 리전·워크스페이스를
바꿔도 동일합니다.

> **경험적 확인:** 이 값은 **새로 생성한 Databricks 계정에서 기본 0**으로 관찰됩니다 —
> 서로 다른 테넌트 2곳(관리형 구독 + 개인 Visual Studio Enterprise 구독), koreacentral·eastus2
> (네이티브 리전 포함)에서 **동일하게 Claude만 403, Llama 등 오픈 모델은 200**으로 재현됐습니다.
> 즉 리전·거버넌스 문제가 아니라 **계정 단위 Anthropic 활성화** 문제입니다.

**1) 계정 레벨 게이트인지 확인** — Databricks 자체 오픈 모델은 되는데 Claude만 막히면 위 상황입니다:

```bash
set -a; . ./.env; set +a          # DATABRICKS_HOST / DATABRICKS_TOKEN 로드
for EP in databricks-meta-llama-3-3-70b-instruct "$DATABRICKS_SERVING_ENDPOINT"; do
  printf '%s -> ' "$EP"
  curl -sS -o /dev/null -w '%{http_code}\n' -X POST \
    "$DATABRICKS_HOST/serving-endpoints/$EP/invocations" \
    -H "Authorization: Bearer $DATABRICKS_TOKEN" -H 'Content-Type: application/json' \
    -d '{"messages":[{"role":"user","content":"hi"}],"max_tokens":5}'
done
# 오픈 모델 200 + Claude 403  →  계정에 Anthropic 서빙 용량이 할당되지 않은 상태
```

**2) 해결** — PAT·워크스페이스 권한·partner-powered·cross-Geo 등 **고객 설정으로는 바뀌지
않습니다**(모두 켜도 0). 공식 문서 안내대로:

- **Anthropic 용량이 이미 할당된 Entra 테넌트/구독**에서 실행하거나,
- **Azure Databricks account team에 문의**해 계정의 Anthropic 서빙 용량 활성화를 요청하세요
  (새로 생성한 Databricks 계정은 Anthropic pay-per-token이 기본 비활성(0)이며, 이는 관리형·개인
  구독 모두에서 재현됩니다).

**3) 비 EU/US 리전(예: `koreacentral`) 추가 조건** — Claude는 "EU/US" 모델이라 비EU/US
워크스페이스는 **cross-Geo 데이터 처리**도 켜져 있어야 합니다: account console → **Workspaces →
워크스페이스 → Security and compliance → "Enforce data processing within workspace Geography
for Designated Services" Off**. (단, 위 용량 할당과 별개 — 할당이 0이면 cross-Geo를 켜도 0입니다.)

### 관리자 권한이 필요한 작업

워크스페이스 생성자는 **workspace admin**(엔드포인트 권한·PAT 발급)이 자동 부여되지만,
**account admin**(신규 워크스페이스·메타스토어·시스템 테이블·계정 설정)은 별도입니다. 최초
account admin은 **Entra ID Global Administrator**가 [account console](https://accounts.azuredatabricks.net)에
로그인해 부트스트랩합니다. 3단계 권한 모델·자가 진단은
[심화 문서](docs/databricks-vs-foundry-models.md) §10 참고.

### 샘플이 자동 처리하는 항목

- Databricks `/invocations`가 거부하는 OpenAI `stream_options` 필드와 Anthropic이 거부하는
  메시지 `name` 필드는 httpx 훅에서 **자동 제거**됩니다(`src/agent_sample.py`).

## 6. 운영 모니터링 (Databricks)

이 엔드포인트는 AI Gateway의 `usage_tracking_config.enabled = true`가 켜져 있어
다음 위치에서도 자동 집계됩니다.

| 위치 | 용도 |
| --- | --- |
| Databricks UI → Serving → 엔드포인트 상세 페이지 | (Custom / Provisioned Throughput 엔드포인트만) 인프라 헬스 메트릭 차트 |
| Databricks UI → Serving → AI Gateway → **Create / View Dashboard** | 토큰/요청/지연시간/사용자별 빌트인 대시보드 (account admin이 import 필요, 백엔드에 SQL Warehouse 사용) |
| `system.ai_gateway.usage` (AI Gateway Beta) / `system.serving.endpoint_usage` (시스템 테이블) | 사용자/엔드포인트/시간 단위 집계, 비용 분석 (account admin 권한 필요) |
| Inference Tables (엔드포인트 설정에서 활성화) | 모든 요청/응답 + 토큰을 Delta 테이블로 저장 |

예시 SQL:

```sql
SELECT
  date_trunc('hour', request_time) AS hour,
  endpoint_name,
  SUM(input_token_count)  AS input_tokens,
  SUM(output_token_count) AS output_tokens,
  COUNT(*)                AS requests
FROM system.serving.endpoint_usage
WHERE endpoint_name = 'databricks-claude-opus-4-8'
  AND request_time >= current_date() - INTERVAL 7 DAYS
GROUP BY 1, 2
ORDER BY 1 DESC;
```

> 모니터링을 위해 추가로 활성화/생성해야 하는 리소스(SQL Warehouse, Inference Tables,
> 시스템 스키마)와 비용 상세는 참고 문서
> [docs/databricks-vs-foundry-models.md](docs/databricks-vs-foundry-models.md) §11 참고.

## 동작 원리

Databricks Foundation Model API의 Anthropic 모델 엔드포인트는 `api_types`로
`mlflow/v1/chat/completions`, `anthropic/v1/messages`만 노출하며,
OpenAI 호환 경로(`/openai/v1/chat/completions`)는 제공하지 않습니다.
대신 `/serving-endpoints/<name>/invocations`가 OpenAI Chat Completions와
**동일한 요청/응답 스키마**(`messages` 입력, `choices[0].message.content` 응답)를 사용합니다.

따라서 OpenAI SDK가 자동으로 추가하는 `/chat/completions` 경로를
httpx **event hook**으로 `/invocations`로 리라이트한 뒤, 이 클라이언트를
Agent Framework의 `OpenAIChatCompletionClient`에 `async_client=`로 주입합니다.

```python
import httpx
from openai import AsyncOpenAI
from agent_framework.openai import OpenAIChatCompletionClient

async def rewrite(req: httpx.Request) -> None:
    if req.url.path.endswith("/chat/completions"):
        new_path = req.url.path[:-len("/chat/completions")] + "/invocations"
        req.url = req.url.copy_with(path=new_path)

http_client = httpx.AsyncClient(event_hooks={"request": [rewrite]})
openai_client = AsyncOpenAI(
    base_url=f"{HOST}/serving-endpoints/{ENDPOINT}/",
    api_key=DATABRICKS_PAT,
    http_client=http_client,
)
client = OpenAIChatCompletionClient(async_client=openai_client, model=ENDPOINT)
agent = client.as_agent(name="ClaudeAgent", instructions="...")
```

> 만약 사용하시는 엔드포인트가 OpenAI 호환 경로를 직접 노출한다면
> (`api_types`에 `openai/v1/chat/completions` 포함) 위 hook 없이
> `base_url=".../serving-endpoints/<name>/openai/v1/"`만으로 충분합니다.

## 참고

- [Microsoft Agent Framework — OpenAI-Compatible Endpoints](https://learn.microsoft.com/agent-framework/agents/providers/openai)
- [Databricks Model Serving — OpenAI compatible APIs](https://learn.microsoft.com/azure/databricks/machine-learning/model-serving/score-foundation-models#openai-client)
- [Foundation Model APIs limits and quotas (rate limits)](https://learn.microsoft.com/azure/databricks/machine-learning/foundation-model-apis/limits)
- [Databricks 호스팅 모델 vs Microsoft Foundry — 심화 비교·거버넌스·모니터링 (참고 문서)](docs/databricks-vs-foundry-models.md)
