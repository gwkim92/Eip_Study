# EIP-7201 Cheat Sheet

> **빠른 참조** - Namespaced Storage Layout (네임스페이스 스토리지)

## 🎯 핵심 (5초)

```
문제: 프록시/Diamond 패턴에서 스토리지 충돌
해결: 네임스페이스 기반 안전한 스토리지 슬롯

→ 고유한 슬롯 계산으로 충돌 방지
→ 업그레이드 안전성 향상
```

## 📝 네임스페이스 계산 공식

```solidity
// EIP-7201 표준 공식
function erc7201Slot(string memory id) internal pure returns (bytes32) {
    return keccak256(
        abi.encode(
            uint256(keccak256(bytes(id))) - 1
        )
    ) & ~bytes32(uint256(0xff));
}

// 예시:
// "example.storage.main"
// → 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00
```

## 💻 기본 구현

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BasicNamespacedStorage {
    // 1. Struct 정의
    struct MainStorage {
        uint256 value;
        address owner;
        mapping(address => uint256) balances;
    }

    // 2. 네임스페이스 슬롯 계산 (컴파일 타임)
    bytes32 private constant MAIN_STORAGE_LOCATION =
        keccak256(
            abi.encode(
                uint256(keccak256("example.storage.main")) - 1
            )
        ) & ~bytes32(uint256(0xff));

    // 3. Storage 접근자
    function _getMainStorage() 
        private 
        pure 
        returns (MainStorage storage $) 
    {
        assembly {
            $.slot := MAIN_STORAGE_LOCATION
        }
    }

    // 4. 사용
    function setValue(uint256 newValue) external {
        MainStorage storage $ = _getMainStorage();
        $.value = newValue;
    }

    function getValue() external view returns (uint256) {
        MainStorage storage $ = _getMainStorage();
        return $.value;
    }
}
```

## 🎨 다중 네임스페이스

```solidity
contract MultiNamespace {
    // ============ 네임스페이스 1: 사용자 데이터 ============
    struct UserStorage {
        mapping(address => string) names;
        mapping(address => uint256) scores;
        uint256 totalUsers;
    }

    bytes32 private constant USER_STORAGE_LOCATION =
        keccak256(
            abi.encode(
                uint256(keccak256("example.storage.user")) - 1
            )
        ) & ~bytes32(uint256(0xff));

    function _getUserStorage() 
        private 
        pure 
        returns (UserStorage storage $) 
    {
        assembly {
            $.slot := USER_STORAGE_LOCATION
        }
    }

    // ============ 네임스페이스 2: 토큰 데이터 ============
    struct TokenStorage {
        mapping(address => uint256) balances;
        uint256 totalSupply;
        string name;
    }

    bytes32 private constant TOKEN_STORAGE_LOCATION =
        keccak256(
            abi.encode(
                uint256(keccak256("example.storage.token")) - 1
            )
        ) & ~bytes32(uint256(0xff));

    function _getTokenStorage() 
        private 
        pure 
        returns (TokenStorage storage $) 
    {
        assembly {
            $.slot := TOKEN_STORAGE_LOCATION
        }
    }

    // ============ 사용 예시 ============
    function setUserName(address user, string calldata name) external {
        UserStorage storage $ = _getUserStorage();
        $.names[user] = name;
        $.totalUsers++;
    }

    function setBalance(address account, uint256 amount) external {
        TokenStorage storage $ = _getTokenStorage();
        $.balances[account] = amount;
        $.totalSupply += amount;
    }
}
```

## 🔄 프록시 패턴과 함께 사용

```solidity
contract UpgradeableWithNamespace {
    // 네임스페이스 스토리지
    struct AppStorage {
        uint256 version;
        address implementation;
        mapping(bytes4 => address) facets;
    }

    bytes32 private constant APP_STORAGE_LOCATION =
        keccak256(
            abi.encode(
                uint256(keccak256("myapp.upgradeable.storage")) - 1
            )
        ) & ~bytes32(uint256(0xff));

    function _getAppStorage() 
        private 
        pure 
        returns (AppStorage storage $) 
    {
        assembly {
            $.slot := APP_STORAGE_LOCATION
        }
    }

    // 업그레이드
    function upgradeTo(address newImplementation) external {
        AppStorage storage $ = _getAppStorage();
        $.implementation = newImplementation;
        $.version++;
    }

    // 버전 조회
    function getVersion() external view returns (uint256) {
        AppStorage storage $ = _getAppStorage();
        return $.version;
    }
}
```

## 📦 Diamond 패턴과 통합

```solidity
// Facet에서 네임스페이스 사용
library TokenLib {
    struct TokenStorage {
        mapping(address => uint256) balances;
        uint256 totalSupply;
    }

    bytes32 constant TOKEN_STORAGE_LOCATION =
        keccak256(
            abi.encode(
                uint256(keccak256("diamond.token.storage")) - 1
            )
        ) & ~bytes32(uint256(0xff));

    function getStorage() 
        internal 
        pure 
        returns (TokenStorage storage $) 
    {
        assembly {
            $.slot := TOKEN_STORAGE_LOCATION
        }
    }
}

contract TokenFacet {
    function mint(address to, uint256 amount) external {
        TokenLib.TokenStorage storage $ = TokenLib.getStorage();
        $.balances[to] += amount;
        $.totalSupply += amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        TokenLib.TokenStorage storage $ = TokenLib.getStorage();
        return $.balances[account];
    }
}
```

## 🛡️ 스토리지 충돌 방지

```solidity
// ❌ BAD: 직접 슬롯 사용 (충돌 위험)
contract BadExample {
    uint256 public value;    // slot 0
    address public owner;    // slot 1
    
    // 업그레이드 시 순서가 바뀌면 충돌!
}

// ✅ GOOD: 네임스페이스 사용
contract GoodExample {
    struct Storage {
        uint256 value;
        address owner;
    }

    bytes32 private constant STORAGE_LOCATION =
        keccak256(
            abi.encode(
                uint256(keccak256("good.example.storage")) - 1
            )
        ) & ~bytes32(uint256(0xff));

    function _getStorage() 
        private 
        pure 
        returns (Storage storage $) 
    {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }
    
    // 안전하게 업그레이드 가능!
}
```

## 🏗️ 모듈식 시스템

```solidity
contract ModularSystem {
    // 모듈 A: 인증
    struct AuthModule {
        mapping(address => bool) authorized;
        address admin;
    }

    bytes32 private constant AUTH_MODULE_LOCATION =
        keccak256(
            abi.encode(
                uint256(keccak256("module.auth.storage")) - 1
            )
        ) & ~bytes32(uint256(0xff));

    function _getAuthModule() 
        private 
        pure 
        returns (AuthModule storage $) 
    {
        assembly {
            $.slot := AUTH_MODULE_LOCATION
        }
    }

    // 모듈 B: 거버넌스
    struct GovernanceModule {
        mapping(uint256 => bool) executed;
        uint256 proposalCount;
    }

    bytes32 private constant GOVERNANCE_MODULE_LOCATION =
        keccak256(
            abi.encode(
                uint256(keccak256("module.governance.storage")) - 1
            )
        ) & ~bytes32(uint256(0xff));

    function _getGovernanceModule() 
        private 
        pure 
        returns (GovernanceModule storage $) 
    {
        assembly {
            $.slot := GOVERNANCE_MODULE_LOCATION
        }
    }

    // 각 모듈은 독립적으로 스토리지 관리
    function authorize(address user) external {
        AuthModule storage $ = _getAuthModule();
        $.authorized[user] = true;
    }

    function createProposal() external returns (uint256) {
        GovernanceModule storage $ = _getGovernanceModule();
        return $.proposalCount++;
    }
}
```

## 🔧 네임스페이스 계산 유틸리티

```solidity
contract NamespaceCalculator {
    // 네임스페이스 계산
    function calculateNamespace(string memory id) 
        public 
        pure 
        returns (bytes32) 
    {
        return keccak256(
            abi.encode(
                uint256(keccak256(bytes(id))) - 1
            )
        ) & ~bytes32(uint256(0xff));
    }

    // 충돌 확인
    function checkCollision(string memory id1, string memory id2)
        external
        pure
        returns (bool collides)
    {
        bytes32 ns1 = calculateNamespace(id1);
        bytes32 ns2 = calculateNamespace(id2);
        return ns1 == ns2;
    }

    // 상세 정보
    function getNamespaceInfo(string memory id)
        external
        pure
        returns (
            bytes32 namespace,
            bytes32 rawHash,
            uint256 rawHashMinus1
        )
    {
        rawHash = keccak256(bytes(id));
        rawHashMinus1 = uint256(rawHash) - 1;
        namespace = keccak256(abi.encode(rawHashMinus1)) 
            & ~bytes32(uint256(0xff));
    }
}
```

## 📝 네임스페이스 명명 규칙

```solidity
/**
 * 네임스페이스 명명 베스트 프랙티스:
 */

// 1. 역방향 도메인 스타일
"com.company.project.module.storage"

// 2. ERC 스타일
"erc7201.storage.module"

// 3. 프로젝트별 스타일
"project.module.version.storage"

// 예시:
bytes32 private constant STORAGE_LOCATION =
    keccak256(
        abi.encode(
            uint256(keccak256("com.mycompany.myproject.main.v1.storage")) - 1
        )
    ) & ~bytes32(uint256(0xff));
```

## 🆚 EIP-1967 vs EIP-7201

| 비교 | EIP-1967 | EIP-7201 |
|-----|----------|----------|
| **용도** | 프록시 메타데이터 | 애플리케이션 데이터 |
| **슬롯** | 고정 (명세에 정의) | 동적 (ID 기반 계산) |
| **예시** | `IMPLEMENTATION_SLOT` | `"app.storage.main"` |
| **충돌** | 표준 슬롯 사용 | 네임스페이스로 방지 |
| **사용처** | Proxy 구현 | 비즈니스 로직 |

```solidity
// EIP-1967: 고정 슬롯
bytes32 constant IMPLEMENTATION_SLOT = 
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

// EIP-7201: 동적 슬롯 (ID 기반)
bytes32 constant MY_STORAGE_LOCATION =
    keccak256(
        abi.encode(
            uint256(keccak256("my.unique.id")) - 1
        )
    ) & ~bytes32(uint256(0xff));
```

## ⚠️ 주의사항

```solidity
// 1. 네임스페이스 ID는 고유해야 함
// ❌ BAD: 중복 가능성
"storage"
"data"

// ✅ GOOD: 고유성 보장
"com.mycompany.myproject.module.v1.storage"

// 2. & ~bytes32(uint256(0xff)) 필수!
// ❌ BAD: 마지막 바이트 마스킹 없음
bytes32 slot = keccak256(abi.encode(uint256(keccak256(id)) - 1));

// ✅ GOOD: 마지막 바이트를 0으로
bytes32 slot = keccak256(abi.encode(uint256(keccak256(id)) - 1))
    & ~bytes32(uint256(0xff));

// 3. Storage struct는 immutable
// ❌ BAD: struct 변경
struct Storage {
    uint256 value;
    address owner;  // 나중에 추가하면 충돌!
}

// ✅ GOOD: 새 네임스페이스 사용
struct StorageV2 {
    uint256 value;
    address owner;
    uint256 newField;  // 새 네임스페이스에서
}
```

## 🎯 사용 시나리오

```
✅ 프록시 패턴: 구현 컨트랙트 간 스토리지 격리
✅ Diamond 패턴: Facet 간 스토리지 격리
✅ 라이브러리: 재사용 가능한 스토리지 라이브러리
✅ 업그레이드: 안전한 컨트랙트 업그레이드
✅ 모듈식 설계: 독립적인 모듈 관리
```

## 💡 핵심 요약

```
┌─────────────────────────────────────┐
│   EIP-7201 한눈에 보기               │
├─────────────────────────────────────┤
│                                     │
│  📝 공식:                           │
│  keccak256(abi.encode(             │
│    uint256(keccak256(id)) - 1      │
│  )) & ~bytes32(uint256(0xff))      │
│                                     │
│  🎯 장점:                           │
│  • 스토리지 충돌 방지 ✅            │
│  • 업그레이드 안전성 ✅             │
│  • 모듈 간 격리 ✅                  │
│  • Diamond 패턴 최적화 ✅          │
│                                     │
│  🔧 사용:                           │
│  1. Struct 정의                    │
│  2. 네임스페이스 계산               │
│  3. Storage 접근자 생성             │
│  4. Assembly로 슬롯 할당            │
│                                     │
└─────────────────────────────────────┘

패턴:
struct MyStorage { ... }
bytes32 constant LOCATION = erc7201Slot("id");
function _getStorage() returns (MyStorage storage $) {
    assembly { $.slot := LOCATION }
}

베스트 프랙티스:
✅ 고유한 네임스페이스 ID
✅ 역방향 도메인 명명
✅ 문서화 철저히
✅ 충돌 테스트
✅ Struct 버전 관리
```

## 📚 참고 자료

**공식 문서**
- [EIP-7201 Specification](https://eips.ethereum.org/EIPS/eip-7201)
- [OpenZeppelin Storage](https://docs.openzeppelin.com/contracts/5.x/api/utils#StorageSlot)

**관련 EIP**
- [EIP-1967: Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967)
- [EIP-2535: Diamond Standard](https://eips.ethereum.org/EIPS/eip-2535)

## 🔑 핵심 기억할 것

```solidity
// 1. 네임스페이스 계산 (3단계)
bytes32 hash = keccak256("my.id");              // 1. 해시
uint256 minus1 = uint256(hash) - 1;             // 2. -1
bytes32 slot = keccak256(abi.encode(minus1))    // 3. 재해시
    & ~bytes32(uint256(0xff));                  //    + 마스킹

// 2. Storage 접근 패턴
function _getStorage() private pure returns (Storage storage $) {
    assembly { $.slot := STORAGE_LOCATION }
}

// 3. 사용 패턴
Storage storage $ = _getStorage();
$.value = 123;

// 4. EIP-1967과 함께 사용
// EIP-1967: 프록시 메타데이터
// EIP-7201: 애플리케이션 데이터
```

**EIP-7201은 스토리지 충돌을 방지하여 안전한 업그레이드와 모듈식 설계를 가능하게 합니다!** 🚀

---

**마지막 업데이트: 2025-11-05**

