# EIP 학습 가이드 - 컨트랙트 개발자용

스마트 컨트랙트 개발자가 반드시 알아야 할 EIP(Ethereum Improvement Proposal)들을 정리한 학습 레포지토리입니다.

## 프로젝트 통계

- **총 EIP 수**: 17개 (4개 카테고리)
- **Solidity 계약**: 31개
- **테스트 파일**: 5개
- **문서**: 19개 README
- **예상 학습 기간**: 4-12주

## 프로젝트 구조

```
EIPcontractStudy/
├── eips/
│   ├── essential/          # 필수
│   │   ├── EIP-712/       # Typed Structured Data Hashing
│   │   ├── EIP-2612/      # Permit (Gasless Approval)
│   │   ├── EIP-1967/      # Proxy Storage Slots
│   │   ├── EIP-2535/      # Diamond Pattern
│   │   └── EIP-1271/      # Contract Signature Validation
│   │
│   ├── very-important/    # 매우 중요
│   │   ├── EIP-1559/      # New Gas Model
│   │   ├── EIP-165/       # Interface Detection
│   │   ├── EIP-2981/      # NFT Royalty Standard
│   │   ├── EIP-4626/      # Tokenized Vault Standard
│   │   └── EIP-5192/      # Soulbound Tokens
│   │
│   ├── good-to-know/      # 알면 좋음
│   │   ├── EIP-2930/      # Access Lists
│   │   ├── EIP-3529/      # Gas Refund Reduction
│   │   ├── EIP-1153/      # Transient Storage
│   │   └── EIP-7201/      # Namespaced Storage Layout
│   │
│   └── future/            # 미래 대비
│       ├── EIP-4337/      # Account Abstraction
│       ├── EIP-7702/      # Set Code for EOAs
│       └── EIP-4844/      # Blob Transactions
│
└── 
```

## 빠른 시작 가이드

### 프로젝트 타입별 학습 경로

**NFT 개발자라면?**
```
EIP-165 → EIP-712 → EIP-2981 → EIP-5192 → EIP-1271 → EIP-1967
```

**DeFi 개발자라면?**
```
EIP-712 → EIP-2612 → EIP-4626 → EIP-1967 → EIP-2535 → EIP-1153
```

**지갑/인프라 개발자라면?**
```
EIP-1271 → EIP-712 → EIP-1559 → EIP-4337 → EIP-7702
```

**초보자라면? (난이도 순)**
```
Phase 1: EIP-165 → EIP-712 → EIP-2612
Phase 2: EIP-1559 → EIP-1967 → EIP-1271
Phase 3: EIP-2535 → EIP-2981 → EIP-4626 → EIP-5192
```

➡️ **자세한 학습 로드맵은 [LEARNING_GUIDE.md](./LEARNING_GUIDE.md)를 참고하세요!**

---

## 학습 순서

### 📌 1단계: Essential (필수) - 5개
반드시 이해하고 사용할 수 있어야 하는 EIP들

1. **[EIP-712](./eips/essential/EIP-712/)** - Typed Structured Data Hashing
   - 오프체인 서명의 표준 (메타 트랜잭션, Permit, 거버넌스)
   - 📁 2개 계약 + 테스트

2. **[EIP-2612](./eips/essential/EIP-2612/)** - Permit (Gasless Approval)
   - 가스비 없는 토큰 승인, UX 개선
   - 📁 2개 계약 + 테스트

3. **[EIP-1967](./eips/essential/EIP-1967/)** - Proxy Storage Slots
   - 업그레이드 가능한 컨트랙트 개발 필수
   - 📁 3개 계약 + 테스트

4. **[EIP-2535](./eips/essential/EIP-2535/)** - Diamond Pattern
   - 24KB 제한 우회, 모듈식 대규모 시스템
   - 📁 10개 계약 + 테스트 (가장 복잡)

5. **[EIP-1271](./eips/essential/EIP-1271/)** - Contract Signature Validation
   - 스마트 컨트랙트 지갑 (Gnosis Safe 등)
   - 📁 5개 계약 + 테스트 + 퀵스타트 가이드

### ⭐ 2단계: Very Important (매우 중요) - 5개
프로덕션급 개발자가 알아야 하는 표준들

6. **[EIP-1559](./eips/very-important/EIP-1559/)** - New Gas Model
   - 동적 가스 모델 (Base Fee + Priority Fee)
7. **[EIP-165](./eips/very-important/EIP-165/)** - Interface Detection
   - 인터페이스 감지 (ERC-165)
8. **[EIP-2981](./eips/very-important/EIP-2981/)** - NFT Royalty Standard
   - NFT 로열티 자동 분배
9. **[EIP-4626](./eips/very-important/EIP-4626/)** - Tokenized Vault Standard
   - Yield Vault 표준 (DeFi 필수)
10. **[EIP-5192](./eips/very-important/EIP-5192/)** - Soulbound Tokens
    - 양도 불가능 토큰 (자격증, 멤버십)

### 💡 3단계: Good-to-Know (알면 좋음) - 4개
고급 최적화와 특수 케이스

11. **[EIP-1153](./eips/good-to-know/EIP-1153/)** - Transient Storage
    - 블록 내 임시 스토리지 (가스 절감)
12. **[EIP-7201](./eips/good-to-know/EIP-7201/)** - Namespaced Storage Layout
    - 스토리지 충돌 방지 패턴
13. **[EIP-2930](./eips/good-to-know/EIP-2930/)** - Access Lists
    - 트랜잭션 최적화
14. **[EIP-3529](./eips/good-to-know/EIP-3529/)** - Gas Refund Reduction
    - 가스 환불 메커니즘 변경

### 🚀 4단계: Future (미래 대비) - 3개
차세대 이더리움 기능

15. **[EIP-4337](./eips/future/EIP-4337/)** - Account Abstraction
    - 스마트 컨트랙트 지갑 표준 (미래의 UX)
16. **[EIP-7702](./eips/future/EIP-7702/)** - Set Code for EOAs
    - EOA에 일시적 코드 실행 기능
17. **[EIP-4844](./eips/future/EIP-4844/)** - Blob Transactions
    - L2 롤업을 위한 데이터 가용성 레이어

## 각 EIP 폴더 구조

각 EIP 폴더는 다음 구조로 되어 있습니다:

```
EIP-XXXX/
├── README.md           # 상세 학습 자료 (한글)
├── contracts/          # 실제 구현 예제
│   ├── Example.sol
│   ├── Advanced.sol
│   └── Integration.sol
└── tests/             # 테스트 예제 (일부)
    └── Example.test.js
```

## 시작하기

### 1. 저장소 클론
```bash
git clone https://github.com/your-username/EIPcontractStudy.git
cd EIPcontractStudy
```

### 2. 학습 순서대로 진행
1. `eips/essential/EIP-712/README.md` 부터 시작
2. 각 README.md를 읽고 핵심 개념 이해
3. `contracts/` 폴더의 예제 코드 실행 및 수정
4. 실전 프로젝트에 적용

### 3. 샘플 컨트랙트 테스트
```bash
# Foundry 설치 (권장)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 테스트 실행
cd eips/essential/EIP-712/contracts
forge test
```

## 각 EIP에서 배울 내용

각 EIP 문서는 다음 구조로 작성되어 있습니다:

- **목적**: 왜 이 EIP가 필요한가?
- **핵심 개념**: 어떻게 동작하는가?
- **구현 예제**: 완전한 Solidity 코드
- **실전 활용**: 실제 사용 패턴
- **주의사항**: 보안 고려사항
- **OpenZeppelin**: 표준 라이브러리 사용법
- **참고 자료**: 공식 문서 링크

## 기술 스택

- **Solidity**: ^0.8.20
- **OpenZeppelin Contracts**: 최신 버전
- **Hardhat / Foundry**: 테스트 프레임워크
- **ethers.js v6**: 프론트엔드 통합

## 기여하기

이 프로젝트는 계속 발전하고 있습니다:

1. 새로운 EIP 추가
2. 기존 문서 개선
3. 더 나은 예제 코드
4. 오류 수정

Pull Request를 환영합니다!

## 라이선스

MIT License

## 개발자를 위한 팁

### 1. 실무에서 자주 사용하는 조합
```
EIP-712 + EIP-2612 + EIP-1271
→ 완전한 메타 트랜잭션 시스템

EIP-1967 + EIP-7201
→ 안전한 업그레이드 가능 컨트랙트

EIP-165 + EIP-2981
→ 표준 NFT 마켓플레이스 통합

EIP-4626 + EIP-2612
→ DeFi 프로토콜 개발
```

### 2. 학습 리소스
- 각 EIP의 공식 명세서
- OpenZeppelin 구현 코드
- 실제 프로젝트 (Uniswap, Aave, OpenSea)
- Etherscan 검증된 컨트랙트

### 3. 실전 연습
1. 각 EIP의 샘플 코드를 수정해보기
2. 여러 EIP를 조합한 프로젝트 만들기
3. 테스트넷에 배포하고 테스트하기
4. 메인넷 프로젝트 분석하기

## 주요 프로젝트 활용 사례

- **Uniswap**: EIP-2612 (Permit)
- **Aave**: EIP-1967 (Upgradeable), EIP-4626 (Vault)
- **Gnosis Safe**: EIP-1271 (Contract Signatures)
- **OpenSea**: EIP-165, EIP-2981 (NFT Standards)
- **Yearn**: EIP-4626 (Tokenized Vaults)

## 문의

질문이나 제안사항이 있으시면 Issue를 생성해주세요.

---

**Happy Learning!**
