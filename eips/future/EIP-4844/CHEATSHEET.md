# EIP-4844 Cheat Sheet

> **빠른 참조** - Proto-Danksharding (Blob 트랜잭션)

## 🎯 핵심 (5초)

```
문제: L2 데이터 비용이 전체의 90% 💥
해결: Blob = 저렴한 임시 저장소

→ CALLDATA: 16 gas/byte
→ Blob: ~1 gas/byte (16배 저렴!)
```

## 📝 핵심 개념

```
Blob (Binary Large Object):
- 크기: 128KB (4096 field elements)
- 비용: CALLDATA의 1/10
- 저장: ~18일 (임시)
- 용도: L2 Data Availability

Type 3 트랜잭션:
→ Blob을 첨부할 수 있는 새로운 트랜잭션 타입
```

## 💻 Type 3 트랜잭션 구조

```javascript
// Type 3: Blob Transaction
const blobTx = {
    type: 3,
    to: rollupContract,
    nonce: nonce,

    // 일반 가스
    maxFeePerGas: 50n * 10n**9n,
    maxPriorityFeePerGas: 2n * 10n**9n,
    gasLimit: 100000n,

    // Blob 전용 가스 (새로운 필드!)
    maxFeePerBlobGas: 30n * 10n**9n,

    // Blob 해시 (KZG commitment)
    blobVersionedHashes: [
        '0x01...',  // Blob 1
        '0x01...'   // Blob 2
    ],

    // 실제 Blob은 sidecar로 첨부
    blobs: [blob1, blob2],
    kzgCommitments: [commitment1, commitment2],
    kzgProofs: [proof1, proof2],

    chainId: 1,
    value: 0n,
    data: '0x...'
};
```

## 🔧 Blob 생성 (Python)

```python
def create_blob(data: bytes) -> list[int]:
    """데이터를 Blob으로 변환"""
    FIELD_ELEMENTS_PER_BLOB = 4096
    BYTES_PER_FIELD_ELEMENT = 32

    blob = []
    for i in range(FIELD_ELEMENTS_PER_BLOB):
        start = i * BYTES_PER_FIELD_ELEMENT
        end = start + BYTES_PER_FIELD_ELEMENT

        if start < len(data):
            chunk = data[start:end].ljust(BYTES_PER_FIELD_ELEMENT, b'\x00')
        else:
            chunk = b'\x00' * BYTES_PER_FIELD_ELEMENT

        field_element = int.from_bytes(chunk, 'big')
        blob.append(field_element)

    return blob

# KZG Commitment 계산
def compute_kzg_commitment(blob: list[int]) -> bytes:
    polynomial = blob
    commitment = compute_commitment_from_polynomial(polynomial)
    return commitment  # 48 bytes

# Versioned Hash 생성
def kzg_to_versioned_hash(commitment: bytes) -> bytes:
    hash_bytes = keccak(commitment)
    return bytes([0x01]) + hash_bytes[1:]

# 사용
data = b"Batch data..." * 1000
blob = create_blob(data)
commitment = compute_kzg_commitment(blob)
versioned_hash = kzg_to_versioned_hash(commitment)
```

## 🚀 Blob 트랜잭션 전송 (JavaScript)

```javascript
const { ethers } = require('ethers');

async function sendBlobTransaction(provider, signer, rollupContract, blobData) {
    // 1. Blob 생성
    const blob = createBlob(blobData);

    // 2. KZG commitment & proof 계산
    const { commitment, proof, versionedHash } = await computeKZG(blob);

    // 3. Blob gas price 조회
    const blobGasPrice = await provider.getBlobBaseFee();

    // 4. 트랜잭션 생성
    const tx = {
        type: 3,
        to: rollupContract.address,
        maxFeePerGas: ethers.utils.parseUnits('50', 'gwei'),
        maxPriorityFeePerGas: ethers.utils.parseUnits('2', 'gwei'),
        gasLimit: 100000,

        // Blob 가스
        maxFeePerBlobGas: blobGasPrice * 2n,

        // Blob 해시
        blobVersionedHashes: [versionedHash],

        // Calldata
        data: rollupContract.interface.encodeFunctionData('postBatch', [
            batchIndex,
            stateRoot,
            [versionedHash]
        ]),

        chainId: 1
    };

    // 5. Blob sidecar 첨부
    tx.blobs = [blob];
    tx.kzgCommitments = [commitment];
    tx.kzgProofs = [proof];

    // 6. 서명 & 전송
    const signedTx = await signer.signTransaction(tx);
    const receipt = await provider.sendTransaction(signedTx);

    return receipt;
}
```

## 🔍 Blob 조회 (Beacon API)

```javascript
// Beacon Chain에서 Blob 조회
async function fetchBlob(blockNumber) {
    // 1. Beacon block root 조회
    const block = await provider.getBlock(blockNumber);
    const beaconBlockRoot = block.parentBeaconBlockRoot;

    // 2. Beacon API로 blob sidecars 조회
    const response = await fetch(
        `https://beacon-node/eth/v1/beacon/blob_sidecars/${beaconBlockRoot}`
    );

    const data = await response.json();
    return data.data;  // Blob sidecars
}

// KZG proof 검증
async function verifyKZGProof(blob, commitment, proof) {
    const POINT_EVALUATION = '0x000000000000000000000000000000000000000A';

    const versionedHash = kzgToVersionedHash(commitment);

    const result = await provider.call({
        to: POINT_EVALUATION,
        data: ethers.utils.concat([
            versionedHash,
            ethers.utils.randomBytes(32),  // z
            ethers.utils.randomBytes(32),  // y
            commitment,
            proof
        ])
    });

    return result !== '0x';
}
```

## 📦 L2 Rollup Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract OptimisticRollup {
    address public sequencer;

    struct Batch {
        bytes32 stateRoot;
        bytes32 blobHash;
        uint256 timestamp;
    }

    mapping(uint256 => Batch) public batches;
    uint256 public latestBatchIndex;

    event BatchPosted(
        uint256 indexed batchIndex,
        bytes32 indexed stateRoot,
        bytes32 blobHash
    );

    // Blob으로 배치 게시
    function postBatch(
        uint256 batchIndex,
        bytes32 stateRoot,
        bytes32[] calldata blobVersionedHashes
    ) external {
        require(msg.sender == sequencer, "Not sequencer");
        require(batchIndex == latestBatchIndex + 1, "Invalid index");
        require(blobVersionedHashes.length > 0, "No blobs");

        // Blob hash 저장 (데이터는 Beacon Chain에)
        bytes32 blobHash = blobVersionedHashes[0];

        batches[batchIndex] = Batch({
            stateRoot: stateRoot,
            blobHash: blobHash,
            timestamp: block.timestamp
        });

        latestBatchIndex = batchIndex;

        emit BatchPosted(batchIndex, stateRoot, blobHash);
    }

    // Blob 가스 가격 조회
    function getBlobBaseFee() public view returns (uint256) {
        return block.blobbasefee;  // 0x4A opcode
    }
}
```

## 📊 CALLDATA vs Blob 비교

| 특징 | CALLDATA | Blob |
|------|----------|------|
| 크기 | 블록 가스 한도 | 128KB/blob |
| 블록당 최대 | ~15MB | 375KB-750KB (3-6 blobs) |
| 가스 비용 | 16 gas/byte | ~1 gas/byte |
| 저장 기간 | 영구 | ~18일 |
| EVM 접근 | 가능 | 불가능 (해시만) |
| 용도 | 모든 용도 | Data Availability |
| 가스 시장 | 일반 가스 | 별도 blob 가스 |

## 💰 비용 비교

```
128KB 데이터 게시:

CALLDATA:
→ 131,072 bytes × 16 gas/byte = 2,097,152 gas
→ @50 gwei: ~0.105 ETH (~$200)

Blob:
→ 1 blob × 125,000 gas = 125,000 gas
→ @1 gwei: ~0.000125 ETH (~$0.25)

절감: 99.9% ✅
```

## 🔑 핵심 파라미터

```solidity
// Blob 크기
FIELD_ELEMENTS_PER_BLOB = 4096
BYTES_PER_FIELD_ELEMENT = 32
BLOB_SIZE = 131,072 bytes (128 KB)

// 가스
BLOB_TX_TYPE = 3
MIN_BLOB_GASPRICE = 1 wei
TARGET_BLOB_GAS_PER_BLOCK = 393,216 (3 blobs)
MAX_BLOB_GAS_PER_BLOCK = 786,432 (6 blobs)
GAS_PER_BLOB = 131,072

// 저장
BLOB_RETENTION_PERIOD = 4096 epochs (~18일)

// Opcodes
BLOBBASEFEE = 0x4A
POINT_EVALUATION_PRECOMPILE = 0x0A

// Versioned Hash
BLOB_COMMITMENT_VERSION_KZG = 0x01
```

## 🎮 Blob 가스 시장

```
EIP-1559 스타일:

Target: 3 blobs/block
Max: 6 blobs/block

가격 조정:
→ Usage > Target: 가격 상승 (지수적)
→ Usage < Target: 가격 하락 (지수적)

최소 가격: 1 wei
```

## ⚠️ 보안 체크리스트

```solidity
// ✅ 1. Blob 가용성 보장
// L2 Sequencer는 Blob을 영구 보관해야 함
class BlobArchive {
    async storeBlob(blobHash, blobData) {
        await this.localStorage.put(blobHash, blobData);
        await this.s3.upload(blobHash, blobData);
        await this.celestia.submit(blobData);  // DA layer
    }
}

// ✅ 2. KZG proof 검증
const verified = await verifyKZGProof(blob, commitment, proof);
require(verified, "Blob verification failed");

// ✅ 3. Challenge period 확인
require(
    block.timestamp <= batch.timestamp + 7 days,
    "Within challenge period"
);

require(
    block.number - batch.l1BlockNumber < 18 * 7200,
    "Blob still available"
);

// ✅ 4. Blob gas price 체크
const blobGasPrice = await provider.getBlobBaseFee();
if (blobGasPrice > threshold) {
    waitForLowerPrice();
}

// ✅ 5. Type 3 트랜잭션 검증
require(tx.type == 3, "Invalid type");
require(tx.blobVersionedHashes.length <= 6, "Too many blobs");
require(tx.blobVersionedHashes[0][0] == 0x01, "Invalid version");
```

## 💡 일반적인 실수

### ❌ 실수 1: EVM에서 Blob 읽기 시도

```solidity
// ❌ 틀림: Blob을 EVM에서 읽을 수 없음
function processBlob(bytes32 blobHash) external {
    bytes memory blobData = readBlob(blobHash);  // 불가능!
}

// ✅ 맞음: Blob hash만 저장
function processBatch(bytes32 blobHash) external {
    batches[index].blobHash = blobHash;  // hash만 저장
    // 실제 데이터는 Beacon API로 조회
}
```

### ❌ 실수 2: 18일 이후 접근 가정

```javascript
// ❌ 틀림: 18일 이후에도 Beacon API 사용
const blob = await beaconAPI.getBlob(blobHash);
// → 18일 이후 404 에러!

// ✅ 맞음: 백업 스토리지 사용
async function getBlob(blobHash) {
    // 1. Beacon API 시도 (18일 내)
    try {
        return await beaconAPI.getBlob(blobHash);
    } catch {}

    // 2. Archive node 또는 백업 사용
    return await archiveAPI.getBlob(blobHash);
}
```

### ❌ 실수 3: maxFeePerBlobGas 누락

```javascript
// ❌ 틀림: Blob gas 가격 지정 안 함
const tx = {
    type: 3,
    blobVersionedHashes: [hash],
    // maxFeePerBlobGas 누락!
};

// ✅ 맞음: Blob gas 가격 지정
const blobGasPrice = await provider.getBlobBaseFee();
const tx = {
    type: 3,
    blobVersionedHashes: [hash],
    maxFeePerBlobGas: blobGasPrice * 2n,  // 여유분 포함
};
```

## 📈 실제 영향 (2024년)

```
L2 수수료 절감:

Optimism:
- Before: $0.50/txn
- After:  $0.05/txn
- 절감: 90%

Arbitrum:
- Before: $0.30/txn
- After:  $0.03/txn
- 절감: 90%

Base:
- Before: $0.40/txn
- After:  $0.04/txn
- 절감: 90%

zkSync Era:
- Before: $0.25/txn
- After:  $0.02/txn
- 절감: 92%
```

## 🔍 디버깅

### Blob 트랜잭션 확인

```javascript
// 트랜잭션 조회
const tx = await provider.getTransaction(txHash);

console.log('Type:', tx.type);  // 3
console.log('Blob hashes:', tx.blobVersionedHashes);
console.log('Max blob gas:', tx.maxFeePerBlobGas);

// Blob gas 사용량 조회
const receipt = await provider.getTransactionReceipt(txHash);
console.log('Blob gas used:', receipt.blobGasUsed);
console.log('Blob gas price:', receipt.blobGasPrice);
```

### Blob 가스 가격 모니터링

```javascript
// 현재 blob gas price
const blobBaseFee = await provider.getBlobBaseFee();
console.log('Current blob gas price:', blobBaseFee);

// 블록별 blob 사용량
const block = await provider.getBlock(blockNumber);
console.log('Blob gas used:', block.blobGasUsed);
console.log('Excess blob gas:', block.excessBlobGas);
```

## 🎓 사용 사례

```
✅ Optimism        - Optimistic Rollup
✅ Arbitrum        - Optimistic Rollup
✅ Base            - Optimistic Rollup (Coinbase)
✅ zkSync Era      - ZK Rollup
✅ Starknet        - ZK Rollup (Cairo)
✅ Polygon zkEVM   - ZK Rollup
✅ Scroll          - ZK Rollup
✅ Linea           - ZK Rollup (Consensys)
```

## 🚀 로드맵

```
현재: Proto-Danksharding (EIP-4844)
→ Target: 3 blobs/block (375KB)
→ Max: 6 blobs/block (750KB)
→ L2 처리량: ~3,000 TPS

미래: Full Danksharding
→ Target: 128 blobs/block (16MB)
→ Data Availability Sampling (DAS)
→ L2 처리량: ~100,000 TPS
```

## 🔗 빠른 링크

- [README.md](./README.md) - 상세 가이드
- [EIP-4844 Spec](https://eips.ethereum.org/EIPS/eip-4844)
- [Blobscan](https://blobscan.com/) - Blob 탐색기
- [Blobs.io](https://blobs.io/) - Blob 통계
- [c-kzg](https://github.com/ethereum/c-kzg-4844) - KZG 라이브러리
- [Danksharding Roadmap](https://ethereum.org/en/roadmap/danksharding/)

---

**핵심 요약:**

```
Blob = L2를 위한 저렴한 임시 저장소

특징:
→ 크기: 128KB
→ 비용: CALLDATA의 1/10
→ 저장: ~18일 (자동 삭제)
→ 접근: Beacon API

Type 3 트랜잭션:
→ maxFeePerBlobGas
→ blobVersionedHashes
→ blobs (sidecar)

효과:
→ L2 수수료 90% 절감
→ L2 처리량 10배 증가
→ 노드 부담 감소

EntryPoint: 2024년 3월 13일 (Dencun)
```

**마지막 업데이트: 2025**
