# Skill-Driven Terraform Generator Design

**Date**: 2026-02-15
**Status**: Approved
**Branch**: feature/skill

## Overview

요구사항 기반으로 Terraform 코드를 자동 생성하는 프로젝트. 템플릿화된 YAML 기반으로 사용자와 대화하며 요구사항을 구체화하고, 확정된 명세서로부터 Terraform 코드를 생성한다.

## Target Users

- **인프라 전문가**: YAML 템플릿 직접 작성하여 빠르게 코드 생성
- **비전문가/개발자**: 대화형 인터뷰를 통해 요구사항 수집 후 코드 생성

## Architecture: Skill-Driven

```
사용자 → /tf-spec (대화형 수집) → spec.yaml → /tf-generate (코드 생성) → Terraform 코드
                                      ↓
                               /tf-review (검토)
```

## Project Structure

```
terraform-multi-account-claude-code/
├── .claude/
│   ├── CLAUDE.md                    # 프로젝트 컨텍스트 + 코딩 표준
│   ├── settings.json                # 권한/훅 설정
│   ├── agents/
│   │   ├── tf-architect.md          # 인프라 설계 에이전트
│   │   ├── tf-security-reviewer.md  # 보안 검토 에이전트
│   │   ├── tf-cost-analyzer.md      # 비용 분석 에이전트
│   │   └── tf-module-developer.md   # 모듈 개발 에이전트
│   └── commands/
│       ├── tf-spec.md               # [NEW] 대화형 요구사항 수집 → spec.yaml
│       ├── tf-generate.md           # [NEW] spec.yaml → Terraform 코드 생성
│       ├── tf-plan.md               # terraform plan 실행
│       └── tf-review.md             # 종합 코드 리뷰
├── templates/                        # [NEW] YAML 요구사항 템플릿
│   ├── _base.yaml                   # 공통 필드 (프로젝트, 환경, 태그)
│   ├── networking.yaml              # VPC, 서브넷, TGW, VPN
│   ├── compute.yaml                 # EC2, ECS, EKS, Lambda, ASG
│   ├── database.yaml                # RDS, DynamoDB, ElastiCache
│   ├── storage.yaml                 # S3, EFS, FSx
│   ├── security.yaml                # IAM, SCP, WAF, GuardDuty
│   └── monitoring.yaml              # CloudWatch, CloudTrail, Config
├── specs/                            # [NEW] 생성된 요구사항 명세서
│   └── (사용자별 spec.yaml 저장)
├── modules/                          # 재사용 가능한 Terraform 모듈
├── environments/                     # 환경별 배포 설정
└── organization/                     # AWS Organizations 설정
```

## Component Design

### 1. YAML Templates (`templates/`)

각 템플릿은 하나의 인프라 카테고리를 정의한다.

**설계 원칙**:
- 모든 필드에 기본값 존재 (비전문가 지원)
- `enabled` 플래그 패턴 (필요한 것만 활성화)
- 주석으로 각 필드 설명 포함
- validation 규칙 내장 (CIDR, 리전, 인스턴스 타입 등)

**`_base.yaml`** (공통):
```yaml
project:
  name: ""
  environment: ""             # dev | staging | prod
  region: "ap-northeast-2"
  account_id: ""

owner:
  team: ""
  cost_center: ""

tags:
  key: value

state:
  bucket: ""
  lock_table: ""
```

**`networking.yaml`** (예시):
```yaml
networking:
  vpc:
    enabled: true
    cidr: "10.0.0.0/16"
    availability_zones: ["ap-northeast-2a", "ap-northeast-2c"]
    subnets:
      public:
        enabled: true
        cidrs: ["10.0.1.0/24", "10.0.2.0/24"]
      private:
        enabled: true
        cidrs: ["10.0.10.0/24", "10.0.11.0/24"]
      database:
        enabled: false
        cidrs: []
    nat_gateway:
      enabled: true
      single_az: true
    flow_logs:
      enabled: true
      retention_days: 30
  transit_gateway:
    enabled: false
  vpn:
    enabled: false
```

### 2. `/tf-spec` Command (대화형 요구사항 수집)

**실행**: `/tf-spec <project-name>`

**플로우**:
1. **기본 정보 수집**: 프로젝트명, 환경, 리전, 계정 ID, 팀, 비용센터
2. **카테고리 선택**: 필요한 인프라 카테고리 선택 (복수)
3. **카테고리별 상세 질문**: 선택된 카테고리만 순차적으로 질문
   - 각 질문에 기본값 제시 + 간단한 설명
   - 전문가는 기본값 수락으로 빠르게 진행
4. **명세서 생성**: `specs/{name}-spec.yaml` 생성 및 요약 출력
5. **확인/수정**: 사용자 확인 후 확정

**전문가 모드**: `/tf-spec --from templates/networking.yaml` 으로 템플릿 직접 지정

### 3. `/tf-generate` Command (코드 생성)

**실행**: `/tf-generate <spec-file>`

**플로우**:
1. **spec 파싱 및 검증**: 필수 필드 확인, 유효성 검사
2. **모듈 매핑**: spec 섹션 → Terraform 모듈 매핑 (기존 재사용 / 신규 생성)
3. **코드 생성**:
   - `environments/{env}/main.tf` - 모듈 호출
   - `environments/{env}/providers.tf` - 크로스 어카운트 AssumeRole
   - `environments/{env}/variables.tf` - spec 기반 변수
   - `environments/{env}/outputs.tf` - 주요 리소스 출력
   - `environments/{env}/backend.hcl` - State 백엔드
   - `environments/{env}/terraform.tfvars` - spec 값 기반
4. **품질 검증**: terraform fmt, validate, style-guide 스킬 적용
5. **요약 출력**: 생성 파일 목록, 리소스 요약, `/tf-review` 안내

### 4. Agents (유지)

| Agent | 역할 | 연동 |
|-------|------|------|
| tf-architect | 인프라 설계 | `/tf-spec`에서 복잡한 설계 판단 시 호출 |
| tf-security-reviewer | 보안 검토 | `/tf-review`에서 호출 |
| tf-cost-analyzer | 비용 분석 | `/tf-review`에서 호출 |
| tf-module-developer | 모듈 개발 | `/tf-generate`에서 모듈 생성 시 호출 |

### 5. Commands (변경)

| Command | 상태 | 설명 |
|---------|------|------|
| tf-spec | NEW | 대화형 요구사항 수집 |
| tf-generate | NEW | spec → 코드 생성 |
| tf-plan | 유지 | terraform plan 실행 |
| tf-review | 유지/개선 | 종합 리뷰 |
| tf-module | 제거 | tf-generate가 대체 |
| tf-account | 제거 | tf-spec의 base가 대체 |

### 6. CLAUDE.md 재설계

기존 코딩 표준/보안 가이드라인 유지하면서:
- 워크플로우 가이드 추가 (`/tf-spec` → `/tf-generate` → `/tf-review`)
- 템플릿 참조 규칙 추가
- spec.yaml 스키마 설명 추가
- 스킬 연동 가이드 추가 (terraform-engineer, terraform-style-guide, terraform-module-library)

## Scope

**인프라 범위**: AWS 전체 주요 서비스
- 네트워크: VPC, Subnet, NAT, IGW, TGW, VPN, Peering
- 컴퓨팅: EC2, ECS, EKS, Lambda, Auto Scaling
- 데이터베이스: RDS, DynamoDB, ElastiCache, Aurora
- 스토리지: S3, EFS, FSx
- 보안: IAM, SCP, WAF, GuardDuty, Security Hub
- 모니터링: CloudWatch, CloudTrail, Config, SNS

## Design Decisions

1. **YAML over HCL**: 비전문가도 읽고 수정할 수 있는 형식
2. **카테고리별 분리 템플릿**: 필요한 것만 조합하여 사용
3. **2-step 워크플로우 (spec → generate)**: 명세서 검토 단계를 분리하여 실수 방지
4. **기존 에이전트 재활용**: 이미 잘 정의된 전문 에이전트들을 파이프라인에 통합
5. **설치된 스킬 활용**: terraform-engineer/style-guide/module-library 스킬이 코드 생성 품질 보장
