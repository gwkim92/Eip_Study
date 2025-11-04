# EIP 학습 가이드

스마트 컨트랙트 개발자를 위한 단계별 EIP 학습 로드맵

---

## 목차

1. [프로젝트 개요](#프로젝트-개요)
2. [학습 전 준비사항](#학습-전-준비사항)
3. [학습 로드맵](#학습-로드맵)
4. [각 단계별 상세 가이드](#각-단계별-상세-가이드)
5. [실습 프로젝트](#실습-프로젝트)
6. [FAQ](#faq)

---

## 프로젝트 개요

### 전체 EIP 목록 (총 17개)

이 저장소는 4개의 카테고리로 구성되어 있으며, 총 **31개의 스마트 컨트랙트**와 **5개의 테스트 파일**을 포함합니다.

#### 📌 Essential (필수) - 5개
모든 스마트 컨트랙트 개발자가 반드시 알아야 하는 핵심 EIP
- **EIP-712**: Typed Structured Data Hashing (오프체인 서명)
- **EIP-2612**: Permit - Gasless Approval (가스비 없는 승인)
- **EIP-1967**: Proxy Storage Slots (업그레이드 가능한 컨트랙트)
- **EIP-2535**: Diamond Pattern (24KB 제한 우회)
- **EIP-1271**: Contract Signature Validation (스마트 컨트랙트 지갑)

#### ⭐ Very Important (매우 중요) - 5개
프로덕션급 개발에 필요한 표준들
- **EIP-1559**: New Gas Model (동적 가스 모델)
- **EIP-165**: Interface Detection (인터페이스 감지)
- **EIP-2981**: NFT Royalty Standard (NFT 로열티)
- **EIP-4626**: Tokenized Vault Standard (볼트 표준)
- **EIP-5192**: Soulbound Tokens (양도 불가능 토큰)

#### 💡 Good-to-Know (알면 좋음) - 4개
고급 최적화와 특수 케이스
- **EIP-1153**: Transient Storage (임시 스토리지)
- **EIP-2930**: Access Lists (트랜잭션 최적화)
- **EIP-3529**: Gas Refund Reduction (가스 환불 변경)
- **EIP-7201**: Namespaced Storage Layout (네임스페이스 스토리지)

#### 🚀 Future (미래 대비) - 3개
차세대 이더리움 기능
- **EIP-4337**: Account Abstraction (계정 추상화)
- **EIP-4844**: Blob Transactions (데이터 가용성 레이어)
- **EIP-7702**: Set Code for EOAs (EOA에 코드 설정)

### 학습 통계
- **총 Solidity 파일**: 31개
- **총 테스트 파일**: 5개 (Essential 카테고리)
- **총 문서**: 19개 README
- **예상 학습 기간**: 4-12주 (깊이에 따라)

---

## 학습 전 준비사항

### 필수 지식
- Solidity 기본 문법 (0.8.x)
- ERC-20, ERC-721 표준 이해
- 스마트 컨트랙트 배포 경험
- Ethers.js 또는 Web3.js 기본 사용법

### 개발 환경
```bash
# 1. Foundry 설치 (권장)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 2. 또는 Hardhat
npm install --save-dev hardhat

# 3. OpenZeppelin 라이브러리
npm install @openzeppelin/contracts
```

### 추천 도구
- **IDE**: VSCode + Solidity Extension
- **테스트넷**: Sepolia (무료 ETH: https://sepoliafaucet.com/)
- **블록 탐색기**: Etherscan
- **지갑**: MetaMask

---

## 학습 로드맵

### 권장 학습 순서

#### 🎯 단계별 학습 경로

**초보자를 위한 순서 (난이도 순)**
```
Phase 1 (기초): EIP-165 → EIP-712 → EIP-2612
Phase 2 (중급): EIP-1559 → EIP-1967 → EIP-1271
Phase 3 (고급): EIP-2535 → EIP-2981 → EIP-4626 → EIP-5192
Phase 4 (최적화): EIP-1153 → EIP-7201 → EIP-2930 → EIP-3529
Phase 5 (미래): EIP-4337 → EIP-7702 → EIP-4844
```

**프로젝트 타입별 추천 순서**

**NFT 개발자**
```
1. EIP-165 (인터페이스 감지) ⭐
2. EIP-712 (서명) ⭐
3. EIP-2981 (로열티) ⭐
4. EIP-5192 (Soulbound)
5. EIP-1271 (컨트랙트 지갑)
6. EIP-1967 (업그레이드)
```

**DeFi 개발자**
```
1. EIP-712 (서명) ⭐
2. EIP-2612 (Permit) ⭐
3. EIP-4626 (Vault) ⭐
4. EIP-1967 (프록시) ⭐
5. EIP-2535 (Diamond)
6. EIP-1559 (가스 모델)
7. EIP-1153 (Transient Storage)
```

**지갑/인프라 개발자**
```
1. EIP-1271 (컨트랙트 서명) ⭐
2. EIP-712 (타입 데이터) ⭐
3. EIP-1559 (가스) ⭐
4. EIP-4337 (Account Abstraction) ⭐
5. EIP-7702 (EOA 코드)
```

### 4주 완성 플랜

```
Week 1: Essential 기초 - EIP-712, EIP-2612, EIP-165
Week 2: Essential 고급 - EIP-1967, EIP-2535, EIP-1271
Week 3: Very Important - EIP-1559, EIP-2981, EIP-4626, EIP-5192
Week 4: 실습 프로젝트 + Good-to-Know 선택 학습
```

### 8주 완성 플랜 (권장)

```
Week 1-2: Essential (필수) 5개 - 깊이 있게 학습
Week 3-4: Very Important (매우 중요) 5개 - 프로젝트 적용
Week 5-6: 종합 프로젝트 - 배운 내용 통합
Week 7: Good-to-Know (알면 좋음) - 최적화 기법
Week 8: Future (미래 대비) - 차세대 기술 탐구
```

---

## 각 단계별 상세 가이드

---

## WEEK 1: Essential EIP (Part 1)

### Day 1-2: EIP-712 (Typed Structured Data Hashing)

#### 학습 목표
- 오프체인 서명의 필요성 이해
- EIP-712 구조 (Domain Separator, TypeHash) 숙지
- 실제 서명 생성 및 검증 구현

#### 학습 순서
1. **이론** (30분)
   - `eips/essential/EIP-712/README.md` 읽기
   - 문제점과 해결책 이해
   - Domain Separator 개념 파악

2. **코드 읽기** (1시간)
   ```bash
   # 기본 구현
   cat eips/essential/EIP-712/contracts/EIP712Example.sol

   # OpenZeppelin 버전
   cat eips/essential/EIP-712/contracts/EIP712WithOpenZeppelin.sol
   ```

3. **실습** (2시간)
   ```solidity
   // 과제 1: 간단한 투표 시스템에 EIP-712 적용
   // - Vote 구조 정의
   // - Domain Separator 설정
   // - 서명 검증 구현
   ```

4. **테스트** (1시간)
   ```javascript
   // ethers.js로 서명 생성 및 검증
   // - MetaMask 연동
   // - signTypedData 사용
   // - 서명 검증 확인
   ```

#### 체크리스트
- [ ] Domain Separator의 역할을 설명할 수 있다
- [ ] TypeHash를 직접 계산할 수 있다
- [ ] 프론트엔드에서 서명을 생성할 수 있다
- [ ] 컨트랙트에서 서명을 검증할 수 있다
- [ ] 재사용 공격 방지 방법을 안다 (nonce, deadline)

---

### Day 3-4: EIP-2612 (Permit - Gasless Approval)

#### 학습 목표
- Permit 패턴의 UX 개선 효과 이해
- EIP-712와의 통합 방법 숙지
- 실제 DApp에 적용

#### 학습 순서
1. **이론** (30분)
   - `eips/essential/EIP-2612/README.md` 읽기
   - approve() 문제점 이해
   - 가스비 절감 효과 확인

2. **코드 읽기** (1시간)
   ```bash
   cat eips/essential/EIP-2612/contracts/ERC20Permit.sol
   cat eips/essential/EIP-2612/contracts/DAppWithPermit.sol
   ```

3. **실습** (2시간)
   ```solidity
   // 과제 2: Permit을 사용하는 스테이킹 컨트랙트
   // - ERC20Permit 토큰 생성
   // - stakeWithPermit() 함수 구현
   // - 한 번의 트랜잭션으로 approve + stake
   ```

4. **통합 테스트** (1시간)
   ```javascript
   // 전체 플로우 테스트
   // 1. 서명 생성 (오프체인)
   // 2. permit + stake (온체인)
   // 3. 가스비 비교 (기존 vs Permit)
   ```

#### 체크리스트
- [ ] Permit과 일반 approve의 차이를 설명할 수 있다
- [ ] permitWithSign 플로우를 구현할 수 있다
- [ ] Front-running 위험을 이해하고 대응할 수 있다
- [ ] try-catch로 안전한 permit을 구현할 수 있다

---

## WEEK 2: Essential EIP (Part 2)

### Day 5-6: EIP-1967 (Proxy Storage Slots)

#### 학습 목표
- 프록시 패턴의 필요성 이해
- 스토리지 충돌 문제 해결
- 안전한 업그레이드 가능 컨트랙트 작성

#### 학습 순서
1. **이론** (1시간)
   - `eips/essential/EIP-1967/README.md` 읽기
   - 스토리지 충돌 시나리오 이해
   - EIP-1967 표준 슬롯 이해

2. **코드 읽기** (2시간)
   ```bash
   cat eips/essential/EIP-1967/contracts/EIP1967Proxy.sol
   cat eips/essential/EIP-1967/contracts/LogicContracts.sol
   cat eips/essential/EIP-1967/contracts/ProxyAdmin.sol
   ```

3. **실습** (3시간)
   ```solidity
   // 과제 3: 업그레이드 가능한 NFT 마켓플레이스
   // - V1: 기본 구매/판매 기능
   // - V2: 경매 기능 추가
   // - 스토리지 레이아웃 유지하며 업그레이드
   ```

4. **디버깅 연습** (1시간)
   ```solidity
   // 잘못된 업그레이드 시나리오 분석
   // - 스토리지 순서 변경
   // - 타입 변경
   // - 어떤 문제가 발생하는지 확인
   ```

#### 체크리스트
- [ ] IMPLEMENTATION_SLOT, ADMIN_SLOT 값을 계산할 수 있다
- [ ] delegatecall의 동작 원리를 이해한다
- [ ] 안전한 스토리지 레이아웃 규칙을 안다
- [ ] ProxyAdmin 패턴을 구현할 수 있다
- [ ] Initializer 패턴을 이해한다

---

### Day 7-8: EIP-2535 (Diamond Pattern)

#### 학습 목표
- 24KB 컨트랙트 크기 제한 이해
- Diamond Pattern의 구조 파악
- 대규모 시스템 설계 능력 향상

#### 학습 순서
1. **이론** (1시간)
   - `eips/essential/EIP-2535/README.md` 읽기
   - Diamond의 필요성 이해
   - Facet, DiamondCut 개념 학습

2. **코드 읽기** (3시간)
   ```bash
   # 핵심 구조
   cat eips/essential/EIP-2535/contracts/Diamond.sol
   cat eips/essential/EIP-2535/contracts/LibDiamond.sol

   # Facet 예제
   cat eips/essential/EIP-2535/contracts/ExampleFacets.sol

   # 관리
   cat eips/essential/EIP-2535/contracts/DiamondCutFacet.sol
   ```

3. **실습** (4시간)
   ```solidity
   // 과제 4: Diamond 기반 DeFi 프로토콜
   // - TokenFacet: ERC20 기능
   // - SwapFacet: DEX 기능
   // - GovernanceFacet: 거버넌스
   // - AppStorage로 데이터 공유
   ```

4. **배포 및 테스트** (2시간)
   ```javascript
   // Diamond 배포 스크립트 작성
   // Facet 추가/교체/제거 테스트
   // Function selector 충돌 처리
   ```

#### 체크리스트
- [ ] Diamond와 일반 Proxy의 차이를 설명할 수 있다
- [ ] Function selector 기반 라우팅을 이해한다
- [ ] AppStorage 패턴을 적용할 수 있다
- [ ] DiamondCut으로 Facet을 관리할 수 있다
- [ ] Diamond를 실제 프로젝트에 적용할 수 있다

---

### Day 9-10: EIP-1271 (Contract Signature Validation)

#### 학습 목표
- 스마트 컨트랙트 지갑 이해
- EIP-1271 매직 값 개념
- Gnosis Safe 패턴 학습

#### 학습 순서
1. **이론** (30분)
   - `eips/essential/EIP-1271/README.md` 읽기
   - `eips/essential/EIP-1271/QUICK_START.md` 따라하기

2. **코드 읽기** (2시간)
   ```bash
   cat eips/essential/EIP-1271/contracts/EIP1271Example.sol
   cat eips/essential/EIP-1271/contracts/MultiSigWallet.sol
   cat eips/essential/EIP-1271/contracts/SessionKeyWallet.sol
   ```

3. **실습** (2시간)
   ```solidity
   // 과제 5: 2-of-3 멀티시그 지갑
   // - 3명의 소유자
   // - 2명의 서명으로 실행
   // - EIP-1271로 서명 검증
   ```

4. **통합** (1시간)
   ```solidity
   // EIP-712 + EIP-1271 통합
   // - 구조화된 데이터에 멀티시그 서명
   // - DApp에서 컨트랙트 지갑 지원
   ```

#### 체크리스트
- [ ] 0x1626ba7e 매직 값의 의미를 안다
- [ ] EOA와 컨트랙트 지갑의 차이를 설명할 수 있다
- [ ] 멀티시그 검증 로직을 구현할 수 있다
- [ ] Session Key 패턴을 이해한다

---

## WEEK 3: Very Important EIP

### Day 11-12: EIP-1559, EIP-165

#### EIP-1559 (New Gas Model)
1. **학습** (2시간)
   - Base Fee vs Priority Fee 이해
   - 가스 추정 전략 학습

2. **실습** (2시간)
   ```javascript
   // ethers.js로 EIP-1559 트랜잭션
   // - maxFeePerGas 설정
   // - maxPriorityFeePerGas 설정
   // - 가스비 예측 알고리즘 구현
   ```

#### EIP-165 (Interface Detection)
1. **학습** (1시간)
   - supportsInterface 패턴
   - Interface ID 계산

2. **실습** (1시간)
   ```solidity
   // 과제: 다중 인터페이스 지원 컨트랙트
   // - ERC721 + ERC2981
   // - 각각의 interfaceId 반환
   ```

---

### Day 13-14: EIP-2981, EIP-4626

#### EIP-2981 (NFT Royalty)
1. **학습** (1시간)
   - royaltyInfo 구현
   - 마켓플레이스 통합

2. **실습** (2시간)
   ```solidity
   // 과제: 로열티 지원 NFT 마켓플레이스
   // - NFT 판매 시 로열티 자동 분배
   // - 크리에이터/판매자 수익 분리
   ```

#### EIP-4626 (Tokenized Vault)
1. **학습** (1시간)
   - Vault 표준 이해
   - Share 계산 로직

2. **실습** (2시간)
   ```solidity
   // 과제: 이자 발생 Vault
   // - USDC 예치
   // - 시간에 따른 이자 계산
   // - Share/Asset 변환
   ```

---

### Day 15-16: EIP-5192 + 종합 복습

#### EIP-5192 (Soulbound Token)
1. **학습** (1시간)
   - Soulbound 개념
   - locked() 구현

2. **실습** (2시간)
   ```solidity
   // 과제: 교육 자격증 시스템
   // - 전송 불가 NFT
   // - 메타데이터로 학위 정보 저장
   ```

#### 종합 복습 (2시간)
- Week 1-3 내용 정리
- 각 EIP의 사용 시나리오 복습
- 질의응답

---

## WEEK 4: 실습 프로젝트

### 최종 프로젝트: 종합 DApp 구축

#### 프로젝트 목표
다음 EIP들을 모두 활용하는 실전 DApp 구축

#### 프로젝트 아이디어

**Option 1: NFT 마켓플레이스**
```
- EIP-712: 오프체인 주문 서명
- EIP-2612: Permit으로 토큰 결제
- EIP-165: 인터페이스 확인
- EIP-2981: 로열티 자동 분배
- EIP-1271: 컨트랙트 지갑 지원
- EIP-1967: 업그레이드 가능한 구조
```

**Option 2: DeFi 프로토콜**
```
- EIP-4626: Vault 표준 적용
- EIP-2612: 가스비 없는 예치
- EIP-712: 거버넌스 투표
- EIP-2535: Diamond로 모듈화
- EIP-1967: 안전한 업그레이드
```

**Option 3: DAO 플랫폼**
```
- EIP-712: 오프체인 투표
- EIP-1271: 조직 지갑
- EIP-5192: 멤버십 증명 (SBT)
- EIP-2535: 확장 가능한 구조
- EIP-2612: 토큰 투표
```

#### 개발 단계

**Day 17-18: 설계 및 컨트랙트 개발**
1. 아키텍처 설계
2. 스마트 컨트랙트 작성
3. 단위 테스트

**Day 19-20: 프론트엔드 개발**
1. React + ethers.js
2. 서명 플로우 구현
3. 통합 테스트

**Day 21: 배포 및 검증**
1. Sepolia 테스트넷 배포
2. Etherscan 검증
3. 실제 동작 테스트

**Day 22: 문서화 및 발표**
1. README 작성
2. 사용 가이드
3. 학습 내용 정리

---

## Good-to-Know (알면 좋음): 가스 최적화 & 고급 패턴

이 섹션의 EIP들은 필수는 아니지만, 가스 최적화와 고급 스토리지 패턴을 배우려면 학습을 권장합니다.

### EIP-1153: Transient Storage

#### 개요
블록 내에서만 유효한 임시 스토리지로, 가스 비용을 크게 절감할 수 있습니다.

#### 언제 사용하나요?
- 재진입 가드 (Reentrancy Guard)
- 플래시론 상태 관리
- 임시 권한 설정

#### 학습 리소스
```bash
# 컨트랙트 위치
eips/good-to-know/EIP-1153/contracts/TransientStorageExample.sol
eips/good-to-know/EIP-1153/README.md
```

#### 실습 아이디어
```solidity
// 가스 비교: SSTORE vs TSTORE
// 재진입 가드를 TSTORE로 구현
```

---

### EIP-7201: Namespaced Storage Layout

#### 개요
프록시 패턴에서 스토리지 충돌을 방지하는 네임스페이스 규칙입니다.

#### 언제 사용하나요?
- Diamond Pattern과 함께 사용
- 복잡한 프록시 시스템
- 라이브러리 개발

#### 학습 리소스
```bash
eips/good-to-know/EIP-7201/contracts/NamespacedStorageExample.sol
eips/good-to-know/EIP-7201/README.md
```

#### EIP-1967과의 차이
- **EIP-1967**: 고정 슬롯 (프록시 메타데이터용)
- **EIP-7201**: 네임스페이스 기반 동적 슬롯 (앱 데이터용)

---

### EIP-2930: Access Lists

#### 개요
트랜잭션에 접근할 주소와 스토리지 키를 미리 선언하여 가스를 절감합니다.

#### 언제 사용하나요?
- 복잡한 DeFi 트랜잭션
- 가스 최적화가 중요한 경우
- 예측 가능한 스토리지 접근

#### 학습 리소스
```bash
eips/good-to-know/EIP-2930/README.md
```

#### 실습 방법
```javascript
// ethers.js로 Access List 생성
const accessList = await provider.send("eth_createAccessList", [{
  from: sender,
  to: contract,
  data: calldata
}]);
```

---

### EIP-3529: Gas Refund Reduction

#### 개요
SELFDESTRUCT와 SSTORE 환불 메커니즘의 변경 사항을 이해합니다.

#### 왜 중요한가요?
- Gas Token 전략 무효화
- 스토리지 정리 패턴 변경
- 가스 최적화 전략 재구성

#### 학습 리소스
```bash
eips/good-to-know/EIP-3529/README.md
```

---

## Future (미래 대비): 차세대 이더리움

### EIP-4337: Account Abstraction

#### 개요
EOA 없이 스마트 컨트랙트만으로 지갑을 구현하는 표준입니다.

#### 왜 배워야 하나요?
- Web2 수준의 UX 제공
- 소셜 로그인, 생체 인증 가능
- 가스비 대납, 배치 트랜잭션
- 미래의 지갑 표준

#### 핵심 개념
- **UserOperation**: 사용자 의도를 표현
- **Bundler**: UserOp를 모아서 실행
- **EntryPoint**: 진입점 컨트랙트
- **Paymaster**: 가스비 대납

#### 학습 리소스
```bash
eips/future/EIP-4337/contracts/AccountAbstractionExample.sol
eips/future/EIP-4337/README.md
```

#### 실습 프로젝트
```solidity
// 소셜 리커버리 지갑 구현
// - 이메일로 복구 가능
// - 월별 지출 한도 설정
// - 2FA 통합
```

---

### EIP-7702: Set Code for EOAs

#### 개요
EOA가 일시적으로 스마트 컨트랙트 코드를 실행할 수 있게 합니다.

#### EIP-4337과의 차이
- **EIP-4337**: 새로운 지갑 표준
- **EIP-7702**: 기존 EOA를 스마트 지갑처럼 사용

#### 사용 사례
- 기존 지갑에 배치 트랜잭션 추가
- 임시로 멀티시그 기능 활성화
- 하위 호환성 유지

#### 학습 리소스
```bash
eips/future/EIP-7702/contracts/EIP7702Example.sol
eips/future/EIP-7702/README.md
```

---

### EIP-4844: Blob Transactions (Proto-Danksharding)

#### 개요
L2 롤업을 위한 저렴한 데이터 가용성 레이어입니다.

#### 왜 중요한가요?
- L2 트랜잭션 비용 90% 이상 감소
- 이더리움 확장성의 핵심
- 향후 Full Danksharding의 기초

#### 핵심 개념
- **Blob**: 128KB 데이터 덩어리
- **KZG Commitment**: 데이터 검증
- **Blob Gas**: 별도의 가스 시장

#### 누구를 위한 EIP인가?
- L2 개발자
- 롤업 운영자
- 인프라 개발자

#### 학습 리소스
```bash
eips/future/EIP-4844/README.md
```

---

## 실습 프로젝트

### 프로젝트 1: Meta-Transaction DApp (초급)
```
기간: 2-3일
난이도: 초급

사용 EIP:
- EIP-712: 서명
- EIP-2612: Permit

목표:
- 가스비 대납 시스템
- 사용자는 서명만 생성
- Relayer가 트랜잭션 전송
```

### 프로젝트 2: Upgradeable NFT Marketplace (중급)
```
기간: 4-5일
난이도: 중급

사용 EIP:
- EIP-1967: Proxy
- EIP-165: Interface Detection
- EIP-2981: Royalty
- EIP-712: Order Signing

목표:
- 업그레이드 가능한 마켓플레이스
- 로열티 자동 분배
- 오프체인 주문
```

### 프로젝트 3: Diamond DeFi Protocol (고급)
```
기간: 7-10일
난이도: 고급

사용 EIP:
- EIP-2535: Diamond Pattern
- EIP-4626: Vault Standard
- EIP-712: Signature
- EIP-2612: Permit
- EIP-1271: Contract Wallet

목표:
- 완전한 DeFi 프로토콜
- 모듈식 구조
- 컨트랙트 지갑 지원
```

---

## FAQ

### Q1: 이 EIP들을 모두 배워야 하나요?
**A**: 필수(Essential) 5개는 반드시 학습하세요. 나머지는 프로젝트 필요에 따라 선택적으로 학습하면 됩니다.

### Q2: 얼마나 시간이 걸리나요?
**A**:
- 집중 학습: 4주
- 여유있게: 8-12주
- 실무 병행: 3-6개월

### Q3: 선수 지식이 부족한데 시작해도 되나요?
**A**: Solidity 기본과 ERC-20/721 표준은 필수입니다. 먼저 학습 후 시작하세요.

### Q4: 어떤 EIP를 먼저 배워야 하나요?
**A**: 프로젝트 타입에 따라 다릅니다:

**범용 추천 순서**:
1. EIP-165 (가장 쉬움, 인터페이스)
2. EIP-712 (서명 기초)
3. EIP-2612 (EIP-712 활용)
4. EIP-1559 (가스 모델 이해)
5. EIP-1967 (프록시 패턴)
6. 나머지 필요에 따라

**빠른 시작**: [학습 로드맵](#학습-로드맵) 섹션의 프로젝트 타입별 순서를 참고하세요.

### Q5: 실전에서 가장 많이 쓰이는 EIP는?
**A**:
1. EIP-712: 거의 모든 DApp
2. EIP-1967: 업그레이드가 필요한 프로젝트
3. EIP-2612: 토큰을 사용하는 모든 DApp
4. EIP-165: NFT/토큰 프로젝트

### Q6: OpenZeppelin을 써도 되나요?
**A**: 네! 프로덕션에서는 OpenZeppelin 사용을 권장합니다. 하지만 학습 시에는 직접 구현해보는 것이 중요합니다.

### Q7: 테스트는 어떻게 하나요?
**A**:
```bash
# Foundry (권장)
forge test

# Hardhat
npx hardhat test
```

### Q8: 막혔을 때 어디서 도움을 받나요?
**A**:
- OpenZeppelin Forum
- Ethereum StackExchange
- Discord 커뮤니티
- GitHub Issues

### Q9: Good-to-Know와 Future EIP는 언제 배워야 하나요?
**A**:
- **Good-to-Know**: Essential과 Very Important를 마친 후, 가스 최적화가 필요할 때
- **Future**: 새로운 지갑 UX나 L2 개발에 관심이 있다면 우선 학습
- 실무에서 필요할 때 Just-in-Time으로 학습해도 충분합니다

### Q10: 각 카테고리별 난이도는?
**A**:
- **Essential**: ⭐⭐⭐⭐ (중급~고급, 하지만 필수)
- **Very Important**: ⭐⭐⭐ (중급, 표준 위주)
- **Good-to-Know**: ⭐⭐⭐⭐⭐ (고급, 최적화 기법)
- **Future**: ⭐⭐⭐⭐ (중급~고급, 개념은 어렵지 않지만 새로움)

---

## 추가 학습 자료

### 공식 문서
- [EIPs.ethereum.org](https://eips.ethereum.org/)
- [Solidity Docs](https://docs.soliditylang.org/)
- [OpenZeppelin Docs](https://docs.openzeppelin.com/)

### 유용한 도구
- [Etherscan](https://etherscan.io/) - 실제 컨트랙트 분석
- [Remix](https://remix.ethereum.org/) - 온라인 IDE
- [Tenderly](https://tenderly.co/) - 디버깅

### 참고 프로젝트
- **Uniswap**: EIP-2612
- **Aave**: EIP-1967, EIP-4626
- **Gnosis Safe**: EIP-1271
- **OpenSea**: EIP-165, EIP-2981

---

## 학습 완료 후

### 전체 EIP 학습 체크리스트

학습 진행 상황을 체크하세요!

#### Essential (필수) - 5/5
- [ ] EIP-712: Typed Structured Data Hashing
- [ ] EIP-2612: Permit (Gasless Approval)
- [ ] EIP-1967: Proxy Storage Slots
- [ ] EIP-2535: Diamond Pattern
- [ ] EIP-1271: Contract Signature Validation

#### Very Important (매우 중요) - 5/5
- [ ] EIP-1559: New Gas Model
- [ ] EIP-165: Interface Detection
- [ ] EIP-2981: NFT Royalty Standard
- [ ] EIP-4626: Tokenized Vault Standard
- [ ] EIP-5192: Soulbound Tokens

#### Good-to-Know (알면 좋음) - 4/4
- [ ] EIP-1153: Transient Storage
- [ ] EIP-2930: Access Lists
- [ ] EIP-3529: Gas Refund Reduction
- [ ] EIP-7201: Namespaced Storage Layout

#### Future (미래 대비) - 3/3
- [ ] EIP-4337: Account Abstraction
- [ ] EIP-4844: Blob Transactions
- [ ] EIP-7702: Set Code for EOAs

### 학습 마일스톤

**Level 1: Beginner (초급)** ✅
- Essential 2개 이상 완료
- 기본 서명과 Permit 구현 가능

**Level 2: Intermediate (중급)** ✅
- Essential 전체 + Very Important 3개 이상
- 프록시 패턴과 표준 구현 가능

**Level 3: Advanced (고급)** ✅
- Essential + Very Important 전체
- Good-to-Know 2개 이상
- 프로덕션 레벨 DApp 설계 가능

**Level 4: Expert (전문가)** ✅
- 모든 카테고리 완료
- 가스 최적화와 차세대 기술까지 마스터
- 대규모 프로토콜 아키텍팅 가능

### 다음 단계
1. **프로덕션 프로젝트** 경험
   - 실제 메인넷 배포
   - 보안 감사 받기
   - 사용자 피드백 수집

2. **보안 감사** 학습
   - Slither, Mythril 사용법
   - 일반적인 취약점 패턴
   - Audit 보고서 읽기

3. **가스 최적화** 마스터
   - Assembly 레벨 최적화
   - Storage packing
   - EIP-1153 활용

4. **고급 패턴** 학습
   - EIP-4337 심화
   - MEV 방지 기법
   - Cross-chain 패턴

### 커리어 경로
- **스마트 컨트랙트 개발자**: Essential + Very Important 마스터
- **DApp 풀스택 개발자**: 위 + 프론트엔드 통합 경험
- **보안 감사자**: 모든 EIP + 보안 전문 지식
- **블록체인 아키텍트**: 전체 + 프로덕션 경험 + 시스템 설계

### 실전 프로젝트 아이디어

**미니 프로젝트** (1-2주)
1. Gasless Token Swap (EIP-712, EIP-2612)
2. Upgradeable NFT Collection (EIP-1967, EIP-165, EIP-2981)
3. Modular DAO (EIP-2535, EIP-5192)

**중규모 프로젝트** (1-2개월)
1. Full-featured NFT Marketplace
2. Yield Aggregator (EIP-4626 기반)
3. Smart Account Wallet (EIP-4337)

**대규모 프로젝트** (3-6개월)
1. DeFi 프로토콜 (Lending, DEX, Derivatives)
2. DAO 플랫폼
3. L2 인프라

---

궁금한 점이 있으면 GitHub Issues에 질문을 남겨주세요.

**Happy Learning! 🚀**
