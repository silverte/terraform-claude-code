# Terraform Spec Builder - 대화형 요구사항 수집

사용자와 대화하며 인프라 요구사항을 수집하고 YAML 명세서(spec.yaml)를 생성합니다.

## Usage
```
/tf-spec <project-name>
```

## Arguments
- **project-name**: 프로젝트 식별자 (예: my-web-service, my-org)

## Execution Steps

### Phase 0: 프로젝트 타입 선택

AskUserQuestion 도구로 프로젝트 타입을 질문합니다.

질문: "어떤 유형의 인프라를 구성하시겠습니까?"

선택지:
- **조직 기반 설정 (Organization Foundation)**: AWS Organizations, OU, SCP, 중앙 보안/로깅, Transit Gateway 등 멀티 어카운트 거버넌스 구성
- **워크로드 배포**: VPC, EC2, ECS, RDS 등 애플리케이션 인프라 배포

- "조직 기반 설정" 선택 → `project.type: "org-foundation"` 설정 → **Phase 1-org**로 진행
- "워크로드 배포" 선택 → `project.type: "workload"` 설정 → **Phase 1**로 진행

---

## 워크로드 배포 흐름 (project.type: "workload")

### Phase 1: 기본 정보 수집

`templates/_base.yaml`을 참조하여 다음 정보를 순서대로 질문합니다.
AskUserQuestion 도구를 사용하여 하나씩 질문하세요.

1. **환경**: dev / staging / prod 중 선택
   - 질문: "배포 환경을 선택해주세요: dev / staging / prod (기본: dev)"
   - 기본값: dev

2. **리전**: 기본값 ap-northeast-2, 변경 필요 시 선택
   - 질문: "AWS 리전을 선택해주세요 (기본: ap-northeast-2)"
   - 기본값: ap-northeast-2
   - 검증: 유효한 AWS 리전 코드인지 확인

3. **AWS 계정 ID**: 대상 계정 ID 입력
   - 질문: "대상 AWS 계정 ID를 입력해주세요 (12자리 숫자)"
   - 검증: 12자리 숫자인지 확인

4. **멀티 어카운트**: 사용 여부 확인
   - 질문: "멀티 어카운트 구성을 사용하시나요? (y/n, 기본: n)"
   - 기본값: false
   - y 선택 시 추가 질문:
     - "Management Account ID를 입력해주세요 (12자리 숫자)"
     - "Security Account ID를 입력해주세요 (12자리 숫자)"
     - AssumeRole 이름은 기본값 `TerraformExecutionRole` 사용

5. **프로젝트 설명**: 프로젝트 목적 간략 설명
   - 질문: "프로젝트에 대해 간략히 설명해주세요 (예: 결제 API 백엔드 서비스)"

6. **담당 팀**: 팀명 입력
   - 질문: "담당 팀명을 입력해주세요 (예: platform-team)"

7. **담당자 이메일**: 연락 가능한 이메일
   - 질문: "담당자 이메일을 입력해주세요"
   - 검증: 이메일 형식인지 확인

8. **비용 센터**: 비용 센터 코드 입력
   - 질문: "비용 센터 코드를 입력해주세요 (예: CC-1234)"

9. **State 설정**: S3 버킷명, DynamoDB 테이블명
   - 질문: "Terraform State S3 버킷명을 입력해주세요 (기본: {project-name}-terraform-state-{account-id})"
   - 질문: "DynamoDB 락 테이블명을 입력해주세요 (기본: {project-name}-terraform-lock)"
   - 기본값 자동 생성 제안

### Phase 2: 인프라 카테고리 선택

AskUserQuestion으로 필요한 인프라 카테고리를 복수 선택하게 합니다.

질문: "필요한 인프라 카테고리를 선택해주세요 (번호로 복수 선택, 쉼표 구분)"

카테고리 목록:
```
1. 네트워크 (VPC, 서브넷, NAT Gateway, Transit Gateway, VPN, VPC Peering)
2. 컴퓨팅 (EC2, ECS, EKS, Lambda, Auto Scaling)
3. 데이터베이스 (RDS, Aurora, DynamoDB, ElastiCache)
4. 스토리지 (S3, EFS, FSx)
5. 보안 (IAM, SCP, WAF, GuardDuty, Security Hub, KMS)
6. 모니터링 (CloudWatch, CloudTrail, Config, SNS)
```

- 예시 응답: "1,2,3" 또는 "네트워크, 컴퓨팅, 데이터베이스"
- "전체" 또는 "all" 입력 시 모든 카테고리 선택

### Phase 3: 카테고리별 상세 질문

선택된 카테고리에 대해서만 `templates/{category}.yaml`을 참조하여 상세 질문합니다.
각 카테고리의 질문을 시작하기 전에 해당 템플릿 파일을 반드시 읽어서 필드 구조를 확인하세요.

#### 질문 전략

- **전문가 감지**: 사용자가 CIDR 블록, 인스턴스 타입, 엔진 버전 등 기술 세부사항을 직접 언급하면 상세 모드로 전환하여 세부 설정을 질문합니다.
- **비전문가 모드**: 기술 용어 대신 목적 기반 질문을 사용합니다.
  - 예: "CIDR 블록을 입력하세요" 대신 "예상 서버 수가 어느 정도인가요? (소규모: ~50대, 중규모: ~200대, 대규모: 200대 이상)"로 질문하고 적절한 CIDR을 추천합니다.
  - 예: "인스턴스 타입을 선택하세요" 대신 "어떤 용도의 서버인가요? (웹 서버 / API 서버 / 배치 처리 / 데이터 분석)"으로 질문하고 적절한 인스턴스 타입을 추천합니다.
- **기본값 적극 활용**: 모든 질문에 기본값을 명시하고, 엔터(빈 입력)로 기본값을 수락할 수 있도록 합니다.

#### 네트워크 질문 흐름 (templates/networking.yaml 참조)

1. **VPC CIDR**
   - 전문가: "VPC CIDR 블록을 입력해주세요 (기본: 10.0.0.0/16)"
   - 비전문가: "네트워크 규모를 선택해주세요: 소규모(/24, ~256 IP) / 중규모(/20, ~4096 IP) / 대규모(/16, ~65536 IP, 기본)"
   - 검증: 유효한 CIDR 블록인지, RFC 1918 사설 대역인지 확인

2. **가용영역 수**
   - 질문: "사용할 가용영역 수를 선택해주세요: 2(기본, 비용절감) / 3(고가용성)"
   - 기본값: 2 (ap-northeast-2a, ap-northeast-2c)

3. **서브넷 구성**
   - 질문: "서브넷 구성을 선택해주세요:"
     - `1` Public + Private (기본, 일반 웹 서비스)
     - `2` Private Only (내부 서비스, VPN 접근)
     - `3` Public + Private + Database (DB 전용 서브넷 분리)
   - 서브넷 CIDR은 VPC CIDR을 기반으로 자동 계산하여 제안

4. **NAT Gateway**
   - 퍼블릭 서브넷이 포함된 경우에만 질문
   - 질문: "NAT Gateway 구성을 선택해주세요:"
     - `1` 단일 AZ (기본, 비용 절감 - 월 ~$45)
     - `2` 다중 AZ (고가용성 - AZ당 ~$45/월)
   - 프로덕션 환경에서는 다중 AZ 권장 안내

5. **VPC Flow Logs**
   - 질문: "VPC Flow Logs를 활성화하시겠습니까? (y/n, 기본: y)"
   - 기본값: true (보안 가이드라인상 필수)
   - y 선택 시: "로그 보관 기간을 선택해주세요: 7 / 14 / 30(기본) / 90일"

6. **Transit Gateway** (멀티 어카운트 사용 시에만 질문)
   - 질문: "다른 VPC 또는 계정과의 네트워크 연결이 필요합니까? (y/n, 기본: n)"
   - y 선택 시: Transit Gateway 설정 질문

7. **VPC Peering** (Transit Gateway 미사용 시 대안으로 질문)
   - 질문: "기존 VPC와 피어링 연결이 필요합니까? (y/n, 기본: n)"

8. **VPN**
   - 질문: "온프레미스 VPN 연결이 필요합니까? (y/n, 기본: n)"

9. **DNS (Route53)**
   - 질문: "도메인 관리(Route53)가 필요합니까? (y/n, 기본: n)"
   - y 선택 시:
     - "도메인명을 입력해주세요 (예: example.com)"
     - "DNS 타입을 선택해주세요:"
       - `1` 퍼블릭 DNS (인터넷에서 접근, 기본)
       - `2` 프라이빗 DNS (VPC 내부 전용)
       - `3` 둘 다
     - ALB/NLB가 있는 경우: "로드밸런서를 도메인에 연결하시겠습니까? (y/n, 기본: y)"
   - 비전문가 안내: "Route53은 도메인(예: api.example.com)을 서버 주소로 연결해주는 DNS 서비스입니다."

#### 컴퓨팅 질문 흐름 (templates/compute.yaml 참조)

1. **워크로드 타입**
   - 질문: "워크로드 타입을 선택해주세요:"
     - `1` 컨테이너 - ECS (관리형 컨테이너, 권장)
     - `2` 컨테이너 - EKS (Kubernetes, 대규모 MSA)
     - `3` 가상 서버 - EC2 (전통적 서버)
     - `4` 서버리스 - Lambda (이벤트 기반)
     - `5` 혼합 (복수 선택)

2. **ECS 선택 시:**
   - 실행 환경: "Fargate(서버리스, 기본) vs EC2(세밀한 제어)"
   - 서비스 구성: "서비스 수는 몇 개인가요? (기본: 1)"
   - 각 서비스별:
     - 서비스명 (예: api-service)
     - CPU/메모리: "워크로드 크기를 선택해주세요: 소규모(0.25vCPU/512MB) / 중규모(0.5vCPU/1GB, 기본) / 대규모(1vCPU/2GB) / 직접입력"
     - 원하는 인스턴스 수 (기본: 2)
     - 오토스케일링 사용 여부 (기본: true)
     - 헬스체크 경로 (기본: /health)

3. **EKS 선택 시:**
   - 클러스터 버전: "EKS 버전을 선택해주세요 (기본: 1.29)"
   - 엔드포인트 접근: "클러스터 API 접근 방식: Private Only(기본, 보안) / Public + Private"
   - 노드 그룹 수: "노드 그룹 수를 입력해주세요 (기본: 1)"
   - 각 노드 그룹별:
     - 그룹명 (예: general)
     - 인스턴스 타입 (기본: t3.medium)
     - 노드 수: min/max/desired (기본: 2/5/3)
     - 용량 타입: "ON_DEMAND(기본, 안정적) vs SPOT(비용 절감, 중단 가능성)"
   - 애드온 선택 (기본: vpc-cni, coredns, kube-proxy)

4. **EC2 선택 시:**
   - 전문가: 인스턴스 타입 직접 입력
   - 비전문가: "서버 용도를 선택해주세요: 웹 서버(t3.small) / API 서버(t3.medium) / 배치(c6i.large) / 메모리 집약(r6i.large)"
   - 수량 (기본: 1)
   - 서브넷 배치: public / private (기본: private)
   - Auto Scaling 사용 여부
   - Auto Scaling y 시: min/max/desired, 스케일링 기준 (CPU 70% 기본)

5. **Lambda 선택 시:**
   - 함수 수 (기본: 1)
   - 각 함수별:
     - 함수명
     - 런타임: Python 3.12 / Node.js 20 / Java 21 / Go / 기타
     - 메모리 (기본: 128MB)
     - 타임아웃 (기본: 30초)
     - 트리거: API Gateway / S3 / SQS / EventBridge Schedule / 기타
     - VPC 내 실행 여부 (기본: false)

6. **로드밸런서** (ECS, EKS, EC2+Auto Scaling 선택 시 자동 질문)
   - 질문: "로드밸런서가 필요합니까? (y/n, 기본: ECS/EKS 선택 시 y)"
   - y 선택 시:
     - "로드밸런서 타입을 선택해주세요:"
       - `1` ALB (HTTP/HTTPS 트래픽, 웹 서비스 권장, 기본)
       - `2` NLB (TCP/UDP 트래픽, 고성능/저지연)
     - 스키마: "인터넷에서 접근이 필요합니까?"
       - `1` 인터넷 접근 가능 (internet-facing, 기본)
       - `2` 내부 전용 (internal, VPC 내부만)
     - HTTPS: "HTTPS를 사용하시겠습니까? (y/n, 기본: y)"
       - y 선택 시: "ACM 인증서 ARN을 입력해주세요 (없으면 빈 값, 추후 설정)"
   - 비전문가 안내: "로드밸런서는 여러 서버로 트래픽을 분산합니다. ALB는 웹 서비스에, NLB는 게임 서버 등 고성능 연결에 적합합니다."

#### 데이터베이스 질문 흐름 (templates/database.yaml 참조)

1. **DB 엔진 선택**
   - 질문: "필요한 데이터베이스를 선택해주세요 (복수 선택 가능):"
     - `1` PostgreSQL (RDS, 범용 추천)
     - `2` MySQL (RDS)
     - `3` Aurora PostgreSQL (고성능/고가용성)
     - `4` Aurora MySQL (고성능/고가용성)
     - `5` DynamoDB (NoSQL, 서버리스)
     - `6` ElastiCache Redis (캐시/세션)
     - `7` ElastiCache Memcached (단순 캐시)
     - `0` 없음

2. **RDS (PostgreSQL/MySQL) 선택 시:**
   - 인스턴스명 (기본: main-db)
   - 인스턴스 크기:
     - 비전문가: "DB 규모를 선택해주세요: 소규모(db.t3.micro) / 중규모(db.t3.medium, 기본) / 대규모(db.r6g.large)"
     - 전문가: 인스턴스 클래스 직접 입력
   - 스토리지: 초기 크기(기본: 20GB), 최대 크기(기본: 100GB)
   - Multi-AZ: "고가용성(Multi-AZ)이 필요합니까? (y/n)"
     - dev: 기본 n, prod: 기본 y
   - 백업 보관 기간 (기본: 7일)
   - 삭제 보호 (dev: false, prod: true)
   - Performance Insights (기본: true)

3. **Aurora 선택 시:**
   - Serverless v2 사용 여부: "서버리스(자동 스케일링) vs 프로비저닝(고정 용량)"
   - Serverless v2: min/max capacity (기본: 0.5/16 ACU)
   - 프로비저닝: 인스턴스 클래스, 인스턴스 수 (기본: 2)
   - 백업 보관 기간 (기본: 7일)

4. **DynamoDB 선택 시:**
   - 테이블 수 (기본: 1)
   - 각 테이블별:
     - 테이블명
     - 과금 모드: "온디맨드(기본, 예측 불가 트래픽) vs 프로비저닝(예측 가능 트래픽)"
     - 파티션 키(hash key)
     - 정렬 키(range key) 필요 여부
     - TTL 속성 필요 여부
     - Point-in-Time Recovery (기본: true)

5. **ElastiCache 선택 시:**
   - 클러스터명 (기본: app-cache)
   - 노드 타입:
     - 비전문가: "캐시 규모: 소규모(cache.t3.micro) / 중규모(cache.t3.medium, 기본) / 대규모(cache.r6g.large)"
   - 복제 그룹 사용 여부 (Redis만)
   - 복제본 수 (기본: 1)
   - 자동 장애 조치 (기본: true)

#### 스토리지 질문 흐름 (templates/storage.yaml 참조)

1. **S3 버킷**
   - 질문: "S3 버킷이 필요합니까? (y/n, 기본: n)"
   - y 선택 시:
     - 버킷 수 (기본: 1)
     - 각 버킷별:
       - 용도: "정적 자산(웹) / 로그 저장 / 데이터 저장 / 백업"
       - 버킷명 (자동 제안: {project}-{env}-{용도})
       - 버전 관리 (기본: true)
       - 암호화 타입: SSE-S3(기본) / SSE-KMS
       - 수명 주기 정책: "일정 기간 후 자동 삭제/이동이 필요합니까? (y/n)"
         - y 시: 보관 기간 질문

2. **EFS**
   - 질문: "공유 파일 시스템(EFS)이 필요합니까? (컨테이너 간 파일 공유 등) (y/n, 기본: n)"
   - y 선택 시:
     - 파일 시스템명
     - 성능 모드: generalPurpose(기본) / maxIO
     - 수명 주기 정책: "자주 사용하지 않는 파일을 저렴한 스토리지로 이동하시겠습니까? (y/n, 기본: y)"

#### 보안 질문 흐름 (templates/security.yaml 참조)

1. **Account Baseline**
   - 질문: "Account Baseline 보안 설정을 적용하시겠습니까? (S3 퍼블릭 차단, EBS 기본 암호화, IMDSv2 강제) (y/n, 기본: y)"
   - 기본값: true (강력 권장)

2. **WAF**
   - 웹 서비스(ECS/EKS + ALB)가 포함된 경우 자동 질문
   - 질문: "WAF(Web Application Firewall)를 활성화하시겠습니까? (웹 서비스 보호, 권장) (y/n, 기본: y)"
   - y 선택 시: "Rate Limit을 설정하시겠습니까? (기본: 2000 req/5min)"

3. **GuardDuty**
   - 질문: "GuardDuty(위협 탐지)를 활성화하시겠습니까? (y/n, 기본: y)"
   - 기본값: true

4. **Security Hub**
   - 질문: "Security Hub(보안 표준 준수 모니터링)를 활성화하시겠습니까? (y/n, 기본: y)"
   - 기본값: true

5. **SCP** (멀티 어카운트 사용 시에만 질문)
   - 질문: "SCP(서비스 제어 정책)를 적용하시겠습니까? (y/n, 기본: y)"
   - y 선택 시: "적용할 정책을 선택해주세요 (복수 선택):"
     - `1` 루트 계정 사용 차단 (권장)
     - `2` 허용 리전 제한 (권장)
     - `3` 퍼블릭 S3 차단 (권장)
     - `4` 전체 선택

6. **KMS**
   - 질문: "추가 KMS 암호화 키가 필요합니까? (기본 AWS 관리 키 외 커스텀 키) (y/n, 기본: n)"
   - y 선택 시: 키 이름, 용도, 자동 교체 여부

#### 모니터링 질문 흐름 (templates/monitoring.yaml 참조)

1. **CloudTrail**
   - 질문: "CloudTrail(API 호출 로깅)을 활성화하시겠습니까? (y/n, 기본: y)"
   - 기본값: true (보안 필수)
   - 멀티 리전 활성화 여부 (기본: true)

2. **Config**
   - 질문: "AWS Config(리소스 구성 추적)를 활성화하시겠습니까? (y/n, 기본: y)"
   - 기본값: true

3. **CloudWatch 알람**
   - 질문: "인프라 알람 설정이 필요합니까? (CPU, 메모리, 에러율 등) (y/n, 기본: y)"
   - y 선택 시: "알람 알림을 받을 이메일 주소를 입력해주세요"
   - 선택된 컴퓨팅/DB에 맞는 기본 알람 자동 구성 제안

4. **대시보드**
   - 질문: "CloudWatch 대시보드를 생성하시겠습니까? (y/n, 기본: n)"
   - y 선택 시: 선택된 리소스 기반으로 기본 대시보드 자동 구성

### Phase 4: 명세서 생성 (워크로드)

→ "명세서 생성 공통" 섹션의 워크로드 파일 구조 참조

### Phase 5: 확인 및 수정 (워크로드)

→ "확인 및 수정 공통" 섹션 참조

---

## 조직 기반 설정 흐름 (project.type: "org-foundation")

### Phase 1-org: 기본 정보 수집

`templates/_base.yaml` + `templates/organization.yaml`을 참조합니다.
AskUserQuestion 도구를 사용하여 하나씩 질문합니다.

1. **프로젝트 설명**
   - 질문: "조직 구성에 대해 간략히 설명해주세요 (예: ABC Corp 멀티 어카운트 기반 구성)"
   - 기본값: "{project-name} organization foundation"

2. **리전**
   - 질문: "기본 AWS 리전을 선택해주세요 (기본: ap-northeast-2)"
   - 안내: "AWS Organizations, IAM 등 글로벌 서비스는 us-east-1이 자동 포함됩니다"

3. **Management Account ID**
   - 질문: "Management Account ID를 입력해주세요 (12자리 숫자, AWS Organizations를 관리하는 계정)"
   - 검증: 12자리 숫자

4. **Security Account ID**
   - 질문: "Security Account ID를 입력해주세요 (12자리 숫자, GuardDuty/SecurityHub 위임 관리 계정)"
   - 검증: 12자리 숫자

5. **Log Archive Account ID**
   - 질문: "Log Archive Account ID를 입력해주세요 (12자리 숫자, CloudTrail/Config 로그 저장 계정)"
   - 검증: 12자리 숫자
   - 안내: "Security Account와 동일해도 됩니다"

6. **추가 계정 정보**
   - 질문: "추가 계정 ID를 등록하시겠습니까? (Shared Services, Dev, Staging, Prod 등)"
   - y 선택 시: 각 계정의 이름과 ID를 하나씩 입력
   - 안내: "나중에 계정을 추가할 수도 있습니다"

7. **담당 팀 / 이메일 / 비용 센터** (워크로드와 동일)

8. **State 설정**
   - 기본값: `{project-name}-terraform-state-{management-account-id}`

### Phase 2-org: 조직 구조 (OU)

`templates/organization.yaml`의 `organizational_units` 섹션을 참조합니다.

1. **OU 구조 선택**
   - 질문: "OU(Organizational Unit) 구조를 선택해주세요:"
     - `1` **권장 구조** (Core / Infrastructure / Workloads(Dev,Staging,Prod) / Sandbox)
     - `2` **간소화 구조** (Core / Workloads(Dev,Prod))
     - `3` **커스텀** (직접 설계)
   - 비전문가: "OU는 계정을 그룹으로 묶어 보안 정책을 적용하는 단위입니다. 권장 구조를 사용하시겠습니까?"
   - 기본값: 권장 구조

2. **커스텀 선택 시:**
   - 최상위 OU 이름들 입력
   - 각 OU의 하위 OU 필요 여부
   - 복잡한 설계 시 tf-architect 서브에이전트 호출

### Phase 3-org: SCP (Service Control Policies)

`templates/organization.yaml`의 `scps` 섹션을 참조합니다.

1. **SCP 적용 여부**
   - 질문: "SCP(서비스 제어 정책)를 적용하시겠습니까? 계정에서 수행 가능한 작업을 제한합니다. (y/n, 기본: y)"
   - 비전문가: "SCP는 계정에서 할 수 있는 작업의 최대 범위를 제한하는 보안 정책입니다. 예: 루트 사용자 차단, 허용 리전 제한"

2. **SCP 세트 선택**
   - 질문: "적용할 SCP를 선택해주세요 (복수 선택 가능):"
     - `1` 루트 계정 사용 차단 (강력 권장)
     - `2` 허용 리전 제한 (강력 권장)
     - `3` 퍼블릭 S3 버킷 생성 차단 (권장)
     - `4` 조직 탈퇴 차단 (권장)
     - `5` 전체 선택 (기본)
   - 기본값: 전체 선택

3. **허용 리전 선택** ("허용 리전 제한" 선택 시)
   - 질문: "허용할 AWS 리전을 선택해주세요 (기본: ap-northeast-2, us-east-1)"
   - 안내: "us-east-1은 IAM, CloudFront 등 글로벌 서비스에 필요하므로 포함을 권장합니다"

### Phase 4-org: 중앙 보안 서비스

`templates/organization.yaml`의 `centralized_security` 섹션을 참조합니다.

1. **조직 CloudTrail**
   - 질문: "조직 전체 CloudTrail을 활성화하시겠습니까? (모든 계정의 API 로그를 중앙 수집) (y/n, 기본: y)"
   - 비전문가: "CloudTrail은 모든 계정에서 누가 무엇을 했는지 기록합니다. 보안 감사에 필수입니다."
   - y 선택 시: "로그 보관 기간: 30 / 60 / 90(기본) / 365일"

2. **조직 GuardDuty**
   - 질문: "GuardDuty(위협 탐지)를 조직 전체에 활성화하시겠습니까? (y/n, 기본: y)"
   - 비전문가: "GuardDuty는 악의적 활동과 이상 행동을 자동으로 탐지합니다."
   - y 선택 시: "신규 계정 자동 활성화: y/n (기본: y)"

3. **조직 Security Hub**
   - 질문: "Security Hub(보안 표준 모니터링)를 조직 전체에 활성화하시겠습니까? (y/n, 기본: y)"
   - 비전문가: "Security Hub는 보안 모범 사례 준수 여부를 자동으로 평가합니다."
   - y 선택 시: "적용할 보안 표준을 선택해주세요:"
     - `1` AWS Foundational Security (기본, 권장)
     - `2` CIS AWS Foundations (엄격한 보안)
     - `3` 둘 다 (기본)

4. **조직 Config**
   - 질문: "AWS Config를 조직 전체에 활성화하시겠습니까? (리소스 변경 추적) (y/n, 기본: y)"
   - 비전문가: "Config는 누가 어떤 리소스를 변경했는지 기록하고, 규정 준수를 검사합니다."

### Phase 5-org: 공유 네트워크

`templates/organization.yaml`의 `shared_networking` 섹션을 참조합니다.

1. **Transit Gateway**
   - 질문: "계정 간 네트워크 연결(Transit Gateway)이 필요합니까? (y/n, 기본: n)"
   - 비전문가: "Transit Gateway는 여러 계정의 VPC를 하나의 네트워크 허브로 연결합니다. 계정 간 통신이 필요하면 활성화하세요."
   - y 선택 시:
     - "TGW를 공유할 범위: 조직 전체 / 특정 OU만 (기본: 특정 OU)"
     - "Egress VPC(중앙 인터넷 출구)가 필요합니까? (y/n, 기본: n)"
       - 비전문가: "Egress VPC를 사용하면 모든 계정의 인터넷 트래픽이 하나의 VPC를 통해 나갑니다. NAT Gateway 비용을 절감할 수 있습니다."
   - 복잡한 네트워크 토폴로지 시 tf-architect 서브에이전트 호출

### Phase 6-org: Account Baseline

`templates/organization.yaml`의 `account_baseline` 섹션을 참조합니다.

1. **Account Baseline 적용**
   - 질문: "Account Baseline 보안 설정을 모든 계정에 적용하시겠습니까? (S3 퍼블릭 차단, EBS 암호화, IMDSv2 강제) (y/n, 기본: y)"
   - 비전문가: "모든 계정에 기본 보안 설정을 자동 적용합니다. 강력히 권장합니다."

2. **TerraformExecutionRole**
   - 질문: "각 계정에 Terraform 실행용 IAM Role을 자동 생성하시겠습니까? (y/n, 기본: y)"
   - 안내: "Management Account에서 AssumeRole로 다른 계정의 리소스를 관리합니다."

### Phase 7-org: SSM Export

`templates/organization.yaml`의 `ssm_exports` 섹션을 참조합니다.

1. **SSM Export 확인**
   - 안내: "org-foundation에서 생성한 리소스 정보를 SSM Parameter Store에 기록합니다. 이후 워크로드 프로젝트에서 이 값들을 참조합니다."
   - 자동 export 항목 목록 표시:
     ```
     /org/organization-id        → Organization ID
     /org/accounts/management    → Management Account ID
     /org/accounts/security      → Security Account ID
     /org/accounts/{name}        → 각 계정 ID
     /org/networking/tgw-id      → Transit Gateway ID (TGW 활성화 시)
     /org/logging/cloudtrail-bucket → CloudTrail S3 버킷명
     /org/kms/{name}             → KMS Key ARN
     ```
   - 질문: "SSM Export prefix를 변경하시겠습니까? (기본: /org)"

### Phase 8-org: 명세서 생성

→ "명세서 생성 공통" 섹션의 org-foundation 파일 구조 참조

### Phase 9-org: 확인 및 수정

→ "확인 및 수정 공통" 섹션 참조

---

## 명세서 생성 공통

### 파일 생성 규칙

1. `templates/_base.yaml`을 읽고, 수집된 기본 정보로 값을 채웁니다.
2. 선택된 카테고리/섹션의 템플릿 파일을 각각 읽습니다.
3. 사용자 응답에 따라 `enabled: true/false`를 설정하고, 세부 값을 채웁니다.
4. 선택되지 않은 카테고리는 파일에 포함하지 않습니다.
5. 비활성화된 하위 항목은 `enabled: false`로 유지하되, 주석 처리된 예시는 제거합니다.

### specs 디렉토리 확인

specs 디렉토리가 없으면 자동으로 생성합니다:
```bash
mkdir -p specs
```

### 워크로드 spec 파일 구조

```yaml
# =============================================================================
# Infrastructure Spec - {project-name}
# =============================================================================
# Auto-generated by /tf-spec
# Generated: {YYYY-MM-DD HH:MM:SS}
# Type: workload
# Environment: {environment}
# Region: {region}
# Account: {account_id}
# =============================================================================

project:
  name: "{project-name}"
  type: "workload"
  description: "{description}"
  environment: "{environment}"
  region: "{region}"
  account_id: "{account_id}"
  multi_account:
    enabled: {true/false}
    # ...

owner:
  team: "{team}"
  # ...

state:
  backend: "s3"
  # ...

# 선택된 카테고리만 포함
networking:
  # ...
compute:
  # ...
```

### org-foundation spec 파일 구조

```yaml
# =============================================================================
# Infrastructure Spec - {project-name}
# =============================================================================
# Auto-generated by /tf-spec
# Generated: {YYYY-MM-DD HH:MM:SS}
# Type: org-foundation
# Region: {region}
# Management Account: {management_account_id}
# =============================================================================

project:
  name: "{project-name}"
  type: "org-foundation"
  description: "{description}"
  environment: "management"
  region: "{region}"
  account_id: "{management_account_id}"
  multi_account:
    enabled: true
    # ...

owner:
  team: "{team}"
  # ...

state:
  backend: "s3"
  # ...

organization:
  # ...
organizational_units:
  # ...
scps:
  # ...
accounts:
  # ...
delegated_administrators:
  # ...
centralized_security:
  # ...
shared_networking:
  # ...
account_baseline:
  # ...
ssm_exports:
  # ...
```

---

## 확인 및 수정 공통

1. 생성된 spec의 요약을 표 형태로 출력합니다. (타입에 따라 포맷 다름)

2. AskUserQuestion으로 확인 요청:
   - "위 명세서를 확인해주세요. 수정할 부분이 있으시면 말씀해주세요. 확정하려면 '확인' 또는 'ok'를 입력해주세요."

3. 수정 요청 시:
   - 해당 부분만 AskUserQuestion으로 재질문
   - 변경 사항을 spec 파일에 반영
   - 수정된 요약 재출력

4. 확정 시 안내 메시지:
```
명세서가 확정되었습니다: specs/{project-name}-spec.yaml

다음 단계:
  /tf-build specs/{project-name}-spec.yaml     ← 코드 생성 + 리뷰를 한번에 (권장)
  /tf-generate specs/{project-name}-spec.yaml  ← 코드만 생성 (이후 /tf-review로 별도 리뷰)
```

---

## Expert Mode

```
/tf-spec my-service --from templates/networking.yaml,templates/compute.yaml
```

`--from` 옵션으로 카테고리를 미리 지정하면 Phase 2를 건너뛰고 바로 Phase 3로 진입합니다.
Phase 0의 프로젝트 타입은 `workload`로 자동 설정됩니다.
Phase 1의 기본 정보 수집은 여전히 수행됩니다.

org-foundation 전용 단축:
```
/tf-spec my-org --type org-foundation
```
`--type org-foundation` 옵션으로 Phase 0을 건너뛰고 바로 Phase 1-org로 진입합니다.

사용 가능한 카테고리 파일:
- `templates/networking.yaml`
- `templates/compute.yaml`
- `templates/database.yaml`
- `templates/storage.yaml`
- `templates/security.yaml`
- `templates/monitoring.yaml`
- `templates/organization.yaml`

## Argument Parsing

$ARGUMENTS에서 프로젝트명과 옵션을 파싱합니다:
```
입력: "my-service --from templates/networking.yaml,templates/compute.yaml"
→ project_name: "my-service"
→ project_type: "workload"
→ from_templates: ["templates/networking.yaml", "templates/compute.yaml"]

입력: "my-org --type org-foundation"
→ project_name: "my-org"
→ project_type: "org-foundation"
→ from_templates: []

입력: "payment-api"
→ project_name: "payment-api"
→ project_type: null (Phase 0에서 선택)
→ from_templates: [] (Phase 2에서 선택)
```

프로젝트명이 없으면 AskUserQuestion으로 질문합니다:
- "프로젝트 식별자를 입력해주세요 (예: my-web-service, my-org)"

## MCP 서버 활용

각 질문 단계에서 MCP 서버를 활용하여 정확한 정보를 제공합니다.

### Terraform MCP (`awslabs.terraform-mcp-server`)
- **리소스 속성 검증**: 사용자가 입력한 값(인스턴스 타입, 엔진 버전, 파라미터 등)이 실제 Terraform Provider에서 지원되는지 확인
- **최신 기본값 확인**: EKS 버전, RDS 엔진 버전, Lambda 런타임 등 자주 변경되는 기본값을 최신으로 제공
- **활용 시점**: Phase 3(카테고리별 상세 질문) 중 컴퓨팅/DB/네트워크 세부 설정 질문 시
  ```
  예: EKS 버전 질문 전 → Terraform MCP로 aws_eks_cluster의 지원 버전 확인
  예: RDS 엔진 선택 시 → Terraform MCP로 aws_db_instance의 engine_version 옵션 확인
  ```

### AWS Documentation MCP (`awslabs.aws-documentation-mcp-server`)
- **서비스 제한/할당량 안내**: 리전별 가용영역 수, 계정별 VPC 한도, SCP 한도 등
- **베스트 프랙티스 참조**: Organizations OU 구조, SCP 작성, Transit Gateway 설계 권장 사항
- **활용 시점**: Phase 2-org(OU 구조), Phase 3-org(SCP), Phase 5-org(공유 네트워크) 등 조직 설계 질문 시
  ```
  예: OU 구조 질문 시 → AWS Docs에서 Organizations 베스트 프랙티스 참조
  예: SCP 작성 시 → AWS Docs에서 SCP 예제 및 제한 사항 참조
  ```

### Well-Architected Security MCP (`awslabs.well-architected-security-mcp-server`)
- **보안 권장 사항 제공**: Security Hub 표준, GuardDuty 구성, CloudTrail 설정 관련 권장 사항
- **활용 시점**: Phase 4-org(중앙 보안), 워크로드 보안 질문(Phase 3 보안 카테고리) 시
  ```
  예: Security Hub 표준 선택 시 → Well-Architected Security에서 권장 표준 확인
  예: Account Baseline 설정 시 → Security Pillar 체크리스트 참조
  ```

## Guidelines

- **한 번에 하나의 질문만** 합니다. 여러 질문을 한꺼번에 하지 마세요.
- **AskUserQuestion 도구**를 적극 활용하여 선택지를 제공합니다.
- 모든 질문에 **기본값을 명시**합니다. 사용자가 빈 입력을 하면 기본값을 적용합니다.
- 비전문가에게는 **기술 용어 대신 목적 기반 설명**을 사용합니다.
  - 예: "CIDR 블록" 대신 "네트워크 규모"
  - 예: "Multi-AZ" 대신 "고가용성(서버 장애 시 자동 복구)"
  - 예: "Fargate" 대신 "서버리스 컨테이너(서버 관리 불필요)"
  - 예: "SCP" 대신 "계정 보안 정책(할 수 있는 작업의 최대 범위 제한)"
  - 예: "Transit Gateway" 대신 "계정 간 네트워크 연결 허브"
- CIDR, 리전, 인스턴스 타입, 계정 ID 등은 **유효성을 검증**합니다.
  - 잘못된 입력 시 이유를 설명하고 재입력 요청
- **환경별 기본값 차별화** (워크로드):
  - dev: 비용 최적화 (단일 AZ NAT, 소규모 인스턴스, Multi-AZ 미사용)
  - staging: dev와 동일하되 prod과 비슷한 구조
  - prod: 고가용성 (다중 AZ NAT, 대규모 인스턴스, Multi-AZ, 삭제 보호)
- **org-foundation 기본값**: 보안 최우선 (SCP 전체 활성, 보안 서비스 전체 활성, 기본 암호화)
- **이전 선택에 따른 조건부 질문**: 불필요한 질문은 건너뜁니다.
  - 예: Private Only 서브넷 선택 시 NAT Gateway 질문 생략
  - 예: Lambda만 선택 시 Auto Scaling 질문 생략
  - 예: TGW 비활성화 시 라우트 테이블/RAM 공유 질문 생략
- **복잡한 설계 판단**이 필요한 경우 tf-architect 서브에이전트를 호출하여 권장 사항을 제공합니다.
- spec 파일 생성 시 반드시 해당 카테고리의 **템플릿 파일을 읽어서** 정확한 YAML 구조를 따릅니다.
- 사용자가 중간에 이전 단계를 수정하고 싶다고 하면 해당 단계로 돌아갑니다.

## Error Handling

- 프로젝트명 미입력: AskUserQuestion으로 재질문
- 잘못된 계정 ID: 12자리 숫자가 아닌 경우 재입력 요청
- 잘못된 CIDR: RFC 1918 범위(10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) 외 입력 시 경고
- 잘못된 리전: AWS 리전 코드 목록과 대조하여 검증
- specs 디렉토리 미존재: 자동 생성
- 동일 파일명 존재: 덮어쓸지 AskUserQuestion으로 확인
