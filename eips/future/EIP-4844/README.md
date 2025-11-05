# EIP-4844: Proto-Danksharding (Blob 트랜잭션)

> **이더리움 확장성의 미래** - L2 롤업을 위한 저렴한 데이터 저장소

## 📋 목차

- [개요](#개요)
- [문제점: L2의 높은 데이터 비용](#문제점-l2의-높은-데이터-비용)
- [해결책: Blob 트랜잭션](#해결책-blob-트랜잭션)
- [핵심 개념](#핵심-개념)
- [Blob 트랜잭션 구조](#blob-트랜잭션-구조)
- [작동 원리](#작동-원리)
- [실전 예제](#실전-예제)
- [L2 통합](#l2-통합)
- [보안 고려사항](#보안-고려사항)
- [실제 영향](#실제-영향)
- [FAQ](#faq)
- [참고 자료](#참고-자료)

## 개요

### EIP-4844란?

**EIP-4844 (Proto-Danksharding)**는 이더리움에 **Blob 트랜잭션 (Type 3)**을 도입하여 L2 롤업의 데이터 가용성 비용을 대폭 절감하는 업그레이드입니다.

2024년 3월 13일, **Dencun 하드포크**를 통해 메인넷에 활성화되었습니다.

### 왜 중요한가?

```
기존 (CALLDATA):
❌ L2 트랜잭션 비용의 90%가 L1 데이터 비용
❌ CALLDATA는 비싸고 영구 저장
❌ L2 확장에 한계

EIP-4844 (Blob):
✅ 데이터 비용 90% 절감
✅ 일시적 저장 (~18일)
✅ L2 처리량 10배 증가
✅ 사용자 수수료 대폭 감소
```

### 핵심 특징

1. **Blob (Binary Large Object)**: 128KB 크기의 임시 데이터 저장소
2. **Type 3 트랜잭션**: Blob을 첨부할 수 있는 새로운 트랜잭션 타입
3. **별도 가스 시장**: Blob 전용 가스 시장 (EIP-1559 스타일)
4. **임시 저장**: ~18일 후 자동 삭제 (commitment는 영구 보존)
5. **KZG Commitment**: 암호학적 증명으로 데이터 무결성 보장

## 문제점: L2의 높은 데이터 비용

### L2 롤업의 작동 방식

L2 롤업(Optimism, Arbitrum, zkSync 등)은 다음과 같이 작동합니다:

```
1. L2에서 트랜잭션 실행 (빠르고 저렴)
2. 트랜잭션 데이터를 배치로 묶음
3. L1 이더리움에 데이터 게시 (Data Availability)
4. L1에서 검증 가능성 보장
```

### 문제: CALLDATA 비용

기존에는 L2 데이터를 **CALLDATA**로 L1에 게시했습니다:

```solidity
// L2 Sequencer가 L1에 배치 게시
function postBatch(bytes calldata batchData) external {
    // batchData는 CALLDATA에 영구 저장됨
    // → 매우 비쌈!
}
```

**CALLDATA 문제점:**

1. **비용이 너무 높음**
   ```
   CALLDATA 가스 비용:
   - Zero byte: 4 gas
   - Non-zero byte: 16 gas

   평균: ~16 gas/byte
   128KB 데이터: ~2,000,000 gas
   → L2 트랜잭션 비용의 90%가 데이터 비용!
   ```

2. **영구 저장 낭비**
   ```
   CALLDATA는 이더리움 상태에 영구 저장
   → L2 검증에만 필요한 임시 데이터까지 영구 보존
   → 노드 부담 증가, 스토리지 낭비
   ```

3. **확장성 한계**
   ```
   블록 가스 한도: 30M gas
   CALLDATA로 채울 수 있는 데이터: ~15MB/block
   → L2 처리량 제한
   ```

### 실제 사례

**Optimism 트랜잭션 비용 (2024년 2월):**
```
L2 실행 비용:    $0.05
L1 데이터 비용:   $0.45
────────────────────
총 비용:         $0.50

→ 90%가 L1 데이터 비용!
```

**사용자 경험 문제:**
- L2를 사용해도 수수료가 높음
- 네트워크 혼잡 시 급격히 상승
- L2의 장점이 제한됨

## 해결책: Blob 트랜잭션

### Blob이란?

**Blob (Binary Large Object)**는 L2 데이터를 위한 임시 저장소입니다.

```
Blob 특징:
- 크기: 128KB (4096 field elements × 32 bytes)
- 비용: CALLDATA의 1/10 (~1 gas/byte)
- 저장: 임시 (~18일, 4096 epoch)
- 접근: EVM에서 직접 읽을 수 없음 (해시만 접근 가능)
- 용도: L2 Data Availability 전용
```

### Type 3 트랜잭션

Blob을 첨부할 수 있는 새로운 트랜잭션 타입:

```javascript
// Type 0: Legacy (pre-EIP-2718)
// Type 1: EIP-2930 (Access List)
// Type 2: EIP-1559 (Dynamic Fee)
// Type 3: EIP-4844 (Blob Transaction) ← 신규!

const blobTx = {
    type: 3,
    to: rollupContract,
    nonce: nonce,

    // EIP-1559 가스
    maxFeePerGas: 50n * 10n**9n,
    maxPriorityFeePerGas: 2n * 10n**9n,
    gasLimit: 100000n,

    // Blob 전용 가스
    maxFeePerBlobGas: 30n * 10n**9n,  // 새로운 필드!

    // Blob 해시들
    blobVersionedHashes: [
        '0x01...',  // Blob 1의 KZG commitment 해시
        '0x01...'   // Blob 2의 KZG commitment 해시
    ],

    // 실제 Blob은 트랜잭션 외부에 첨부
    blobs: [blob1, blob2],

    chainId: 1,
    value: 0n,
    data: '0x...'
};
```

### Blob vs CALLDATA 비교

| 특징 | CALLDATA | Blob |
|------|----------|------|
| 크기 제한 | 블록 가스 한도 | 128KB/blob |
| 블록당 최대 | ~15MB | 375KB - 750KB (3-6 blobs) |
| 가스 비용 | 16 gas/byte | ~1 gas/byte |
| 저장 기간 | 영구 | ~18일 |
| EVM 접근 | 가능 | 불가능 (해시만) |
| 용도 | 모든 용도 | Data Availability |
| 가스 시장 | 일반 가스 | 별도 blob 가스 |

### 비용 절감 효과

```
128KB 데이터 게시 비용 비교:

CALLDATA:
→ 131,072 bytes × 16 gas/byte = 2,097,152 gas
→ Gas price 50 gwei: ~0.105 ETH (~$200)

Blob:
→ 1 blob × ~125,000 gas = 125,000 gas
→ Blob gas price 1 gwei: ~0.000125 ETH (~$0.25)

절감: 99.9% ✅
```

## 핵심 개념

### 1. Blob 구조

```
Blob = 128KB 데이터 청크

구성:
- 4096 field elements
- 각 field element: 32 bytes (256 bits)
- BLS12-381 곡선의 스칼라 필드

총 크기: 4096 × 32 = 131,072 bytes = 128 KB
```

**Field Element:**
```
BLS12-381 필드의 원소:
→ 0부터 p-1까지의 정수
→ p = 52435875175126190479447740508185965837690552500527637822603658699938581184513

실제로는 254 bits만 사용 (안전을 위해)
```

### 2. KZG Commitment

**KZG (Kate-Zaverucha-Goldberg) Commitment**는 Blob의 암호학적 요약입니다.

```
KZG Commitment:
→ Blob 데이터를 48 bytes로 압축
→ 데이터 무결성 증명 가능
→ 특정 위치의 값 증명 가능 (Polynomial Commitment)

versioned hash:
→ sha256(commitment)[1:] + 0x01
→ 32 bytes
→ 트랜잭션에 포함됨
```

**작동 원리:**

```python
# 1. Blob을 다항식으로 변환
polynomial = blob_to_polynomial(blob)

# 2. KZG Commitment 계산
commitment = commit_to_polynomial(polynomial)  # 48 bytes

# 3. Versioned Hash 생성
versioned_hash = kzg_to_versioned_hash(commitment)  # 32 bytes

# 4. 트랜잭션에 versioned_hash 포함
tx.blobVersionedHashes = [versioned_hash]

# 5. 검증자가 Blob과 commitment 일치 확인
assert verify_blob_kzg_proof(blob, commitment)
```

### 3. Blob 가스 시장

Blob은 일반 가스와 **별도의 가스 시장**을 사용합니다 (EIP-1559 스타일).

```solidity
// Blob 가스 가격 계산
function calculate_blob_gas_price(excess_blob_gas) returns (uint256) {
    return fake_exponential(
        MIN_BLOB_GASPRICE,
        excess_blob_gas,
        BLOB_GASPRICE_UPDATE_FRACTION
    );
}

// EIP-1559 스타일 지수 함수
function fake_exponential(factor, numerator, denominator) returns (uint256) {
    // e^(numerator/denominator) 근사
    // ...
}
```

**파라미터:**

```
MIN_BLOB_GASPRICE: 1 wei
TARGET_BLOB_GAS_PER_BLOCK: 393,216 (3 blobs)
MAX_BLOB_GAS_PER_BLOCK: 786,432 (6 blobs)
BLOB_GASPRICE_UPDATE_FRACTION: 3,338,477

각 Blob: 131,072 gas
```

**가격 메커니즘:**

```
target보다 많이 사용:
→ 가격 상승 (지수적)

target보다 적게 사용:
→ 가격 하락 (지수적)

최소 가격: 1 wei
최대 가격: 무제한 (수요에 따라)
```

### 4. Blob 저장 기간

```
저장 기간: ~18일 (4096 epoch)
→ 1 epoch = 32 slots = 6.4분
→ 4096 epoch = 약 18일

이후:
→ Beacon Node에서 자동 삭제
→ KZG commitment는 영구 보존
→ Archive node는 계속 보관 가능
```

**왜 18일?**

```
L2 롤업의 Challenge Period:
- Optimism: 7일
- Arbitrum: 7일
- Base: 7일

→ 18일이면 충분한 검증 시간 확보
→ 이후에는 데이터 불필요
→ 스토리지 부담 감소
```

### 5. BLOBBASEFEE Opcode

EVM에 새로운 opcode 추가:

```solidity
// 0x4A: BLOBBASEFEE
assembly {
    let blobGasPrice := blobbasefee()
}

// 현재 블록의 blob gas price 반환
// 일반 가스 가격(basefee)과 독립적
```

### 6. POINT_EVALUATION Precompile

Blob의 KZG proof를 검증하는 precompiled contract:

```solidity
// 0x0A: POINT_EVALUATION_PRECOMPILE
address constant POINT_EVALUATION = 0x000000000000000000000000000000000000000A;

function verifyKZGProof(
    bytes32 versionedHash,
    bytes32 z,
    bytes32 y,
    bytes48 commitment,
    bytes48 proof
) external view returns (bool) {
    (bool success, bytes memory result) = POINT_EVALUATION.staticcall(
        abi.encodePacked(versionedHash, z, y, commitment, proof)
    );

    return success && abi.decode(result, (bool));
}
```

## Blob 트랜잭션 구조

### Type 3 트랜잭션 형식

```javascript
// RLP 인코딩
0x03 || rlp([
    chain_id,
    nonce,
    max_priority_fee_per_gas,
    max_fee_per_gas,
    gas_limit,
    to,
    value,
    data,
    access_list,
    max_fee_per_blob_gas,       // 새로운 필드
    blob_versioned_hashes,      // 새로운 필드
    signature_y_parity,
    signature_r,
    signature_s
])

// Blob은 별도로 전송 (네트워크 레이어)
blobs: [blob1, blob2, ...]
commitments: [commitment1, commitment2, ...]
proofs: [proof1, proof2, ...]
```

### Blob Sidecar

Blob은 트랜잭션 본체와 분리되어 **Sidecar**로 전송됩니다:

```json
{
  "beacon_block_root": "0x...",
  "index": 0,
  "slot": 123456,
  "block_root": "0x...",
  "block_parent_root": "0x...",
  "proposer_index": 42,
  "blob": "0x...",  // 128KB 데이터
  "kzg_commitment": "0x...",  // 48 bytes
  "kzg_proof": "0x..."  // 48 bytes
}
```

### 트랜잭션 검증

```python
def validate_blob_transaction(tx):
    # 1. Type 확인
    assert tx.type == 3

    # 2. Blob 수 확인
    assert len(tx.blob_versioned_hashes) > 0
    assert len(tx.blob_versioned_hashes) <= MAX_BLOBS_PER_BLOCK

    # 3. Versioned hash 형식 확인
    for vhash in tx.blob_versioned_hashes:
        assert vhash[0] == BLOB_COMMITMENT_VERSION_KZG  # 0x01

    # 4. Blob gas 확인
    assert tx.max_fee_per_blob_gas >= MIN_BLOB_GASPRICE

    # 5. 서명 검증
    assert verify_signature(tx)

    # 6. KZG proof 검증
    for i, vhash in enumerate(tx.blob_versioned_hashes):
        assert verify_blob_kzg_proof(
            tx.blobs[i],
            tx.commitments[i],
            tx.proofs[i]
        )
        assert kzg_to_versioned_hash(tx.commitments[i]) == vhash
```

## 작동 원리

### 전체 흐름

```
┌─────────────┐
│ L2 Sequencer│
└──────┬──────┘
       │ 1. 트랜잭션 배치 생성
       ↓
┌─────────────┐
│  Blob 생성  │ (128KB 데이터)
└──────┬──────┘
       │ 2. KZG commitment 계산
       ↓
┌─────────────────┐
│ Type 3 트랜잭션 │
│ + Blob Sidecar  │
└──────┬──────────┘
       │ 3. L1에 제출
       ↓
┌─────────────┐
│ Beacon Chain│
└──────┬──────┘
       │ 4. 검증 & 저장
       ↓
┌─────────────┐
│  ~18일 보관 │
└──────┬──────┘
       │ 5. 자동 삭제
       ↓
┌─────────────┐
│ Commitment  │ (영구 보존)
└─────────────┘
```

### 1. L2에서 Blob 생성

```python
# L2 Sequencer
class RollupSequencer:
    def create_batch(self, transactions):
        # 1. 트랜잭션들을 배치로 압축
        batch_data = compress_transactions(transactions)

        # 2. Blob 생성 (128KB)
        blob = create_blob(batch_data)

        # 3. KZG commitment 계산
        commitment = compute_kzg_commitment(blob)
        proof = compute_kzg_proof(blob, commitment)

        # 4. Versioned hash 생성
        versioned_hash = kzg_to_versioned_hash(commitment)

        return blob, commitment, proof, versioned_hash
```

### 2. L1에 트랜잭션 제출

```javascript
// L2 Sequencer가 L1 Rollup Contract 호출
const tx = await rollupContract.postBatchWithBlob(
    batchIndex,
    stateRoot,
    blobVersionedHashes,
    {
        type: 3,
        maxFeePerBlobGas: blobGasPrice,
        blobs: [blob],
        kzgCommitments: [commitment],
        kzgProofs: [proof]
    }
);
```

### 3. L1 Rollup Contract 검증

```solidity
// L1 Rollup Contract
contract RollupContract {
    event BatchPosted(
        uint256 indexed batchIndex,
        bytes32 indexed stateRoot,
        bytes32 blobHash
    );

    function postBatchWithBlob(
        uint256 batchIndex,
        bytes32 stateRoot,
        bytes32[] calldata blobVersionedHashes
    ) external {
        require(msg.sender == sequencer, "Not sequencer");
        require(blobVersionedHashes.length > 0, "No blobs");

        // Blob hash 저장 (데이터는 읽을 수 없음!)
        bytes32 blobHash = blobVersionedHashes[0];

        // 상태 업데이트
        batches[batchIndex] = Batch({
            stateRoot: stateRoot,
            blobHash: blobHash,
            timestamp: block.timestamp
        });

        emit BatchPosted(batchIndex, stateRoot, blobHash);
    }

    // Blob 데이터는 EVM에서 직접 읽을 수 없음
    // → Beacon Chain API로 조회 필요
}
```

### 4. Beacon Node에서 Blob 조회

```javascript
// Blob 데이터 조회
async function fetchBlob(blockNumber, blobIndex) {
    const beaconBlockRoot = await getBeaconBlockRoot(blockNumber);

    // Beacon Node API
    const response = await fetch(
        `https://beacon-node/eth/v1/beacon/blob_sidecars/${beaconBlockRoot}`
    );

    const sidecars = await response.json();
    return sidecars.data[blobIndex].blob;
}

// KZG proof 검증
async function verifyBlob(blob, commitment, proof, versionedHash) {
    const verified = await POINT_EVALUATION_PRECOMPILE.call({
        data: ethers.utils.concat([
            versionedHash,
            z,  // evaluation point
            y,  // claimed value
            commitment,
            proof
        ])
    });

    return verified;
}
```

### 5. 18일 후 자동 삭제

```
Beacon Node:
→ 4096 epoch (약 18일) 후 Blob 자동 삭제
→ Commitment만 beacon block에 영구 보존
→ Archive node는 계속 보관 가능

사용자:
→ 18일 내에 Blob 다운로드 필요
→ 이후에는 Archive node 또는 L2 DA 레이어에서 조회
```

## 실전 예제

### 1. Blob 생성 (Python)

```python
from eth_utils import keccak
from py_ecc.bls import G1ProofOfPossession as bls

# Blob 생성
def create_blob(data: bytes) -> list[int]:
    """데이터를 Blob (4096 field elements)로 변환"""

    FIELD_ELEMENTS_PER_BLOB = 4096
    BYTES_PER_FIELD_ELEMENT = 32

    # 데이터를 field element로 분할
    blob = []
    for i in range(FIELD_ELEMENTS_PER_BLOB):
        start = i * BYTES_PER_FIELD_ELEMENT
        end = start + BYTES_PER_FIELD_ELEMENT

        if start < len(data):
            chunk = data[start:end]
            # 32 bytes로 패딩
            chunk = chunk.ljust(BYTES_PER_FIELD_ELEMENT, b'\x00')
        else:
            chunk = b'\x00' * BYTES_PER_FIELD_ELEMENT

        # bytes를 정수로 변환
        field_element = int.from_bytes(chunk, 'big')
        blob.append(field_element)

    return blob

# KZG Commitment 계산
def compute_kzg_commitment(blob: list[int]) -> bytes:
    """Blob의 KZG commitment 계산"""

    # 1. Blob을 다항식 계수로 변환
    polynomial = blob

    # 2. KZG commitment 계산 (BLS12-381)
    # G1 점으로 commitment 생성
    commitment = compute_commitment_from_polynomial(polynomial)

    return commitment  # 48 bytes

# Versioned Hash 생성
def kzg_to_versioned_hash(commitment: bytes) -> bytes:
    """KZG commitment를 versioned hash로 변환"""

    # SHA-256 해시
    hash_bytes = keccak(commitment)

    # 첫 바이트를 version (0x01)으로 교체
    return bytes([0x01]) + hash_bytes[1:]

# 사용 예제
data = b"Hello, Blob!" * 1000  # 배치 데이터
blob = create_blob(data)
commitment = compute_kzg_commitment(blob)
versioned_hash = kzg_to_versioned_hash(commitment)

print(f"Blob size: {len(blob)} field elements")
print(f"Commitment: {commitment.hex()}")
print(f"Versioned hash: {versioned_hash.hex()}")
```

### 2. Blob 트랜잭션 전송 (JavaScript)

```javascript
const { ethers } = require('ethers');

// Blob 트랜잭션 전송
async function sendBlobTransaction(provider, signer, rollupContract, blobData) {
    // 1. Blob 생성
    const blob = createBlob(blobData);  // 128KB

    // 2. KZG commitment & proof 계산
    const { commitment, proof, versionedHash } = await computeKZG(blob);

    // 3. Blob gas price 조회
    const blobGasPrice = await provider.getBlobBaseFee();

    // 4. Type 3 트랜잭션 생성
    const tx = {
        type: 3,
        to: rollupContract.address,
        nonce: await signer.getTransactionCount(),

        // 일반 가스
        maxFeePerGas: ethers.utils.parseUnits('50', 'gwei'),
        maxPriorityFeePerGas: ethers.utils.parseUnits('2', 'gwei'),
        gasLimit: 100000,

        // Blob 가스
        maxFeePerBlobGas: blobGasPrice * 2n,  // 2배 여유

        // Blob 해시
        blobVersionedHashes: [versionedHash],

        // Calldata
        data: rollupContract.interface.encodeFunctionData('postBatch', [
            batchIndex,
            stateRoot,
            [versionedHash]
        ]),

        value: 0,
        chainId: 1
    };

    // 5. Blob sidecar 첨부
    tx.blobs = [blob];
    tx.kzgCommitments = [commitment];
    tx.kzgProofs = [proof];

    // 6. 서명 & 전송
    const signedTx = await signer.signTransaction(tx);
    const receipt = await provider.sendTransaction(signedTx);

    console.log('Blob transaction sent:', receipt.hash);
    return receipt;
}

// 사용 예제
const provider = new ethers.providers.JsonRpcProvider('https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY');
const signer = new ethers.Wallet(privateKey, provider);

const blobData = compressBatch(transactions);  // 128KB 이하
await sendBlobTransaction(provider, signer, rollupContract, blobData);
```

### 3. Blob 조회 (Beacon API)

```javascript
// Beacon Chain에서 Blob 조회
async function fetchBlobFromBeacon(blockNumber) {
    // 1. Execution block에서 beacon block root 조회
    const block = await provider.getBlock(blockNumber);
    const beaconBlockRoot = block.parentBeaconBlockRoot;

    // 2. Beacon API로 blob sidecars 조회
    const response = await fetch(
        `https://beacon-node/eth/v1/beacon/blob_sidecars/${beaconBlockRoot}`
    );

    const data = await response.json();

    // 3. Blob sidecars 파싱
    const sidecars = data.data;

    for (const sidecar of sidecars) {
        console.log('Blob index:', sidecar.index);
        console.log('Commitment:', sidecar.kzg_commitment);
        console.log('Blob size:', sidecar.blob.length);

        // 4. KZG proof 검증
        const verified = await verifyKZGProof(
            sidecar.blob,
            sidecar.kzg_commitment,
            sidecar.kzg_proof
        );

        console.log('Verified:', verified);
    }

    return sidecars;
}

// KZG proof 검증
async function verifyKZGProof(blob, commitment, proof) {
    const POINT_EVALUATION = '0x000000000000000000000000000000000000000A';

    // Versioned hash 계산
    const versionedHash = kzgToVersionedHash(commitment);

    // Precompile 호출
    const result = await provider.call({
        to: POINT_EVALUATION,
        data: ethers.utils.concat([
            versionedHash,
            ethers.utils.randomBytes(32),  // z (evaluation point)
            ethers.utils.randomBytes(32),  // y (claimed value)
            commitment,
            proof
        ])
    });

    return result !== '0x';
}

// 사용 예제
const blockNumber = 19000000;  // Dencun 이후 블록
const blobs = await fetchBlobFromBeacon(blockNumber);
```

### 4. L2 Rollup Contract 구현

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract OptimisticRollup {
    address public sequencer;

    struct Batch {
        bytes32 stateRoot;
        bytes32 blobHash;
        uint256 timestamp;
        uint256 l1BlockNumber;
    }

    mapping(uint256 => Batch) public batches;
    uint256 public latestBatchIndex;

    event BatchPosted(
        uint256 indexed batchIndex,
        bytes32 indexed stateRoot,
        bytes32 blobHash,
        uint256 l1BlockNumber
    );

    constructor(address _sequencer) {
        sequencer = _sequencer;
    }

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
            timestamp: block.timestamp,
            l1BlockNumber: block.number
        });

        latestBatchIndex = batchIndex;

        emit BatchPosted(batchIndex, stateRoot, blobHash, block.number);
    }

    // Challenge: Fraud Proof 제출
    function challengeBatch(
        uint256 batchIndex,
        bytes calldata fraudProof
    ) external {
        Batch memory batch = batches[batchIndex];
        require(batch.timestamp > 0, "Batch not found");
        require(
            block.timestamp <= batch.timestamp + 7 days,
            "Challenge period expired"
        );

        // Fraud proof 검증
        // → Blob 데이터는 Beacon API에서 조회하여 오프체인에서 검증
        // → 성공 시 배치 롤백

        // ...
    }

    // Finalize: Challenge period 이후 확정
    function finalizeBatch(uint256 batchIndex) external {
        Batch memory batch = batches[batchIndex];
        require(batch.timestamp > 0, "Batch not found");
        require(
            block.timestamp > batch.timestamp + 7 days,
            "Challenge period not over"
        );

        // 배치 확정
        // ...
    }

    // Blob 가스 가격 조회
    function getBlobBaseFee() public view returns (uint256) {
        return block.blobbasefee;  // 0x4A opcode
    }
}
```

### 5. Blob 데이터 디코딩

```javascript
// Blob에서 원본 데이터 추출
function decodeBlobData(blob) {
    const FIELD_ELEMENTS_PER_BLOB = 4096;
    const BYTES_PER_FIELD_ELEMENT = 32;

    // Blob은 field element 배열
    const data = [];

    for (let i = 0; i < FIELD_ELEMENTS_PER_BLOB; i++) {
        const fieldElement = blob[i];

        // 정수를 bytes로 변환
        const bytes = ethers.utils.arrayify(
            ethers.BigNumber.from(fieldElement)
        );

        // 32 bytes로 패딩
        const paddedBytes = ethers.utils.zeroPad(bytes, BYTES_PER_FIELD_ELEMENT);

        data.push(...paddedBytes);
    }

    // 원본 데이터 추출 (끝의 0 제거)
    const dataBytes = Buffer.from(data);
    const originalData = removeTrailingZeros(dataBytes);

    return originalData;
}

// 배치 데이터 압축 해제
function decompressBatch(blobData) {
    // L2마다 다른 압축 방식 사용
    // 예: zlib, brotli 등

    const decompressed = zlib.inflateSync(blobData);
    const transactions = rlp.decode(decompressed);

    return transactions;
}

// 사용 예제
const blob = await fetchBlobFromBeacon(blockNumber);
const blobData = decodeBlobData(blob[0].blob);
const transactions = decompressBatch(blobData);

console.log('Transactions in batch:', transactions.length);
```

## L2 통합

### Optimistic Rollup 통합

```solidity
// Optimism Bedrock 스타일
contract OptimismPortal {
    // Blob으로 배치 제출
    function depositTransaction(
        address _to,
        uint256 _value,
        uint64 _gasLimit,
        bool _isCreation,
        bytes memory _data,
        bytes32[] memory _blobVersionedHashes
    ) public payable {
        require(_blobVersionedHashes.length <= 6, "Too many blobs");

        // L2 트랜잭션 큐에 추가
        // Blob 데이터는 Beacon Chain에서 조회

        emit TransactionDeposited(
            msg.sender,
            _to,
            _value,
            _data,
            _blobVersionedHashes[0]
        );
    }
}
```

### ZK Rollup 통합

```solidity
// zkSync Era 스타일
contract ZKRollup {
    // Blob으로 배치 + ZK proof 제출
    function commitBatches(
        StoredBatchInfo memory _lastCommittedBatchData,
        CommitBatchInfo[] calldata _newBatchesData,
        bytes32[] calldata _blobVersionedHashes
    ) external {
        require(msg.sender == validator, "Not validator");

        // ZK proof 검증
        // Blob 데이터로 state transition 검증

        for (uint256 i = 0; i < _newBatchesData.length; i++) {
            _commitOneBatch(_newBatchesData[i], _blobVersionedHashes[i]);
        }
    }

    function proveBatches(
        StoredBatchInfo calldata _prevBatch,
        StoredBatchInfo[] calldata _committedBatches,
        ProofInput calldata _proof
    ) external {
        // ZK proof 검증
        require(verifyProof(_proof), "Invalid proof");

        // 배치 확정
        // ...
    }
}
```

### 실제 L2 사용 현황 (2024년)

```
Optimism:
- Dencun 이전: $0.50/txn
- Dencun 이후: $0.05/txn
- 절감: 90%

Arbitrum:
- Dencun 이전: $0.30/txn
- Dencun 이후: $0.03/txn
- 절감: 90%

Base:
- Dencun 이전: $0.40/txn
- Dencun 이후: $0.04/txn
- 절감: 90%

zkSync Era:
- Dencun 이전: $0.25/txn
- Dencun 이후: $0.02/txn
- 절감: 92%
```

## 보안 고려사항

### 1. Blob 가용성 보장

```
문제: 18일 후 Blob 삭제

해결책:
1. Archive Node 운영
   → Full history 보관

2. L2 DA 레이어
   → Celestia, EigenDA 등

3. L2 자체 스토리지
   → Sequencer가 영구 보관
```

**모범 사례:**

```javascript
// L2 Sequencer는 Blob을 영구 보관해야 함
class BlobArchive {
    async storeBlob(blobHash, blobData) {
        // 1. 로컬 스토리지에 저장
        await this.localStorage.put(blobHash, blobData);

        // 2. 백업 스토리지에 저장
        await this.s3.upload(blobHash, blobData);

        // 3. DA 레이어에 저장 (선택)
        await this.celestia.submit(blobData);
    }

    async getBlob(blobHash) {
        // 1. Beacon Chain에서 시도 (18일 내)
        const blob = await this.beaconAPI.getBlob(blobHash);
        if (blob) return blob;

        // 2. 로컬 스토리지에서 조회
        const localBlob = await this.localStorage.get(blobHash);
        if (localBlob) return localBlob;

        // 3. 백업 스토리지에서 조회
        return await this.s3.download(blobHash);
    }
}
```

### 2. KZG Trusted Setup

```
KZG Commitment는 Trusted Setup 필요:

이더리움 Trusted Setup Ceremony:
- 2023년에 진행
- 140,000명 이상 참여
- Powers of Tau
- 단 1명만 정직하면 안전

결과:
→ 공개 파라미터 생성
→ 모든 KZG 연산에 사용
```

### 3. Blob 가스 시장 조작 방지

```solidity
// ❌ 위험: Blob 가스 시장 조작
// 공격자가 의도적으로 많은 Blob을 제출하여 가격 상승

// ✅ 안전: 지수적 가격 메커니즘
// → 수요 급증 시 가격 급등
// → 공격 비용 매우 높음

// Sequencer는 동적으로 대응
if (blobGasPrice > threshold) {
    // Blob 사용 연기
    waitForLowerPrice();
} else {
    // Blob 제출
    submitBlob();
}
```

### 4. Blob 데이터 검증

```javascript
// ❌ 위험: Blob 데이터 신뢰 없이 사용
const blob = await fetchBlob(blobHash);
const data = decodeBlob(blob);
// → 데이터 무결성 미확인!

// ✅ 안전: KZG proof 검증
const blob = await fetchBlob(blobHash);
const commitment = await getCommitment(blobHash);
const proof = await getProof(blobHash);

const verified = await verifyKZGProof(blob, commitment, proof);
require(verified, "Blob verification failed");

const data = decodeBlob(blob);
```

### 5. Challenge Period 보장

```solidity
// Optimistic Rollup은 Challenge Period 필수

contract SafeRollup {
    uint256 constant CHALLENGE_PERIOD = 7 days;

    function finalizeBatch(uint256 batchIndex) external {
        Batch memory batch = batches[batchIndex];

        // Challenge Period 확인
        require(
            block.timestamp > batch.timestamp + CHALLENGE_PERIOD,
            "Challenge period not over"
        );

        // 18일 내 Blob 가용성 보장
        require(
            block.number - batch.l1BlockNumber < 18 * 7200,  // ~18일
            "Blob may be unavailable"
        );

        // 배치 확정
        // ...
    }
}
```

## 실제 영향

### L2 처리량 증가

```
블록당 데이터 용량:

Before EIP-4844:
→ CALLDATA: ~15MB/block
→ L2 처리량: ~300 TPS (all L2s combined)

After EIP-4844:
→ Blob: 375KB - 750KB/block (3-6 blobs)
→ But: Blob 전용, CALLDATA와 병행
→ L2 처리량: ~3,000 TPS (10배 증가)

Future (Full Danksharding):
→ Target: 16MB/block (128 blobs)
→ L2 처리량: ~100,000 TPS (300배 증가)
```

### 사용자 수수료 절감

```
실제 사례 (2024년 3-4월):

Optimism:
- ETH Transfer: $0.50 → $0.05 (90% 감소)
- Uniswap Swap: $2.00 → $0.20 (90% 감소)
- NFT Mint: $1.50 → $0.15 (90% 감소)

Arbitrum:
- ETH Transfer: $0.30 → $0.03 (90% 감소)
- Uniswap Swap: $1.50 → $0.15 (90% 감소)

Base:
- ETH Transfer: $0.40 → $0.04 (90% 감소)
- Social Post: $0.20 → $0.02 (90% 감소)
```

### 네트워크 사용량

```
Blob 사용 통계 (2024년 3-6월):

일일 Blob 수: 5,000 - 15,000 blobs
일일 데이터: 640GB - 1.9TB
평균 Blob gas price: 1-100 gwei (변동)

주요 사용자:
1. Arbitrum: 40%
2. Optimism: 30%
3. Base: 20%
4. 기타 L2: 10%
```

### 노드 부담 감소

```
Full Node 스토리지 증가:

Before EIP-4844:
→ L2 데이터가 CALLDATA에 영구 저장
→ 연간 ~5TB 증가

After EIP-4844:
→ Blob은 18일 후 삭제
→ Commitment만 영구 저장 (48 bytes)
→ 연간 ~500GB 증가 (10분의 1)
```

## FAQ

### Q1: Blob은 왜 EVM에서 읽을 수 없나?

**A:** 설계상 의도된 제약입니다:

```
이유:
1. Blob은 Data Availability 전용
   → L2 검증용, 일반 컨트랙트 로직에 불필요

2. 큰 데이터 로드 방지
   → 128KB를 EVM에 로드하면 가스 비용 폭발
   → DoS 공격 벡터

3. 일관성 보장
   → 18일 후 삭제되므로 EVM 결과 불일치

대안:
→ Blob hash만 저장
→ 필요시 Beacon API로 조회
```

### Q2: 18일이 지나면 데이터가 완전히 사라지나?

**A:** 일부 노드에서는 계속 보관됩니다:

```
삭제되는 곳:
→ 일반 Beacon Node (대부분)

보관하는 곳:
→ Archive Node
→ L2 Sequencer
→ Blobscan 같은 Explorer
→ DA 레이어 (Celestia 등)

사용자 입장:
→ Beacon API (18일 내)
→ Archive API (이후)
→ L2 RPC (영구)
```

### Q3: Blob 가스 가격은 어떻게 결정되나?

**A:** EIP-1559 스타일의 동적 가격:

```javascript
// Target: 3 blobs/block
// Max: 6 blobs/block

if (usage > target) {
    price += price * excess / UPDATE_FRACTION;
    // 지수적 상승
} else {
    price -= price * deficit / UPDATE_FRACTION;
    // 지수적 하락
}

// 최소 가격: 1 wei
// 일반적: 1-100 gwei
// 혼잡시: 수백 gwei
```

### Q4: 여러 Blob을 하나의 트랜잭션에 첨부할 수 있나?

**A:** 네, 최대 6개까지 가능합니다:

```javascript
const tx = {
    type: 3,
    blobVersionedHashes: [
        hash1,  // Blob 1
        hash2,  // Blob 2
        hash3,  // Blob 3
        // 최대 6개
    ],
    blobs: [blob1, blob2, blob3],
    // ...
};

// 각 Blob: 128KB
// 최대: 768KB
```

### Q5: Full Danksharding과의 차이는?

**A:** Proto-Danksharding은 첫 단계입니다:

```
Proto-Danksharding (EIP-4844) - 현재:
→ Target: 3 blobs/block (375KB)
→ Max: 6 blobs/block (750KB)
→ 모든 validator가 모든 Blob 검증

Full Danksharding - 미래:
→ Target: 128 blobs/block (16MB)
→ Data Availability Sampling (DAS)
→ Validator는 일부만 검증 (샘플링)
→ 100,000 TPS 목표
```

### Q6: Blob은 롤백될 수 있나?

**A:** 트랜잭션과 동일하게 처리됩니다:

```
Reorg 시:
→ 트랜잭션이 롤백되면 Blob도 롤백
→ Commitment도 함께 롤백

Finality 후:
→ Blob 확정
→ 롤백 불가능
```

### Q7: Blob 없이도 L2를 운영할 수 있나?

**A:** 네, 여전히 CALLDATA 사용 가능합니다:

```solidity
// Option 1: Blob (저렴, 권장)
function postBatchWithBlob(bytes32[] calldata blobHashes) external {}

// Option 2: CALLDATA (비쌈, 호환성)
function postBatchWithCalldata(bytes calldata data) external {}

// L2는 상황에 따라 선택 가능
```

### Q8: Blob 데이터는 암호화되나?

**A:** 아니요, 공개 데이터입니다:

```
Blob 데이터:
→ 누구나 조회 가능
→ Beacon API로 공개
→ L2 트랜잭션 내용 공개

프라이버시:
→ L2 레벨에서 처리
→ 예: zkRollup은 proof만 공개
```

### Q9: Blob 사용 시 감사는 어떻게?

**A:** KZG commitment로 검증 가능합니다:

```javascript
// 감사자
async function auditBatch(batchIndex) {
    // 1. L1 rollup contract에서 commitment 조회
    const commitment = await rollup.getBatchCommitment(batchIndex);

    // 2. Blob 다운로드
    const blob = await fetchBlob(batchIndex);

    // 3. Commitment 검증
    const verified = await verifyKZGProof(blob, commitment, proof);

    // 4. Blob 데이터 파싱 & 검증
    const transactions = decodeBlobData(blob);
    const stateRoot = computeStateRoot(transactions);

    // 5. State root 일치 확인
    assert(stateRoot === onChainStateRoot);
}
```

### Q10: Proto-Danksharding은 언제 활성화되었나?

**A:** 2024년 3월 13일, Dencun 하드포크:

```
Dencun 하드포크:
→ Cancun (Execution Layer)
→ Deneb (Consensus Layer)
→ 블록 높이: 19,426,587

포함된 EIP:
→ EIP-4844: Blob transactions
→ EIP-1153: Transient storage
→ EIP-4788: Beacon block root
→ EIP-5656: MCOPY opcode
→ EIP-6780: SELFDESTRUCT 제한
→ EIP-7516: BLOBBASEFEE opcode
```

## 참고 자료

### 공식 문서
- [EIP-4844 Specification](https://eips.ethereum.org/EIPS/eip-4844)
- [Danksharding Roadmap](https://ethereum.org/en/roadmap/danksharding/)
- [KZG Ceremony](https://ceremony.ethereum.org/)

### 도구
- [Blobscan](https://blobscan.com/) - Blob 탐색기
- [Blobs.io](https://blobs.io/) - Blob 통계
- [L2BEAT](https://l2beat.com/) - L2 사용 현황

### 라이브러리
- [c-kzg](https://github.com/ethereum/c-kzg-4844) - KZG 라이브러리
- [ethers.js v6](https://docs.ethers.org/v6/) - Blob 트랜잭션 지원
- [viem](https://viem.sh/) - TypeScript 라이브러리

### 블로그 & 아티클
- [Vitalik: Proto-Danksharding FAQ](https://notes.ethereum.org/@vbuterin/proto_danksharding_faq)
- [Domothy: EIP-4844 Deep Dive](https://domothy.com/blobspace/)
- [EF Blog: Dencun Upgrade](https://blog.ethereum.org/2024/03/13/dencun-mainnet-announcement)

### L2 통합 가이드
- [Optimism Bedrock](https://specs.optimism.io/protocol/derivation.html#blob-encoding)
- [Arbitrum Nitro](https://docs.arbitrum.io/how-arbitrum-works/inside-arbitrum-nitro)
- [zkSync Era](https://docs.zksync.io/zk-stack/concepts/data-availability)

---

**작성일**: 2025년 1월
**EIP 상태**: Final
**활성화**: 2024년 3월 13일 (Dencun)

EIP-4844는 이더리움 확장성의 핵심 기술로, L2 롤업의 대중화를 가능하게 했습니다! 🚀
