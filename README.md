# Claude on Azure Databricks

[Microsoft Agent Framework](https://learn.microsoft.com/agent-framework/) (Python)
기반으로 **Azure Databricks Model Serving**에서 제공되는 **Anthropic Claude Opus 4.8**
모델을 사용하는 최소 샘플입니다.

> 최종 검증: 2026-07-11. 모델·리전 가용성, 쿼터, Preview 상태는 변경될 수 있으므로
> 운영 배포 전 링크된 공식 문서를 다시 확인하세요.

## 이 리포로 할 수 있는 것

1. **Python 에이전트 샘플** — Microsoft Agent Framework로 Databricks의 Claude Opus 4.8을
  호출하는 최소 예제(`src/agent_sample.py`). 아래 **§0~§4**로 바로 실습할 수 있습니다.
2. **Claude Code 백엔드 연결** — 터미널 코딩 CLI [Claude Code](https://code.claude.com/)의
  LLM을 Databricks의 **네이티브 Anthropic Messages API**에 직접 연결합니다. LiteLLM,
  로컬 포트, 백그라운드 프록시는 필요하지 않습니다.
  → [docs/claude-code-databricks.md](docs/claude-code-databricks.md)

| 목적 | 시작 위치 |
| --- | --- |
| Azure 리소스 생성부터 Python Agent 실행까지 | [§0 자동 설정](#0-자동-설정-macoslinuxwsl-선택) 또는 §1~§4 |
| 기존 Claude Code를 Databricks Claude로 전환 | [Claude Code 빠른 경로](#claude-code-빠른-경로) |
| 운영·비용·Foundry 비교 | [심화 비교 문서](docs/databricks-vs-foundry-models.md) |

Python 샘플은 Databricks의 표준 OpenAI 호환 경로
`/serving-endpoints/chat/completions`를 사용합니다. Agent Framework가 다중 턴 이력에
추가하는 선택적 `name` 필드만 Databricks Claude가 거부하므로, httpx 훅은 이 필드만
제거합니다. URL 변환이나 LiteLLM은 사용하지 않습니다.

> 📌 **Python Agent 실습은 이 README의 §0~§4로 완결됩니다.** Claude Code는 별도
> 직접 연결 가이드, 운영·비용·Foundry 비교는 심화 문서로 분리했습니다.

> 💻 **[Claude Code](https://code.claude.com/)(Anthropic 터미널 코딩 CLI)의 LLM을 이 Databricks
> Claude 엔드포인트로 설정**하려면 — 네이티브 `/serving-endpoints/anthropic` 연결,
> 안전한 token helper, `~/.claude/settings.json` 구성·검증까지 —
> **[docs/claude-code-databricks.md](docs/claude-code-databricks.md)** 가이드를 참고하세요.
> 원클릭 스크립트 [`scripts/setup_claude_code_databricks.sh`](scripts/setup_claude_code_databricks.sh)로
> 직접 연결 설정이 자동화됩니다.
> 요건·주의사항 요약(동료·고객·파트너 공유용)은
> [docs/claude-code-databricks-checklist.md](docs/claude-code-databricks-checklist.md)를 참고하세요.

## Claude Code 빠른 경로

> ✅ **이미 Claude Code가 설치돼 있고 `.env`에 자신의 Databricks 접속 정보가 있다면,
> 아래 설치기 한 번으로 전환됩니다.**

```bash
unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY
scripts/setup_claude_code_databricks.sh
```

Windows PowerShell:

```powershell
Remove-Item Env:ANTHROPIC_AUTH_TOKEN, Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
powershell -ExecutionPolicy Bypass -File .\scripts\setup_claude_code_databricks.ps1
```

### 실행 전 준비

1. [Claude Code](https://code.claude.com/)가 설치돼 있어야 합니다. 이 리포의 기본
   Sonnet 5 매핑까지 사용하려면 2.1.197 이상을 권장합니다.
2. 리포를 clone하고 `.env.example`을 `.env`로 복사합니다.
3. `.env`에 고객/파트너 자신의 값을 입력합니다.

```dotenv
DATABRICKS_HOST=https://<workspace>.azuredatabricks.net
DATABRICKS_SERVING_ENDPOINT=databricks-claude-opus-4-8
DATABRICKS_TOKEN=<대상 모델을 호출할 수 있는 PAT>
```

macOS/Linux 설치기는 `curl`과 Python 3도 사용합니다. Claude 모델이 해당 Databricks
계정·리전에서 활성화돼 있어야 합니다. 일반 serving endpoint ACL에서는 `CAN QUERY`가
필요하고, Foundation Model Unity Catalog 권한 기능을 활성화한 계정은 승인된
`system.ai` 모델에 `EXECUTE`도 필요합니다.

### 설치기가 자동으로 하는 일

- Claude Code와 충돌하는 ambient credential 사전 점검
- macOS/Linux에서는 `curl`과 Python도 사전 점검
- 네이티브 `/serving-endpoints/anthropic/v1/messages` 호출 확인
- 기존 `~/.claude/settings.json` 백업 후 Databricks 직접 URL과 모델 프리셋 병합
- PAT를 설정 JSON에 넣지 않고 권한이 제한된 `apiKeyHelper` 파일에 저장
- `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1`로 미지원 Anthropic beta 헤더 억제
- hosted `WebSearch` deny 설정
- 기존 LiteLLM launchd/systemd/Scheduled Task 중지
- Claude Code를 실제 실행해 `DIRECT OK` 종단 간 확인

기존 Claude Code 설정의 다른 항목은 보존됩니다. 전환 후에는 로컬 포트나 LiteLLM
프로세스가 필요하지 않습니다.

### 직접 연결 확인 (macOS/Linux)

```bash
python3 -c \
  'import json, pathlib; p = pathlib.Path.home() / ".claude/settings.json"; print(json.loads(p.read_text())["env"]["ANTHROPIC_BASE_URL"])'
# 기대값: https://<workspace>.azuredatabricks.net/serving-endpoints/anthropic

if command -v lsof >/dev/null; then
  lsof -nP -iTCP:4000 -sTCP:LISTEN
fi
# 기대값: 출력 없음

claude --model databricks-claude-opus-4-8 \
  -p "Reply with exactly: DIRECT OK" --output-format json
```

더 자세한 모델 전환, Windows 결과물, 인증 범위 및 문제 해결은
[Claude Code 직접 연결 가이드](docs/claude-code-databricks.md)를 참고하세요.

> 🚀 **처음이신가요?** macOS/Linux/WSL에서는
> **[§0 자동 설정 스크립트](#0-자동-설정-macoslinuxwsl-선택)** 가 가장 빠릅니다.
> 필수 CLI와 Python 환경을 준비하고 Azure에 로그인하면 리소스 그룹·워크스페이스·PAT·
> `.env` 생성부터 검증까지 자동으로 수행합니다. 각 단계를 직접 이해하며 하고 싶으면
> **§1~§4**(사전 준비 → 설치 → 환경 변수 → 실행)를 순서대로 따르세요.

## 0. 자동 설정 (macOS/Linux/WSL, 선택)

리소스 그룹 생성부터 워크스페이스·PAT·`.env`·OpenAI 호환 API·네이티브 Anthropic
API 검증과 샘플 실행까지 자동화하는 스크립트를 제공합니다.

> **필요한 것:** [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli),
> [Azure CLI Databricks 확장](https://learn.microsoft.com/azure/databricks/admin/workspace/azure-cli),
> curl, Python 3.10 이상(3.12 권장), git, 그리고 리소스를 만들 수 있는 **Azure 구독**
> (Owner 또는 Contributor 권한).

```bash
# 1) 리포 클론 (이미 했다면 생략)
git clone https://github.com/junwoojeong100/claude-on-azure-databricks.git
cd claude-on-azure-databricks

# 2) Python 3.10+ 확인 + 가상환경 + 의존성 설치
PYTHON_BIN="${PYTHON_BIN:-python3}"  # 필요하면 python3.12, python3.11 등으로 변경
"$PYTHON_BIN" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else "Python 3.10+ required: " + sys.version)'
"$PYTHON_BIN" -m venv .venv
.venv/bin/python -m pip install -r requirements.txt

# 3) Azure CLI 확장 설치 + 로그인 (브라우저 인증 창이 열립니다)
az extension add --name databricks --upgrade
az login
# 여러 구독이 있으면 실행: az account set --subscription "<name-or-id>"

# 4) 실행 — RG·워크스페이스·PAT·.env 생성 + 엔드포인트 검증 + 샘플 실행
scripts/setup_databricks_claude.sh
# 기본값: RG=rg-databricks-claude · LOCATION=eastus2 · WORKSPACE=ws-databricks-claude
# 변경 예: RG=my-rg LOCATION=koreacentral WORKSPACE=my-ws scripts/setup_databricks_claude.sh
# API 연결까지만 검증하고 샘플 질문 3개는 건너뛰기: RUN_AGENT=0 scripts/setup_databricks_claude.sh
```

같은 workspace에서 다시 실행하면 `.env`의 PAT를 먼저 검증해 유효한 경우 재사용하고,
기존 serving endpoint와 Claude Code model 설정도 명시적 환경변수로 덮어쓰지 않는 한
보존합니다.
명시적으로 새 PAT가 필요할 때만 `ROTATE_PAT=1 scripts/setup_databricks_claude.sh`를
사용하세요. 네트워크 오류나 429/5xx로 기존 PAT를 검증하지 못하면 불필요한 토큰 생성을
막기 위해 중단합니다.

`ROTATE_PAT=1`은 새 PAT를 만들지만 기존 PAT를 자동 폐기하지 않습니다. 새 토큰이 정상
동작하는지 확인한 뒤 더 이상 사용하지 않는 PAT는 워크스페이스 설정에서 폐기하세요.

스크립트는 대상 엔드포인트(`databricks-claude-opus-4-8`) 호출을 테스트하고, 만약
`rate limit of 0`(403)으로 막히면 모델/리전, cross-Geo, endpoint·사용자 rate limit,
권한, 계정 용량을 점검하도록 안내하고 Databricks 자체 호스팅 모델로 인증과 API 경로가
정상인지 별도로 검증합니다. Cross-Geo와 Designated Services 같은 account-level 정책은
공개되지 않은 설정 필드로 추정하지 않고 account console에서 직접 확인해야 합니다.

> 자동 스크립트가 만드는 사용자 PAT는 로컬 개발용입니다. Databricks는 PAT를 legacy
> 인증으로 분류하며 운영 환경에는 서비스 주체 OAuth M2M을 권장합니다. PAT가 꼭 필요한
> 개발/테스트에서도 가능하면 사용자 PAT보다 서비스 주체 PAT를 사용하세요.

> **비용 주의:** 기본 설정은 Premium Databricks 워크스페이스와 pay-per-token 모델을
> 사용합니다. 실습이 끝난 뒤 리소스 그룹 전체가 불필요하면
> `az group delete -n rg-databricks-claude --yes --no-wait`로 정리하세요.

## 1. 사전 준비

1. **Azure 구독 + Databricks 워크스페이스**(권장 SKU `premium`). Claude Opus 4.8
   pay-per-token 엔드포인트(`databricks-claude-opus-4-8`)는 워크스페이스에
   **사전 구성**돼 있습니다
   (Serving → Endpoints에서 확인). Claude는 Llama·GPT-OSS와 같은 **Databricks-hosted
   Foundation Model**(pay-per-token)입니다.
   - ⚠️ 모델/리전 가용성, cross-Geo, endpoint rate limit 또는 계정별 용량 상태에 따라
     호출이 `rate limit of 0`으로 거부될 수 있습니다 →
     [§5 문제 해결](#5-문제-해결-troubleshooting) 참고.
2. **인증 정보** — 일반 serving endpoint ACL에서는 대상 엔드포인트에 **CAN QUERY**가
   필요합니다. Foundation Model Unity Catalog 권한 기능을 활성화했다면 승인된
   `system.ai` 모델에 `EXECUTE`도 필요합니다.
   운영 환경은 서비스 주체 **OAuth M2M**을 권장하며, 이 최소 샘플과 자동 설정은
   개발 편의를 위해
   [Databricks Personal Access Token (legacy)](https://learn.microsoft.com/azure/databricks/dev-tools/auth/pat)을
   사용합니다. 워크스페이스 → Settings → Developer → Access tokens → Manage →
   Generate new token.
   (`§0` 자동 스크립트는 Azure 로그인으로 PAT를 발급하고 이후 유효한 `.env` PAT를 재사용합니다.)
3. **Python 3.10 이상** (3.12 권장).

## 2. 설치

macOS/Linux/WSL:

```bash
git clone https://github.com/junwoojeong100/claude-on-azure-databricks.git
cd claude-on-azure-databricks

PYTHON_BIN="${PYTHON_BIN:-python3}"  # 필요하면 python3.12, python3.11 등으로 변경
"$PYTHON_BIN" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else "Python 3.10+ required: " + sys.version)'
"$PYTHON_BIN" -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

> `source .venv/bin/activate` 대신 `.venv/bin/python`을 직접 호출해도 됩니다.

Windows PowerShell:

```powershell
git clone https://github.com/junwoojeong100/claude-on-azure-databricks.git
Set-Location claude-on-azure-databricks

py -3 -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 'Python 3.10+ required: ' + sys.version)"
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

`py` 런처가 없는 Windows 환경에서는 Python 3.10 이상인지 확인한 뒤 위 두 명령의
`py -3`을 `python`으로 바꿉니다.

## 3. 환경 변수 설정

`.env.example`을 복사해 `.env`로 만든 뒤 값을 채웁니다.

```bash
cp .env.example .env
```

Windows PowerShell에서는 `Copy-Item .env.example .env`를 사용합니다.

| 변수 | 설명 | 예시 |
| --- | --- | --- |
| `DATABRICKS_HOST` | 워크스페이스 URL (스킴 포함, 끝 슬래시 없음) | `https://adb-1234567890.16.azuredatabricks.net` |
| `DATABRICKS_SERVING_ENDPOINT` | 사용할 Databricks-hosted Claude endpoint 이름 | `databricks-claude-opus-4-8` |
| `DATABRICKS_TOKEN` | Databricks PAT (`dapi...`) | `dapiXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX` |

Python 샘플은 다음 OpenAI 호환 URL에 `DATABRICKS_SERVING_ENDPOINT`를 `model`로
전달합니다:

```
{DATABRICKS_HOST}/serving-endpoints/chat/completions
```

Claude Code는 별도의 네이티브 Anthropic URL을 사용합니다:

```text
{DATABRICKS_HOST}/serving-endpoints/anthropic/v1/messages
```

## 4. 실행

```bash
.venv/bin/python src/agent_sample.py
```

Windows PowerShell에서는 `.\.venv\Scripts\python.exe src\agent_sample.py`를 실행합니다.

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
Databricks agent (databricks-claude-opus-4-8) — 대화를 시작합니다.
종료하려면 빈 줄을 입력하거나 Ctrl-D를 누르세요.
먼저 샘플 질문 3개를 자동으로 실행합니다.

[User] Azure Databricks Model Serving이 무엇인지 한 문단으로 설명해줘.  (sample)
⠹ 응답 대기 중…
[Agent] Azure Databricks Model Serving은 …
[Tokens] this turn: input=1458 output=421 total=1879
         | cumulative (1 turns): input=1458 output=421 total=1879

... (샘플 2, 3 자동 실행) ...

[User]                          ← 여기서부터 직접 입력
============================================================
세션 요약 — 3턴, 총 input=8203, output=1287, total=9490 tokens
```

> 이 샘플은 Databricks OpenAI 호환 API를 통해 Agent Framework가 반환한
> `input_token_count`, `output_token_count`, `total_token_count`를 표시합니다.
> `total_token_count`가 없을 때만 `input + output`을 사용합니다.
>
> 네이티브 Anthropic Messages API의 `usage` 구조는 다릅니다. `input_tokens`는
> cache token을 제외하므로 전체 입력은
> `input_tokens + cache_read_input_tokens + cache_creation_input_tokens`이고,
> 전체 token은 여기에 `output_tokens`를 더해 계산합니다.

## 5. 문제 해결 (Troubleshooting)

### `403 PERMISSION_DENIED: ... Databricks-set rate limit of 0` (Claude 호출 시)

Anthropic Claude는 Azure Databricks의 Databricks-hosted Foundation Model입니다.
OpenAI 호환 Foundation Model API와 네이티브 Anthropic Messages API를 모두 제공합니다.
일반 사용량 초과는 보통 429이므로 이 403은 구분해서 진단해야 하지만, 메시지만으로
원인을 account entitlement 하나로 확정할 수는 없습니다.
이 오류 문구와 아래 순서는 이 리포에서 관찰한 실무 진단 지식이며, Databricks의 공식
오류 코드별 원인 매핑은 아닙니다.

먼저 Databricks 자체 오픈 모델을 호출해 인증과 공통 API 경로를 분리해서 확인합니다.

```bash
set -a; . ./.env; set +a          # DATABRICKS_HOST / DATABRICKS_TOKEN 로드
for EP in databricks-meta-llama-3-3-70b-instruct "$DATABRICKS_SERVING_ENDPOINT"; do
  printf '%s -> ' "$EP"
  printf 'header = "Authorization: Bearer %s"\n' "$DATABRICKS_TOKEN" |
  curl --config - -sS -o /dev/null -w '%{http_code}\n' -X POST \
    "$DATABRICKS_HOST/serving-endpoints/chat/completions" \
    -H 'Content-Type: application/json' \
    -d "{\"model\":\"$EP\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}"
done
# 오픈 모델 200 + Claude 403 → 공통 인증/API 경로는 정상, Claude 제공 조건을 추가 점검
```

**점검 순서:**

1. Foundation Model API의 [지원 모델](https://learn.microsoft.com/azure/databricks/machine-learning/foundation-model-apis/supported-models)과
   [리전별 가용성](https://learn.microsoft.com/azure/databricks/machine-learning/model-serving/foundation-model-overview)을
   확인합니다.
2. 다른 Geography에서 처리되는 모델이라면 account console의 designated services 데이터
   처리 설정과 조직의 cross-Geo 정책을 확인합니다.
3. Serving → Endpoints → 해당 모델 → AI Gateway에서 endpoint·사용자·그룹 rate limit이
   0으로 설정되지 않았는지 확인합니다.
4. 호출 주체의 endpoint `CAN QUERY`를 확인하고, Foundation Model Unity Catalog 권한
   기능을 사용한다면 대상 `system.ai` 모델의 `EXECUTE`도 확인합니다.
5. 계속 재현되면 workspace URL, 모델, 리전, request ID, 발생 시각을 포함해
   [Azure Databricks 지원](https://learn.microsoft.com/azure/databricks/resources/support)
   또는 Databricks account team에 용량·계정 제공 상태를 문의합니다.

### 관리자 권한이 필요한 작업

Azure Contributor/Owner는 워크스페이스를 만들고 처음 로그인해 **workspace admin**
권한을 얻을 수 있지만, **account admin**(메타스토어·시스템 테이블·계정 설정)은 별도입니다. 최초
account admin은 **Entra ID Global Administrator**가 [account console](https://accounts.azuredatabricks.net)에
로그인해 부트스트랩합니다. **3단계 권한 모델·부트스트랩·권한 매트릭스·자가 진단**은
[§7 관리자 권한 모델](#7-관리자-권한-모델) 참고.

### 샘플이 자동 처리하는 항목

- Agent Framework가 대화 이력의 assistant 메시지에 추가하는 `name` 필드는 Databricks
  Claude가 허용하지 않으므로, 최소 httpx 훅에서 이 필드만 **자동 제거**합니다
  (`src/agent_sample.py`).

## 6. 운영 모니터링 (Databricks)

Serving endpoint 상세의 이전 세대 **AI Gateway for serving endpoints**에서
**Enable usage tracking**을 켜면
`system.serving.endpoint_usage`에 요청별 토큰 사용량이 수집되고,
`system.serving.served_entities`에서 endpoint·모델 메타데이터를 조회할 수 있습니다.
두 테이블은 `served_entity_id`로 조인합니다. 새 **Unity AI Gateway (Beta)**를
활성화한 계정은 model service의 `system.ai_gateway.usage`와 빌트인 대시보드도 사용할
수 있습니다. 두 기능의 설정 화면과 시스템 테이블은 서로 다릅니다.

| 위치 | 용도 |
| --- | --- |
| Databricks UI → Serving → 엔드포인트 상세 페이지 | (Custom / Provisioned Throughput 엔드포인트만) 인프라 헬스 메트릭 차트 |
| Databricks UI → Serving → AI Gateway | 이전 세대 endpoint별 usage tracking, rate limit, payload logging, guardrail 설정 (`CAN MANAGE` 필요) |
| `system.serving.endpoint_usage` + `system.serving.served_entities` | 사용자/endpoint/모델/시간 단위 토큰 집계 (usage tracking 필요) |
| Databricks UI → AI Gateway (Beta) | Unity Catalog model service, routing, budget, service policy, 통합 대시보드 |
| `system.ai_gateway.usage` (Unity AI Gateway Beta) | model service의 사용량 집계 (Preview와 account admin 접근 필요) |
| Inference Tables | 요청/응답 payload를 Unity Catalog Delta 테이블에 저장 |

예시 SQL:

```sql
SELECT
  date_trunc('hour', u.request_time) AS hour,
  e.endpoint_name,
  COALESCE(e.entity_name, e.served_entity_name) AS model_name,
  SUM(u.input_token_count)  AS input_tokens,
  SUM(u.output_token_count) AS output_tokens,
  COUNT(*)                  AS requests
FROM system.serving.endpoint_usage AS u
JOIN system.serving.served_entities AS e
  ON u.served_entity_id = e.served_entity_id
WHERE u.request_time >= current_timestamp() - INTERVAL 7 DAYS
  AND lower(COALESCE(e.entity_name, e.served_entity_name)) LIKE '%claude%'
GROUP BY
  date_trunc('hour', u.request_time),
  e.endpoint_name,
  COALESCE(e.entity_name, e.served_entity_name)
ORDER BY hour DESC;
```

> Usage tracking 설정은 endpoint `CAN MANAGE` 권한이 필요합니다. AI Gateway의 전용
> 문서는 `system.serving.endpoint_usage`와 `served_entities`를 account admin이
> 조회한다고 설명하고, 일반 시스템 테이블 문서는 account admin과 metastore admin을
> 모두 가진 사용자가 기본 접근한다고 설명합니다. 다른 사용자에게 위임할 때는 두 역할을
> 모두 가진 관리자가 `system` catalog의 `USE CATALOG`, 대상 schema의 `USE SCHEMA`와
> `SELECT`를 부여합니다. 반면 현재 Beta 문서는 `system.ai_gateway.usage` 조회를
> account admin으로 제한하며 일반 사용자 위임을 문서화하지 않습니다. Inference
> Tables에는 Unity Catalog와 serverless compute,
> endpoint `CAN MANAGE`, 대상 카탈로그의 `USE CATALOG`, 스키마의 `USE SCHEMA`·
> `CREATE TABLE`도 필요합니다. 추가 리소스와 비용 상세는
> [docs/databricks-vs-foundry-models.md](docs/databricks-vs-foundry-models.md) §11 참고.

## 7. 관리자 권한 모델

Databricks 운영 작업의 상당수는 **어느 관리자 역할이 있느냐**로 가능 여부가 갈립니다
(Workspace / Account / Metastore). `rate limit of 0`은 메시지만으로 원인을 확정하지
말고 [§5 문제 해결](#5-문제-해결-troubleshooting)의 순서대로 점검하세요.

### 7.1 세 가지 레벨

| 레벨 | 스코프 | 부여 방법 | 대표 권한 |
| --- | --- | --- | --- |
| **Workspace admin** | 단일 Databricks workspace | Account admin이 만든 워크스페이스에서는 생성자가 자동 부여. 아직 역할이 없다면 Azure 구독 Owner/Contributor가 워크스페이스에 로그인해 획득할 수도 있음. 이후 UI/API로 위임 | 워크스페이스 내 사용자/그룹·권한·클러스터·서빙 엔드포인트·잡 관리, PAT 발급, 노트북 권한 |
| **Account admin** | Databricks **account** 전체 (account console = `accounts.azuredatabricks.net`) | **자동 부여되지 않음**. 최초 1회는 **Microsoft Entra ID Global Administrator**가 account console에 처음 로그인하여 부트스트랩. 이후 기존 account admin이 UI/API로 위임 | 계정 콘솔의 워크스페이스·메타스토어·시스템 테이블·Preview·계정 사용자/그룹·청구 설정 관리 |
| **Metastore admin** | Unity Catalog metastore 1개 (보통 region 1개) | 메타스토어 생성 시 지정 (account admin이 생성). 기본은 그 사용자/그룹이 owner | 카탈로그 생성/소유권 이전, 외부 location/storage credential 관리, 모든 카탈로그·스키마·테이블에 대한 메타데이터 권한 |

> **⚠️ 흔한 오해**: Azure 구독 Owner/Contributor 또는 workspace admin이라고 해서
> Databricks account admin이 되는 것은 아닙니다. Account admin은 별도 부트스트랩이 필요합니다.

### 7.2 부트스트랩 (최초 account admin) 절차

Microsoft Learn 공식 문서 요지:

> "For security and organizational integrity, Databricks requires that a **Microsoft Entra ID Global Administrator** establish your account's first account admin role."

1. Microsoft Entra ID **Global Administrator** 권한이 있는 사용자가 <https://accounts.azuredatabricks.net> 접속.
2. Microsoft Entra ID 로그인 → 첫 로그인 시 자동으로 해당 Databricks 계정의 account admin이 부여됨.
3. 부여 후에는 Global Administrator 권한이 더 이상 필요 없음 (Account console 접근만 가능하면 됨).
4. 이후 추가 account admin은 account console → **User management** → 대상 사용자 →
   **Roles**에서 위임 가능 (Global Admin 권한 불필요).

> **Azure 구독 Owner/Contributor만으로는 account admin 부트스트랩 불가**. 반드시 Entra ID Global Administrator가 최초 1회 클릭해야 합니다.

### 7.3 Unity Catalog 상태 확인

Databricks는 2023년 11월 9일부터 새 워크스페이스의 Unity Catalog 자동 활성화를
점진적으로 도입했으며, 공식 문서는 그 이후 생성된 워크스페이스가 자동 활성화됐을 수
있다고 안내합니다. 실제 워크스페이스에서 `system` catalog와 workspace catalog를 먼저
확인하고, 활성화되지 않은 경우에만 account admin이 리전별 metastore를 만들어
워크스페이스를 할당하세요.

| 항목 | 설명 |
| --- | --- |
| 자동 활성화 확인 | Catalog Explorer에서 workspace catalog와 `system` catalog 확인 |
| 기존 워크스페이스 업그레이드 | **Account admin**이 metastore 생성/할당 |
| 1개 region 1개 | 같은 region 내 여러 워크스페이스가 하나의 metastore를 공유 가능 |
| 관리형 스토리지 | 자동 활성화 환경은 Databricks 관리형 스토리지를 사용할 수 있음. 외부 ADLS 접근에는 별도 storage credential/access connector 구성 |
| Workspace 연결 | 기존 non-Unity Catalog 워크스페이스를 업그레이드할 때 metastore 할당 필요 |
| 시스템 스키마 | `system.serving.endpoint_usage`, `system.ai_gateway.usage`, `system.access.audit` 등은 기능별 활성화 조건과 account-level 권한이 다르므로 각 시스템 테이블 문서 확인 |
| Metastore admin | 메타스토어 owner 그룹/사용자. 카탈로그 생성·소유권 이전·외부 location 관리 가능 |

> Unity Catalog가 활성화되어 있어야 **AI Gateway 사용량 시스템 테이블·Inference Tables** 등 [§6 운영 모니터링](#6-운영-모니터링-databricks) 및 [심화 문서](docs/databricks-vs-foundry-models.md) §11의 관측 기능이 의미를 갖습니다.

### 7.4 이 샘플 운영 시 필요 권한 매트릭스

| 작업 | 필요한 최소 권한 |
| --- | --- |
| 엔드포인트 호출 | 사용자/SP에 endpoint `CAN QUERY`; Foundation Model UC 권한 사용 시 대상 `system.ai` 모델 `EXECUTE` |
| PAT 발급 (로컬 개발용) | 본인 사용자 권한 (workspace 설정에서 PAT 허용된 경우). 운영은 OAuth M2M 권장 |
| Inference Tables 활성화 | endpoint `CAN MANAGE` + serverless compute + Unity Catalog `USE CATALOG`·`USE SCHEMA`·`CREATE TABLE` |
| 서빙 엔드포인트 **Enable usage tracking** | endpoint `CAN MANAGE` |
| `system.serving.endpoint_usage` / `served_entities` 조회 | 전용 문서는 account admin으로 명시. 일반 시스템 테이블 권한 위임은 `USE CATALOG` + `USE SCHEMA` + `SELECT`; 위임 관리자는 account admin과 metastore admin을 모두 보유 |
| `system.ai_gateway.usage` 조회 | 현재 Unity AI Gateway Beta 문서 기준 **account admin만** 가능 |
| Unity AI Gateway 빌트인 대시보드 생성 | **Account admin** + SQL Warehouse |
| Metastore 생성/워크스페이스 할당 | **Account admin** |
| 신규 워크스페이스 생성 | Azure Portal/CLI: 구독 **Owner/Contributor** 또는 필요한 custom role. Account console: **Account admin** |

### 7.5 빠른 자가 진단

본인 권한을 1회 호출로 점검:

```bash
# Workspace 레벨 — admins 그룹에 속하면 workspace admin
printf 'header = "Authorization: Bearer %s"\n' "$DATABRICKS_TOKEN" |
  curl --config - -sS \
    "$DATABRICKS_HOST/api/2.0/preview/scim/v2/Me" |
  python3 -c \
    'import json, sys
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    raise SystemExit("Databricks API did not return JSON; check the curl error above")
groups = data.get("groups")
if not isinstance(groups, list):
    raise SystemExit(data.get("message") or data.get("error_code") or "groups missing")
print("\n".join(g.get("display", "") for g in groups))'

# Entra ID Global Administrator 여부 (부트스트랩 가능자인지)
az rest --method get \
  --url "https://graph.microsoft.com/v1.0/me/memberOf?\$select=displayName" \
  --query "value[?displayName=='Global Administrator']"
```

Account admin 여부는 <https://accounts.azuredatabricks.net> → **User management** → 본인
사용자의 **Roles**에서 확인합니다.

> Databricks 3단계 관리자 권한을 Foundry(단일 Azure RBAC)와 비교한 표는
> [심화 문서](docs/databricks-vs-foundry-models.md) §10 참고.

## 동작 원리

Databricks Foundation Model API는 여러 모델에 공통으로 쓸 수 있는 OpenAI 호환
`/serving-endpoints/chat/completions` 경로를 제공합니다. SDK의 `model`에는
서빙 엔드포인트 이름을 전달합니다. 따라서 URL 리라이트나 LiteLLM 프록시는 필요하지 않습니다.

Agent Framework는 대화 이력의 assistant 메시지에 선택 필드 `name`을 추가하지만, Databricks
Claude는 이 필드를 거부합니다. 아래처럼 해당 필드만 제거하는 최소 훅을 사용합니다.

```python
import json

import httpx
from openai import AsyncOpenAI
from agent_framework.openai import OpenAIChatCompletionClient

async def strip_message_names(request: httpx.Request) -> None:
    if request.method == "POST" and request.content:
        body = json.loads(request.content)
        for message in body.get("messages", []):
            message.pop("name", None)
        content = json.dumps(body).encode()
        request.stream = httpx.ByteStream(content)
        request.headers["content-length"] = str(len(content))

http_client = httpx.AsyncClient(event_hooks={"request": [strip_message_names]})
openai_client = AsyncOpenAI(
    base_url=f"{HOST}/serving-endpoints",
    api_key=DATABRICKS_TOKEN,
    http_client=http_client,
)
client = OpenAIChatCompletionClient(async_client=openai_client, model=ENDPOINT)
agent = client.as_agent(name="ClaudeAgent", instructions="...")
```

Claude Code는 OpenAI 호환 경로가 아니라 provider-native Anthropic Messages API
`/serving-endpoints/anthropic/v1/messages`에 직접 연결합니다. Claude Code가 `/v1/messages`를
붙이므로 `ANTHROPIC_BASE_URL`에는 `https://<workspace>/serving-endpoints/anthropic`을
설정합니다.

## 참고

- [Microsoft Agent Framework — OpenAI-Compatible Endpoints](https://learn.microsoft.com/agent-framework/agents/providers/openai)
- [Databricks Model Serving — OpenAI compatible APIs](https://learn.microsoft.com/azure/databricks/machine-learning/model-serving/score-foundation-models#openai-client)
- [Databricks-hosted foundation models](https://learn.microsoft.com/azure/databricks/machine-learning/foundation-model-apis/supported-models)
- [Foundation model Unity Catalog permissions](https://learn.microsoft.com/azure/databricks/machine-learning/foundation-model-apis/model-uc-permissions)
- [Foundation Model APIs limits and quotas (rate limits)](https://learn.microsoft.com/azure/databricks/machine-learning/foundation-model-apis/limits)
- [AI governance with Unity AI Gateway](https://learn.microsoft.com/azure/databricks/ai-gateway/)
- [AI Gateway for serving endpoints](https://learn.microsoft.com/azure/databricks/ai-gateway/overview-serving-endpoints)
- [Configure AI Gateway on model serving endpoints](https://learn.microsoft.com/azure/databricks/ai-gateway/configure-ai-gateway-endpoints)
- [System tables reference](https://learn.microsoft.com/azure/databricks/admin/system-tables/)
- [Monitor served models using inference tables](https://learn.microsoft.com/azure/databricks/ai-gateway/inference-tables-serving-endpoints)
- [Anthropic prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- [Databricks 호스팅 모델 vs Microsoft Foundry — 심화 비교·거버넌스·모니터링 (참고 문서)](docs/databricks-vs-foundry-models.md)
- [Claude Code에서 Azure Databricks의 Claude 모델 사용하기 — 네이티브 API 직접 연결 가이드](docs/claude-code-databricks.md)
