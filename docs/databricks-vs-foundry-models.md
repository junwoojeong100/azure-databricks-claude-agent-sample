# Databricks 호스팅 모델 vs Microsoft Foundry 모델 직접 사용 — Foundry Control Plane 관점

## TL;DR

현재 샘플처럼 **Databricks Foundation Model API**로 Claude를 호출하면 모델 거버넌스/네트워킹/관측이 **Databricks Control Plane**에 묶입니다. **Foundry Models를 직접 쓰면** Azure AI Foundry의 RBAC, Private Link, Content Safety, Cost Management, 모델 카탈로그가 **Foundry Control Plane** 한 곳에서 관리됩니다.

---

## 1. Control Plane / 거버넌스 위치

| 항목 | 현재 (Databricks 호스팅) | Foundry Models 직접 |
| --- | --- | --- |
| 모델 카탈로그 | Databricks Foundation Model API 카탈로그 | Foundry Model Catalog (Azure OpenAI + Anthropic + Meta + Mistral + xAI 등) |
| 라이프사이클 관리 | Databricks workspace 단위 | Foundry Project / Hub 단위 |
| 권한 모델 | Databricks Unity Catalog + workspace permission | **Microsoft Entra ID + Azure RBAC** |
| 정책 적용 지점 | Databricks AI Gateway | Foundry → Azure Policy + Content Safety |

> 핵심: 거버넌스 주체가 **Databricks 관리자**인지 **Azure/Foundry 플랫폼 팀**인지가 갈립니다.

## 2. 인증 (Identity)

| | 현재 | Foundry 직접 |
| --- | --- | --- |
| 인증 방식 | Databricks PAT / OAuth (workspace 토큰) | **Entra ID Managed Identity / Service Principal** (`AzureCliCredential`, `DefaultAzureCredential`) |
| 키 관리 | PAT 회전 별도 운영 | 키리스(passwordless) 가능 |
| 감사 로그 | Databricks audit logs | Entra ID Sign-in logs + Azure Activity Log |

Foundry 쪽이 Azure 표준 ID 체계에 정렬되어 **다른 Azure 리소스와 동일한 거버넌스**를 받습니다.

## 3. 네트워킹

| | 현재 | Foundry 직접 |
| --- | --- | --- |
| Private endpoint | Databricks workspace의 Private Link 통해 간접 | **Foundry/Cognitive Services Private Endpoint** 직접 |
| 데이터 경로 | Client → Databricks workspace → 모델 호스트 | Client → Foundry endpoint (직선) |
| Egress 제어 | Databricks Network Security 정책 | Azure VNet/NSG/Firewall로 Foundry 단위 제어 |

Foundry 직접이 **홉(hop)이 적고**, Azure 네트워크 정책과 일관성이 높습니다.

## 4. 관측성 (Observability)

| 항목 | 현재 | Foundry 직접 |
| --- | --- | --- |
| 메트릭 | Serving UI Metrics + `system.serving.endpoint_usage` | **Azure Monitor Metrics** + Foundry Tracing (OpenTelemetry) |
| 로그 | Databricks Inference Tables (Delta) | Diagnostic Settings → Log Analytics / Storage |
| 분산 추적 | 별도 구성 | **Agent Framework + Foundry Tracing** 네이티브 |
| 콘텐츠 안전 로그 | AI Gateway에서 별도 설정 | Content Safety가 Foundry에 기본 내장 |

Foundry는 Azure Monitor / Application Insights와 **표준 통합**, Databricks는 자체 시스템 테이블 모델입니다.

## 5. 과금 (Cost)

| | 현재 | Foundry 직접 |
| --- | --- | --- |
| 청구서 | Databricks 인보이스 (DBU 환산) | **Azure 인보이스** (다른 Azure 리소스와 합산) |
| 단위 | DBU per 1M tokens | $/1K tokens (모델별) |
| Cost Management 통합 | Azure Cost Mgmt에서 Databricks **묶음**으로 표시 | Azure Cost Mgmt에서 모델별/태그별 분해 가능 |
| 예산/알림 | Databricks Budget Policy | Azure Budget + Action Group |

여러 Azure 워크로드를 운영 중이라면 Foundry가 **단일 청구/예산 거버넌스**에 더 잘 맞습니다.

## 6. 모델 카탈로그 / 가용성

| | 현재 | Foundry 직접 |
| --- | --- | --- |
| Anthropic Claude | ✅ (Foundation Model API) | ✅ (Foundry에 Anthropic 카탈로그 추가됨) |
| Azure OpenAI (GPT-4.1, o-시리즈 등) | ❌ | ✅ |
| Meta Llama / Mistral / xAI / DeepSeek | ✅ 일부 | ✅ 광범위 |
| 자체 fine-tuned 모델 | Databricks MLflow에서 배포 | Foundry Custom Model 배포 |
| Reasoning/도구 호출 등 신규 기능 | Databricks 지원 시점 | Foundry 우선 지원 경향 |

## 7. 쿼터 / 용량

- **현재**: Databricks 워크스페이스 단위 throughput 제한 (Pay-per-token 또는 Provisioned Throughput).
- **Foundry**: 구독/리전 단위 TPM/RPM 쿼터, **PTU (Provisioned Throughput Units)** 또는 Pay-as-you-go. Reservation 구매 가능.

엔터프라이즈 SLA·예약 가격이 필요하면 Foundry PTU 모델이 일반적으로 더 풍부한 선택지를 제공합니다.

## 8. 데이터 거버넌스 / 컴플라이언스

| | 현재 | Foundry 직접 |
| --- | --- | --- |
| 학습 데이터 사용 안 함 보장 | Databricks 정책 | Foundry/Azure OpenAI 표준 정책 |
| 데이터 거주지(region pinning) | Databricks workspace region | Foundry endpoint region (세부 선택 가능) |
| 규정 준수 인증 | Databricks 인증 셋 | Azure 인증 셋 (FedRAMP, HIPAA, ISO 등 광범위) |
| Customer-managed keys | Databricks managed | Azure Key Vault 통합 |

## 9. Agent Framework 통합 측면

| | 현재 | Foundry 직접 |
| --- | --- | --- |
| 클라이언트 | `OpenAIChatCompletionClient` + httpx hook (호환 어댑터) | **`FoundryChatClient` / `FoundryAgent`** (1급 시민) |
| Hosted tools (code interpreter, file search, MCP) | 직접 구현 | **Foundry Agent Service에서 호스팅 제공** |
| Thread/Session 관리 | 클라이언트가 직접 | Foundry 서버측 관리 옵션 |
| Evaluation / Guardrails | 별도 구축 | Foundry Evaluations + Content Safety |

샘플 코드의 `/invocations` 리라이트 같은 우회가 필요 없고, Microsoft가 정식 권장 경로입니다.

---

## 언제 어느 쪽이 맞나

**현재 방식(Databricks 호스팅)이 적합한 경우**
- 이미 Databricks가 데이터 플랫폼 표준이고, 모델 호출도 같은 보안/네트워크 경계에서 처리하고 싶을 때
- Lakehouse 데이터와 inference 결과를 같은 Delta로 보관·분석할 때 (Inference Tables)
- 엔지니어링·데이터 팀이 모두 Databricks 사용자일 때

**Foundry Models 직접이 적합한 경우**
- 거버넌스/네트워킹/비용 관리를 **Azure 표준 도구**로 일원화하고 싶을 때
- Azure OpenAI 모델(GPT-4.1, o-시리즈 등)을 같은 카탈로그에서 함께 쓰고 싶을 때
- Agent Framework의 Hosted Tools / Foundry Agent Service / Evaluations를 적극 활용할 때
- Entra ID 기반 키리스 인증, Private Endpoint, Content Safety가 컴플라이언스 요건일 때

## 마이그레이션 관점 한 줄

> **Databricks → Foundry로 옮기는 비용은 코드 한 줄(`OpenAIChatCompletionClient` 교체) 수준**이지만, 옮겨가는 즉시 **거버넌스·관측·청구가 Azure Foundry Control Plane으로 통합**됩니다. 반대로 Databricks에 남기면 **데이터 플랫폼과 모델 플랫폼이 한 경계 안**에 머무는 게 가장 큰 이점입니다.
