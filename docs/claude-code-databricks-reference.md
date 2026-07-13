# Claude Code × Azure Databricks 상세 참고

이 문서는 [직접 연결 가이드](claude-code-databricks.md)의 인증, 모델, 설정 충돌과
문제 해결 세부사항을 모은 참고 문서입니다. 자동 스크립트 없이 직접 구성하려면
[한 파일 수동 연결 가이드](claude-code-databricks-manual.md)를 사용합니다.

## 1. 직접 연결 구조

```text
Claude Code ──(Anthropic /v1/messages)──► Azure Databricks
                                           /serving-endpoints/anthropic
```

`ANTHROPIC_BASE_URL`에는 `/v1/messages`를 제외한 다음 URL을 설정합니다.

```text
https://<workspace-host>/serving-endpoints/anthropic
```

Claude Code가 마지막 `/v1/messages`를 붙입니다.

## 2. 자동 설정 결과물

| 위치 | 역할 |
| --- | --- |
| 선택한 settings 파일(기본 `~/.claude/settings.json` 또는 `$CLAUDE_CONFIG_DIR/settings.json`) | Databricks Anthropic URL, 모델 프리셋, `apiKeyHelper` |
| `~/.claude-databricks/.env` | PAT 기반 자동 설정의 credential source |
| `~/.claude-databricks/get-token.sh` | macOS/Linux credential helper |
| `~/.claude-databricks/get-token.ps1` | Windows credential helper |

macOS/Linux에서는 state directory가 `0700`, token 파일이 `0600`, helper가 `0700`으로
설정됩니다. Windows에서는 현재 사용자만 수정할 수 있도록 ACL을 제한합니다.

설치기는 기존 JSON의 다른 설정을 보존합니다. 다음 값은 Databricks 직접 연결과
충돌하므로 제거합니다.

- `ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_API_KEY`
- `ANTHROPIC_MODEL`
- `ANTHROPIC_SMALL_FAST_MODEL`
- 기존 `ANTHROPIC_DEFAULT_*_MODEL`
- `CLAUDE_CODE_USE_*` provider selector

그 후 검증된 값으로 `ANTHROPIC_DEFAULT_*_MODEL`을 다시 구성합니다.
`availableModels`와 `enforceAvailableModels`도 선택한 settings에 기록해 현재 사용자의
모델 선택을 검증된 Databricks 모델 중심으로 정리합니다. Fable은 명시적으로 opt-in하고
모델 검증에 성공한 경우에만 allowlist와 family mapping에 추가됩니다.

이 사용자 settings는 편의와 실수 방지를 위한 로컬 설정이지 조직 정책이 아닙니다.
조직 전체 모델 제한은 managed settings에 배포하세요. `enforceAvailableModels`
지원에는 Claude Code 2.1.175 이상이 필요합니다.

### 기존 Anthropic API credential과 병행

리포 로컬 settings는 사용자 settings보다 우선하지만, 셸에서 export된
`ANTHROPIC_BASE_URL`, credential, model override와 `CLAUDE_CODE_USE_*` provider
selector를 제거하지는 않습니다.

기존 Anthropic 연결을 유지해야 한다면 Databricks 전용 설정 디렉터리를 별도로 만들고,
해당 프로세스에서만 사용합니다.

macOS/Linux:

```bash
DATABRICKS_CONFIG_DIR="$HOME/.claude-databricks-config"
mkdir -p "$DATABRICKS_CONFIG_DIR"

env -u ANTHROPIC_BASE_URL \
  -u ANTHROPIC_AUTH_TOKEN \
  -u ANTHROPIC_API_KEY \
  -u ANTHROPIC_MODEL \
  -u ANTHROPIC_SMALL_FAST_MODEL \
  -u ANTHROPIC_DEFAULT_OPUS_MODEL \
  -u ANTHROPIC_DEFAULT_SONNET_MODEL \
  -u ANTHROPIC_DEFAULT_HAIKU_MODEL \
  -u ANTHROPIC_DEFAULT_FABLE_MODEL \
  -u CLAUDE_CODE_USE_FOUNDRY \
  -u CLAUDE_CODE_USE_BEDROCK \
  -u CLAUDE_CODE_USE_VERTEX \
  -u CLAUDE_CODE_USE_MANTLE \
  -u CLAUDE_CODE_USE_ANTHROPIC_AWS \
  CLAUDE_SETTINGS="$DATABRICKS_CONFIG_DIR/settings.json" \
  scripts/setup_claude_code_databricks.sh

env -u ANTHROPIC_BASE_URL \
  -u ANTHROPIC_AUTH_TOKEN \
  -u ANTHROPIC_API_KEY \
  -u ANTHROPIC_MODEL \
  -u ANTHROPIC_SMALL_FAST_MODEL \
  -u ANTHROPIC_DEFAULT_OPUS_MODEL \
  -u ANTHROPIC_DEFAULT_SONNET_MODEL \
  -u ANTHROPIC_DEFAULT_HAIKU_MODEL \
  -u ANTHROPIC_DEFAULT_FABLE_MODEL \
  -u CLAUDE_CODE_USE_FOUNDRY \
  -u CLAUDE_CODE_USE_BEDROCK \
  -u CLAUDE_CODE_USE_VERTEX \
  -u CLAUDE_CODE_USE_MANTLE \
  -u CLAUDE_CODE_USE_ANTHROPIC_AWS \
  CLAUDE_CONFIG_DIR="$DATABRICKS_CONFIG_DIR" \
  claude
```

Windows PowerShell:

```powershell
$DatabricksConfigDir = Join-Path $HOME '.claude-databricks-config'
New-Item -ItemType Directory -Force -Path $DatabricksConfigDir | Out-Null
Remove-Item `
    Env:ANTHROPIC_BASE_URL, Env:ANTHROPIC_AUTH_TOKEN, Env:ANTHROPIC_API_KEY, `
    Env:ANTHROPIC_MODEL, Env:ANTHROPIC_SMALL_FAST_MODEL, `
    Env:ANTHROPIC_DEFAULT_OPUS_MODEL, Env:ANTHROPIC_DEFAULT_SONNET_MODEL, `
    Env:ANTHROPIC_DEFAULT_HAIKU_MODEL, Env:ANTHROPIC_DEFAULT_FABLE_MODEL, `
    Env:CLAUDE_CODE_USE_FOUNDRY, Env:CLAUDE_CODE_USE_BEDROCK, `
    Env:CLAUDE_CODE_USE_VERTEX, Env:CLAUDE_CODE_USE_MANTLE, `
    Env:CLAUDE_CODE_USE_ANTHROPIC_AWS `
    -ErrorAction SilentlyContinue

powershell -ExecutionPolicy Bypass `
    -File .\scripts\setup_claude_code_databricks.ps1 `
    -ClaudeSettings (Join-Path $DatabricksConfigDir 'settings.json')

$env:CLAUDE_CONFIG_DIR = $DatabricksConfigDir
claude
```

## 3. 필수 설정의 이유

### `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1`

Claude Code는 Anthropic beta 헤더나 beta 도구 필드를 보낼 수 있습니다. Databricks
네이티브 API가 지원하지 않는 beta를 받으면 400을 반환할 수 있으므로 이 값을 `1`로
설정합니다.

### `permissions.deny: ["WebSearch"]`

일반적인 Claude Code 도구 호출은 동작하지만 Anthropic hosted `WebSearch`는 현재
Databricks 네이티브 경로에서 지원이 문서화돼 있지 않습니다. 이 리포의 검증에서도
`web_search_20250305` 요청이 HTTP 400으로 거부됐습니다.

기존 deny 규칙을 지우지 말고 bare `WebSearch`만 추가합니다. 웹 검색이 필요하면 별도의
MCP 검색 서버를 사용하세요.

### `apiKeyHelper`

Credential을 `settings.json`의 `ANTHROPIC_AUTH_TOKEN`이나 `ANTHROPIC_API_KEY`에 직접
저장하면 설정 파일에 비밀이 평문으로 남습니다. Helper는 OAuth token을 요청하거나
보호된 PAT 파일에서 credential을 읽어 표준 출력으로 전달합니다.

### `ANTHROPIC_MODEL`을 설정하지 않는 이유

Opus/Sonnet/Haiku 프리셋과 같은 모델을 `ANTHROPIC_MODEL`에도 설정하면 `/model` 목록에
중복 선택지가 생길 수 있습니다. 기본 선택과 family alias는
`ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`,
`ANTHROPIC_DEFAULT_HAIKU_MODEL`로 제어합니다.

## 4. 모델 검증과 fallback

자동 설치기는 기본 모델, Haiku 후보, `DATABRICKS_MODELS` 후보를 네이티브 Anthropic
API로 먼저 호출합니다.

1. 기본 모델 검증 실패: 설정 중단
2. Haiku 검증 실패: 기본 모델을 Haiku 프리셋에도 사용
3. Opus/Sonnet 후보 실패: 검증된 같은 family를 우선하고, 없으면 기본 모델 사용
4. Fable 검증 실패: 다른 family로 대체하지 않고 Fable mapping을 만들지 않음

Fable 5는 프롬프트와 응답을 trust and safety 목적으로 30일 보존하고 일부 경우 사람
검토 대상이 될 수 있습니다. 정책을 승인한 환경에서만 명시적으로 추가합니다.

```bash
DATABRICKS_MODELS="databricks-claude-opus-4-8 databricks-claude-sonnet-5 databricks-claude-haiku-4-5 databricks-claude-fable-5" \
  scripts/setup_claude_code_databricks.sh
```

Databricks의 Sonnet 5는 `temperature`, `top_p`, `top_k`를 지원하지 않습니다. 이 리포의
설정과 테스트는 해당 sampling parameter를 추가하지 않습니다.

## 5. 선택: 개인 사용자 OAuth U2M helper

PAT를 로컬에 저장하지 않으려는 개인 개발자는 Azure Databricks OAuth U2M을 선택할 수
있습니다. 사용자는 브라우저에서 한 번 로그인하고, Databricks CLI가 1시간짜리 access
token의 발급과 갱신을 처리합니다. 사용자가 token 값을 직접 복사할 필요는 없습니다.

먼저 Databricks CLI로 로그인합니다.

```bash
databricks auth login \
  --host "https://<workspace-host>" \
  --profile claude-code
```

macOS/Linux `apiKeyHelper`:

```bash
mkdir -p "$HOME/.claude-databricks"
chmod 700 "$HOME/.claude-databricks"

cat > "$HOME/.claude-databricks/get-oauth-token.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
PROFILE="claude-code"

databricks auth token \
  --profile "$PROFILE" \
  --output json |
  python3 -c 'import json, sys; print(json.load(sys.stdin)["access_token"], end="")'
SH

chmod 700 "$HOME/.claude-databricks/get-oauth-token.sh"
```

Windows PowerShell `apiKeyHelper`:

```powershell
$StateDir = Join-Path $HOME '.claude-databricks'
$HelperPath = Join-Path $StateDir 'get-oauth-token.ps1'
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null

@'
$Profile = 'claude-code'
$Token = databricks auth token `
    --profile $Profile `
    --output json | ConvertFrom-Json
[Console]::Out.Write($Token.access_token)
'@ | Set-Content $HelperPath -Encoding utf8

icacls $HelperPath /inheritance:r /grant:r "${env:USERNAME}:(M)" | Out-Null
```

선택한 Claude settings의 `apiKeyHelper`를 해당 helper command로 지정합니다.
`CLAUDE_CODE_API_KEY_HELPER_TTL_MS=900000`을 사용하면 Claude Code가 helper 결과를 최대
15분 캐시합니다.

## 6. 운영용 OAuth M2M helper

자동화와 운영 환경에서는 Databricks 서비스 주체 OAuth M2M을 사용합니다. 각 access
token은 1시간 동안 유효하며 helper가 필요할 때 새 token을 발급합니다.

`~/.claude-databricks/m2m.env`를 만들고 `0600`으로 제한합니다.

```dotenv
DATABRICKS_HOST=https://<workspace-host>
DATABRICKS_CLIENT_ID=<service-principal-client-id>
DATABRICKS_CLIENT_SECRET=<service-principal-oauth-secret>
```

```bash
chmod 600 ~/.claude-databricks/m2m.env
```

`~/.claude-databricks/get-token.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
TOKEN_FILE="$(cd "$(dirname "$0")" && pwd)/m2m.env"
python3 - "$TOKEN_FILE" <<'PY'
import base64
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

values = {}
for raw_line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    values[key.strip()] = value.strip().strip('"').strip("'")

host = values["DATABRICKS_HOST"].rstrip("/")
client_id = values["DATABRICKS_CLIENT_ID"]
client_secret = values["DATABRICKS_CLIENT_SECRET"]
basic = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
body = urllib.parse.urlencode(
    {"grant_type": "client_credentials", "scope": "all-apis"}
).encode()
request = urllib.request.Request(
    f"{host}/oidc/v1/token",
    data=body,
    headers={
        "Authorization": f"Basic {basic}",
        "Content-Type": "application/x-www-form-urlencoded",
    },
)
with urllib.request.urlopen(request, timeout=30) as response:
    print(json.load(response)["access_token"], end="")
PY
```

```bash
chmod 700 ~/.claude-databricks/get-token.sh
```

## 7. Custom base URL에서 달라지는 기능

`ANTHROPIC_BASE_URL`이 Anthropic 기본 호스트가 아니면 Claude Code는 일부
provider-specific 기능을 비활성화할 수 있습니다.

- MCP tool search 기본 비활성화
- Remote Control 비활성화
- 일반 MCP 서버와 로컬 도구는 계속 사용 가능

Databricks 경로가 `tool_reference` block을 지원한다는 확인 없이
`ENABLE_TOOL_SEARCH=true`를 강제로 설정하지 마세요.

## 8. 문제 해결

| 증상 | 원인 / 해결 |
| --- | --- |
| 지원하지 않는 beta/필드 관련 400 | `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1` 확인 |
| `401 Credential was not sent` | `apiKeyHelper` command와 credential 파일 또는 OAuth login 확인 |
| 다른 provider/host/key/model이 사용됨 | 셸과 프로필의 `CLAUDE_CODE_USE_*`, `ANTHROPIC_*` override 제거 |
| `403 ... rate limit of 0` | 모델·리전, cross-Geo, rate limit, 권한, 계정 용량 확인 |
| `/model`의 모델 실패 | 실제 model ID와 리전 가용성 확인 |
| Fable이 picker에 없음 | 모델 검증 실패 또는 Claude Code 최소 버전 미충족 |
| `web_search_*` 400 | Bare `WebSearch` deny 또는 별도 MCP 검색 사용 |
| MCP tool search/Remote Control 없음 | Custom base URL의 기본 제한 |

## 공식 문서

- [Provider native APIs](https://learn.microsoft.com/azure/databricks/machine-learning/model-serving/provider-native-apis)
- [Query with the Anthropic Messages API](https://learn.microsoft.com/azure/databricks/machine-learning/model-serving/query-anthropic-messages)
- [Databricks-hosted foundation models](https://learn.microsoft.com/azure/databricks/machine-learning/foundation-model-apis/supported-models)
- [Foundation model Unity Catalog permissions](https://learn.microsoft.com/azure/databricks/machine-learning/foundation-model-apis/model-uc-permissions)
- [OAuth U2M](https://learn.microsoft.com/azure/databricks/dev-tools/auth/oauth-u2m)
- [OAuth M2M](https://learn.microsoft.com/azure/databricks/dev-tools/auth/oauth-m2m)
- [Databricks CLI authentication](https://learn.microsoft.com/azure/databricks/dev-tools/cli/authentication)
- [Personal access tokens](https://learn.microsoft.com/azure/databricks/dev-tools/auth/pat#create-personal-access-tokens-for-workspace-users)
- [Per-workspace URLs](https://learn.microsoft.com/azure/databricks/workspace/per-workspace-urls)
- [Claude Code settings scopes](https://code.claude.com/docs/en/settings#configuration-scopes)
- [Claude Code model configuration](https://code.claude.com/docs/en/model-config)
