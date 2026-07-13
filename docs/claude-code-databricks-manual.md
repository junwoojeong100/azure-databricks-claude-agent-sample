# Claude Code와 Azure Databricks 최소 수동 설정

가장 단순한 연결 방법은 이 리포의 `.claude/settings.local.json` 파일 하나를 사용하는
것입니다. 이 파일은 `.gitignore`에 포함되어 있으므로 Git에 커밋되지 않습니다.

```text
Claude Code
  └─ .claude/settings.local.json
       ├─ Azure Databricks URL
       ├─ PAT
       └─ 사용할 Claude 모델 ID
```

> 이 방법은 PAT를 로컬 settings에 평문으로 저장하는 대신 설정이 가장 간단합니다.
> 먼저 연결을 확인한 뒤 보안 요구가 높아지면 `apiKeyHelper`나 OAuth로 전환하세요.

## 1. Settings 파일 만들기

프로젝트 루트에서 `.claude` 디렉터리를 만듭니다.

macOS/Linux:

```bash
mkdir -p .claude
chmod 700 .claude
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force -Path .claude | Out-Null
```

`.claude/settings.local.json`:

```json
{
  "permissions": {
    "deny": [
      "WebSearch"
    ]
  },
  "env": {
    "ANTHROPIC_BASE_URL": "https://<workspace-host>/serving-endpoints/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "<databricks-pat>",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "databricks-claude-opus-4-8",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "databricks-claude-sonnet-5",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "databricks-claude-haiku-4-5",
    "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "1"
  }
}
```

다음 두 값만 자신의 환경에 맞게 바꿉니다.

| Placeholder | 입력할 값 |
| --- | --- |
| `<workspace-host>` | `adb-1234567890123456.7.azuredatabricks.net` 형식의 host |
| `<databricks-pat>` | 해당 workspace와 모델을 호출할 수 있는 PAT |

처음에는 하나의 검증된 모델만 사용해 Opus/Sonnet/Haiku alias를 모두 같은 모델에
연결하는 것이 가장 간단합니다.

macOS/Linux에서는 파일 권한을 제한합니다.

```bash
chmod 600 .claude/settings.local.json
```

Windows에서는 현재 사용자만 수정할 수 있도록 제한합니다.

```powershell
icacls .claude\settings.local.json `
  /inheritance:r /grant:r "${env:USERNAME}:(M)" | Out-Null
```

## 2. Claude Code 실행

프로젝트 루트에서 Databricks 모델을 명시해 실행합니다.

```bash
claude --model databricks-claude-opus-4-8 \
  -p "Reply with exactly: MANUAL OK" \
  --output-format json
```

정상 응답에서 `is_error`는 `false`이고 결과에는 `MANUAL OK`가 포함됩니다.

대화형 실행:

```bash
claude
```

`/model`에서 Opus/Sonnet/Haiku와 Databricks 모델 ID를 확인할 수 있습니다.

## 3. 모델 선택기 동작

Claude Code는 시작할 때 `settings.local.json`을 읽어 `/model` 선택기를 구성합니다.
자동 스크립트는 필요하지 않습니다.

| 설정 | 역할 |
| --- | --- |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | `opus` 선택 시 실제 요청할 Databricks 모델 |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | `sonnet` 선택 시 실제 요청할 Databricks 모델 |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | `haiku` 선택 시 실제 요청할 Databricks 모델 |

앞의 설정에서는 다음 alias가 각각의 Databricks 모델로 연결됩니다.

- `opus` → `databricks-claude-opus-4-8`
- `sonnet` → `databricks-claude-sonnet-5`
- `haiku` → `databricks-claude-haiku-4-5`

현재 workspace에서 위 세 모델의 Anthropic Messages API 호출이 모두 성공하는 것을
확인했습니다.

선택기를 세 alias로 제한하고 싶을 때만 다음 항목을 settings 최상위에 추가합니다.

```json
{
  "availableModels": [
    "opus",
    "sonnet",
    "haiku"
  ]
}
```

## 4. 하나의 모델만 사용할 때

Workspace에서 한 모델만 호출할 수 있다면 세 alias를 같은 모델 ID에 연결해도 됩니다.
이 경우에만 다음처럼 설정합니다.

```json
{
  "env": {
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "databricks-claude-opus-4-8",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "databricks-claude-opus-4-8",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "databricks-claude-opus-4-8"
  }
}
```

## 5. 자주 발생하는 문제

| 증상 | 확인할 항목 |
| --- | --- |
| 다른 provider나 host가 사용됨 | 터미널에 남은 `ANTHROPIC_*` 또는 `CLAUDE_CODE_USE_*` 환경변수 제거 |
| `401 Credential was not sent` | `ANTHROPIC_AUTH_TOKEN`의 PAT와 workspace 확인 |
| beta 또는 `web_search_*` 관련 400 | beta 비활성화와 `WebSearch` deny 확인 |
| 모델을 찾지 못함 | 현재 workspace에서 실제 호출 가능한 Databricks 모델 ID 확인 |

## 선택: credential 보안 강화

이 한 파일 방식은 이해하고 시작하기 쉽지만 PAT가 평문으로 저장됩니다. 보안 요구가
높아지면 settings의 `ANTHROPIC_AUTH_TOKEN`을 제거하고 다음 방식으로 전환합니다.

- 개인 사용자: [OAuth U2M](https://learn.microsoft.com/azure/databricks/dev-tools/auth/oauth-u2m)
- 운영 자동화: [OAuth M2M](https://learn.microsoft.com/azure/databricks/dev-tools/auth/oauth-m2m)
- 보호된 PAT 파일: 자동 설치기가 생성하는 `apiKeyHelper`
