# EIP-1559: Fee Market Change (  )

##
1. [](#)
2. [EIP-1559  vs ](#eip-1559--vs-)
3. [ ](#-)
4. [Base Fee  ](#base-fee--)
5. [ ](#-)
6. [](#)
7. [  ](#--)
8. [  ](#--)
9. [Frontend  (ethers.js)](#frontend--ethersjs)
10. [ ](#-)

---

##

**EIP-1559** 2021 8 5        .

###
- **    **:     
- **  **: Base fee    
- **  **:     
- **ETH **: Base fee    

---

## EIP-1559  vs

### Before EIP-1559 (Legacy )

```solidity
// First-Price Auction 
{
    gasPrice: 100 gwei,  //      
    gasLimit: 21000
}
```

**:**
1. **  **:     
2. ** **:      
3. ** **:       
4. **UX **:     

### After EIP-1559 (Type 2 )

```solidity
// Base Fee + Priority Fee 
{
    maxFeePerGas: 100 gwei,           //     
    maxPriorityFeePerGas: 2 gwei,    //   
    gasLimit: 21000
}
```

**:**
1. ** **: Base fee   
2. ** **:    ( )
3. ** **: Priority fee  
4. **ETH **: Base fee    ()

---

##

### 1. Base Fee ( )

```solidity
//     
uint256 baseFee = block.basefee;  // BASEFEE opcode (0x48)
```

**:**
-    (  )
-      
- **** (Burn):   
-    

### 2. Priority Fee ( /)

```solidity
//   
uint256 priorityFee = min(
    maxPriorityFeePerGas,
    maxFeePerGas - block.basefee
);
```

**:**
-   
- / 
-   
-  1-2 gwei 

### 3. Max Fee Per Gas

```solidity
//      
maxFeePerGas >= block.basefee + maxPriorityFeePerGas
```

**:**
- Base fee + Priority fee 
- Base fee     
-      

### 4.

```solidity
//   
uint256 effectiveGasPrice = block.basefee + min(
    maxPriorityFeePerGas,
    maxFeePerGas - block.basefee
);

uint256 totalFee = effectiveGasPrice * gasUsed;

// 
uint256 refund = (maxFeePerGas - effectiveGasPrice) * gasUsed;
```

---

## Base Fee

###

```solidity
//    
uint256 constant BLOCK_GAS_TARGET = 15_000_000;  //  
uint256 constant BLOCK_GAS_LIMIT = 30_000_000;   //   (2x target)
```

###

```solidity
//   Base Fee 
function calculateNextBaseFee(
    uint256 currentBaseFee,
    uint256 parentGasUsed,
    uint256 parentGasTarget
) public pure returns (uint256) {
    if (parentGasUsed == parentGasTarget) {
        return currentBaseFee;  //   
    }

    if (parentGasUsed > parentGasTarget) {
        //  50%   Base Fee  ( 12.5% )
        uint256 gasUsedDelta = parentGasUsed - parentGasTarget;
        uint256 baseFeePerGasDelta = max(
            currentBaseFee * gasUsedDelta / parentGasTarget / 8,
            1
        );
        return currentBaseFee + baseFeePerGasDelta;
    } else {
        //  50%  Base Fee  ( 12.5% )
        uint256 gasUsedDelta = parentGasTarget - parentGasUsed;
        uint256 baseFeePerGasDelta =
            currentBaseFee * gasUsedDelta / parentGasTarget / 8;
        return currentBaseFee - baseFeePerGasDelta;
    }
}
```

**:**
-    12.5% 
- 8 ( 2)  2     
-    

---

##

### Type 2  (EIP-1559)

```javascript
// ethers.js v6
const tx = await wallet.sendTransaction({
    to: "0x...",
    value: ethers.parseEther("1.0"),
    maxFeePerGas: ethers.parseUnits("100", "gwei"),
    maxPriorityFeePerGas: ethers.parseUnits("2", "gwei"),
    gasLimit: 21000,
    type: 2  // EIP-1559 
});
```

### Legacy  ( )

```javascript
//   
const tx = await wallet.sendTransaction({
    to: "0x...",
    value: ethers.parseEther("1.0"),
    gasPrice: ethers.parseUnits("100", "gwei"),
    gasLimit: 21000,
    type: 0  // Legacy 
});
```

---

##

### 1.     (Better UX)

```javascript
// Before:   
gasPrice = guessPrice();  // 50 gwei? 100 gwei? 200 gwei?

// After:   
const feeData = await provider.getFeeData();
maxFeePerGas = feeData.maxFeePerGas;  //  
maxPriorityFeePerGas = feeData.maxPriorityFeePerGas;
```

### 2.   (Fee Burning)

```solidity
// Base Fee 
//     ETH  

// :   
// Base Fee: 30 gwei
//   : ~100M gas
// : 30 * 100M = 3000 ETH/day
```

**:**
- ETH   ( )
-      , Priority fee + MEV 
-   ETH   

### 3.   (Predictability)

```javascript
// Base fee   12.5% 
//    Base fee  

function predictBaseFee(currentBaseFee, blocksAhead) {
    //   (  12.5% )
    return currentBaseFee * Math.pow(1.125, blocksAhead);
}

// :  30 gwei
// 1  : 33.75 gwei
// 5  : 54.3 gwei
```

### 4.

```solidity
//    ( 2x target)
//          
//       
```

---

##

### 1. BASEFEE Opcode

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BaseFeeChecker {
    // block.basefee Solidity 0.8.7  

    function getCurrentBaseFee() public view returns (uint256) {
        return block.basefee;  // BASEFEE opcode (0x48)
    }

    function isBaseFeeAcceptable(uint256 maxAcceptable)
        public
        view
        returns (bool)
    {
        return block.basefee <= maxAcceptable;
    }

    //      
    modifier maxBaseFee(uint256 maxFee) {
        require(block.basefee <= maxFee, "Base fee too high");
        _;
    }

    function expensiveOperation() public maxBaseFee(50 gwei) {
        //  50 gwei   
    }
}
```

### 2. Gas Price vs Base Fee

```solidity
contract GasPriceAware {
    // tx.gasprice:    
    // block.basefee:   

    function analyzeGas() public view returns (
        uint256 gasPrice,
        uint256 baseFee,
        uint256 priorityFee
    ) {
        gasPrice = tx.gasprice;          // effectiveGasPrice
        baseFee = block.basefee;         // base fee
        priorityFee = gasPrice - baseFee; // priority fee

        return (gasPrice, baseFee, priorityFee);
    }

    // : tx.gasprice  
    // EIP-1559 effectiveGasPrice 
    function legacyGasPriceCheck() public view {
        require(tx.gasprice >= 20 gwei, "Gas price too low");
        // EIP-1559  
    }
}
```

### 3.

```solidity
contract GasRefundAware {
    // EIP-1559     (EIP-3529)
    // SSTORE : 15000 -> 
    // SELFDESTRUCT : 24000 -> 

    mapping(uint256 => uint256) public data;

    function optimizedStorage(uint256 key, uint256 value) public {
        //        
        if (value == 0) {
            delete data[key];  //  
        } else {
            data[key] = value;
        }
    }
}
```

### 4.

```solidity
contract ReentrancyAndGas {
    mapping(address => uint256) public balances;

    //       
    function withdraw() public {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");

        balances[msg.sender] = 0;

        //     ()
        // EIP-1559  
        (bool success, ) = msg.sender.call{value: amount, gas: 2300}("");
        require(success, "Transfer failed");
    }
}
```

---

##

### 1.

```javascript
// ethers.js v6
const provider = new ethers.JsonRpcProvider("https://eth-mainnet...");

// 1.  Fee Data 
const feeData = await provider.getFeeData();
console.log({
    maxFeePerGas: ethers.formatUnits(feeData.maxFeePerGas, "gwei"),
    maxPriorityFeePerGas: ethers.formatUnits(feeData.maxPriorityFeePerGas, "gwei"),
    gasPrice: ethers.formatUnits(feeData.gasPrice, "gwei") // legacy
});

// 2. Gas Limit 
const gasEstimate = await provider.estimateGas({
    to: "0x...",
    value: ethers.parseEther("1.0"),
    from: wallet.address
});

// 3.    (10%)
const gasLimit = gasEstimate * 110n / 100n;
```

### 2.  Fee

```javascript
//   ( priority fee)
async function sendFastTransaction(wallet, to, value) {
    const feeData = await wallet.provider.getFeeData();

    return await wallet.sendTransaction({
        to,
        value,
        maxFeePerGas: feeData.maxFeePerGas * 120n / 100n,  // 20% 
        maxPriorityFeePerGas: ethers.parseUnits("3", "gwei"), //  
        type: 2
    });
}

//   ( fee)
async function sendNormalTransaction(wallet, to, value) {
    const feeData = await wallet.provider.getFeeData();

    return await wallet.sendTransaction({
        to,
        value,
        maxFeePerGas: feeData.maxFeePerGas,
        maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
        type: 2
    });
}

//   ( priority fee)
async function sendSlowTransaction(wallet, to, value) {
    const block = await wallet.provider.getBlock("latest");
    const baseFee = block.baseFeePerGas;

    return await wallet.sendTransaction({
        to,
        value,
        maxFeePerGas: baseFee * 150n / 100n,  // 50% 
        maxPriorityFeePerGas: ethers.parseUnits("0.5", "gwei"), //  
        type: 2
    });
}
```

### 3.  Fee

```javascript
// Base Fee   
class FeePredictor {
    constructor(provider) {
        this.provider = provider;
        this.baseFeeHistory = [];
    }

    async updateBaseFee() {
        const block = await this.provider.getBlock("latest");
        this.baseFeeHistory.push({
            blockNumber: block.number,
            baseFee: block.baseFeePerGas,
            gasUsed: block.gasUsed,
            gasLimit: block.gasLimit,
            timestamp: block.timestamp
        });

        //  100 
        if (this.baseFeeHistory.length > 100) {
            this.baseFeeHistory.shift();
        }
    }

    predictNextBaseFee(blocksAhead = 1) {
        if (this.baseFeeHistory.length === 0) return null;

        const latest = this.baseFeeHistory[this.baseFeeHistory.length - 1];
        let baseFee = latest.baseFee;

        //     
        const target = latest.gasLimit / 2n;
        const utilizationRate = Number(latest.gasUsed * 100n / target);

        //   (    )
        for (let i = 0; i < blocksAhead; i++) {
            if (utilizationRate > 100) {
                baseFee = baseFee * 1125n / 1000n;  // 12.5% 
            } else if (utilizationRate < 100) {
                baseFee = baseFee * 875n / 1000n;   // 12.5% 
            }
        }

        return baseFee;
    }

    async getOptimalFees() {
        await this.updateBaseFee();

        const currentBaseFee = this.baseFeeHistory[this.baseFeeHistory.length - 1].baseFee;
        const predictedBaseFee = this.predictNextBaseFee(5); // 5 

        return {
            maxFeePerGas: predictedBaseFee * 150n / 100n,  // 50% 
            maxPriorityFeePerGas: ethers.parseUnits("2", "gwei")
        };
    }
}

//  
const predictor = new FeePredictor(provider);
const fees = await predictor.getOptimalFees();
```

### 4.  API

```javascript
// ETH Gas Station, Blocknative, Alchemy  API 
async function getGasFromOracle() {
    // Alchemy API 
    const response = await fetch(
        "https://eth-mainnet.g.alchemy.com/v2/YOUR-API-KEY",
        {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                jsonrpc: "2.0",
                method: "eth_maxPriorityFeePerGas",
                params: [],
                id: 1
            })
        }
    );

    const data = await response.json();
    const maxPriorityFee = BigInt(data.result);

    // Base Fee   
    const block = await provider.getBlock("latest");
    const baseFee = block.baseFeePerGas;

    return {
        maxFeePerGas: baseFee * 2n + maxPriorityFee,  //  
        maxPriorityFeePerGas: maxPriorityFee
    };
}
```

---

## Frontend  (ethers.js)

### 1.

```javascript
import { ethers } from "ethers";

//  
const provider = new ethers.JsonRpcProvider("https://eth-mainnet.g.alchemy.com/v2/YOUR-API-KEY");

//   (MetaMask)
const browserProvider = new ethers.BrowserProvider(window.ethereum);
const signer = await browserProvider.getSigner();
```

### 2. EIP-1559

```javascript
// React  
import { useState } from "react";
import { ethers } from "ethers";

function SendTransaction() {
    const [txHash, setTxHash] = useState("");
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState("");

    async function sendEIP1559Transaction() {
        try {
            setLoading(true);
            setError("");

            // 1.  Signer 
            const provider = new ethers.BrowserProvider(window.ethereum);
            const signer = await provider.getSigner();

            // 2. Fee Data 
            const feeData = await provider.getFeeData();

            // 3. Gas Limit 
            const recipient = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e";
            const amount = ethers.parseEther("0.1");

            const gasEstimate = await provider.estimateGas({
                to: recipient,
                value: amount,
                from: await signer.getAddress()
            });

            // 4.  
            const tx = await signer.sendTransaction({
                to: recipient,
                value: amount,
                maxFeePerGas: feeData.maxFeePerGas,
                maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
                gasLimit: gasEstimate * 120n / 100n,  // 20% 
                type: 2  // EIP-1559
            });

            setTxHash(tx.hash);

            // 5.   
            const receipt = await tx.wait();
            console.log("Transaction confirmed:", receipt);

            // 6.    
            const gasUsed = receipt.gasUsed;
            const effectiveGasPrice = receipt.gasPrice;  // effectiveGasPrice
            const totalFee = gasUsed * effectiveGasPrice;

            console.log(`Total fee paid: ${ethers.formatEther(totalFee)} ETH`);

        } catch (err) {
            setError(err.message);
            console.error(err);
        } finally {
            setLoading(false);
        }
    }

    return (
        <div>
            <button onClick={sendEIP1559Transaction} disabled={loading}>
                {loading ? "Sending..." : "Send Transaction"}
            </button>
            {txHash && <p>Transaction Hash: {txHash}</p>}
            {error && <p style={{ color: "red" }}>Error: {error}</p>}
        </div>
    );
}
```

### 3.  Gas Price

```javascript
import { useEffect, useState } from "react";
import { ethers } from "ethers";

function GasPriceMonitor() {
    const [gasData, setGasData] = useState(null);

    useEffect(() => {
        const provider = new ethers.JsonRpcProvider("https://eth-mainnet...");

        async function updateGasPrice() {
            try {
                // Fee Data 
                const feeData = await provider.getFeeData();

                //   
                const block = await provider.getBlock("latest");

                setGasData({
                    baseFee: ethers.formatUnits(block.baseFeePerGas, "gwei"),
                    maxFee: ethers.formatUnits(feeData.maxFeePerGas, "gwei"),
                    priorityFee: ethers.formatUnits(feeData.maxPriorityFeePerGas, "gwei"),
                    blockNumber: block.number,
                    gasUsed: Number(block.gasUsed * 100n / block.gasLimit)
                });
            } catch (err) {
                console.error("Failed to fetch gas price:", err);
            }
        }

        //  
        updateGasPrice();

        // 12 
        const interval = setInterval(updateGasPrice, 12000);

        return () => clearInterval(interval);
    }, []);

    if (!gasData) return <div>Loading...</div>;

    return (
        <div>
            <h3>Current Gas Prices</h3>
            <p>Block: #{gasData.blockNumber}</p>
            <p>Base Fee: {gasData.baseFee} gwei</p>
            <p>Max Fee: {gasData.maxFee} gwei</p>
            <p>Priority Fee: {gasData.priorityFee} gwei</p>
            <p>Block Utilization: {gasData.gasUsed}%</p>
        </div>
    );
}
```

### 4.   UI

```javascript
function FeeSelector({ onFeeChange }) {
    const [feeSpeed, setFeeSpeed] = useState("standard");
    const [customFees, setCustomFees] = useState(null);
    const [baseFee, setBaseFee] = useState(0n);

    useEffect(() => {
        async function loadBaseFee() {
            const provider = new ethers.JsonRpcProvider("https://eth-mainnet...");
            const block = await provider.getBlock("latest");
            setBaseFee(block.baseFeePerGas);
        }
        loadBaseFee();
    }, []);

    const feeOptions = {
        slow: {
            maxPriorityFee: ethers.parseUnits("1", "gwei"),
            maxFee: baseFee * 130n / 100n,  // base fee 130%
            time: "~3 min"
        },
        standard: {
            maxPriorityFee: ethers.parseUnits("2", "gwei"),
            maxFee: baseFee * 150n / 100n,  // base fee 150%
            time: "~1 min"
        },
        fast: {
            maxPriorityFee: ethers.parseUnits("3", "gwei"),
            maxFee: baseFee * 180n / 100n,  // base fee 180%
            time: "~15 sec"
        }
    };

    function handleSpeedChange(speed) {
        setFeeSpeed(speed);
        const fees = feeOptions[speed];
        onFeeChange({
            maxFeePerGas: fees.maxFee,
            maxPriorityFeePerGas: fees.maxPriorityFee
        });
    }

    return (
        <div>
            <h3>Select Transaction Speed</h3>
            {Object.entries(feeOptions).map(([speed, fees]) => (
                <div key={speed}>
                    <label>
                        <input
                            type="radio"
                            name="feeSpeed"
                            value={speed}
                            checked={feeSpeed === speed}
                            onChange={() => handleSpeedChange(speed)}
                        />
                        {speed.toUpperCase()} - {fees.time}
                        <br />
                        Max: {ethers.formatUnits(fees.maxFee, "gwei")} gwei
                        | Tip: {ethers.formatUnits(fees.maxPriorityFee, "gwei")} gwei
                    </label>
                </div>
            ))}
        </div>
    );
}
```

---

##

### 1:

```javascript
async function deployContractWithEIP1559() {
    const provider = new ethers.JsonRpcProvider("https://eth-mainnet...");
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

    // 1.  Factory 
    const contractFactory = new ethers.ContractFactory(ABI, BYTECODE, wallet);

    // 2. Fee Data 
    const feeData = await provider.getFeeData();

    // 3. Gas Limit 
    const gasEstimate = await provider.estimateGas({
        data: BYTECODE,
        from: wallet.address
    });

    // 4.  ( )
    const contract = await contractFactory.deploy({
        maxFeePerGas: feeData.maxFeePerGas * 150n / 100n,  // 50% 
        maxPriorityFeePerGas: ethers.parseUnits("3", "gwei"),  //  
        gasLimit: gasEstimate * 120n / 100n
    });

    console.log("Deploying contract to:", contract.target);
    console.log("Transaction hash:", contract.deploymentTransaction().hash);

    // 5.   
    await contract.waitForDeployment();
    console.log("Contract deployed at:", contract.target);

    // 6.   
    const receipt = await contract.deploymentTransaction().wait();
    const totalCost = receipt.gasUsed * receipt.gasPrice;
    console.log(`Deployment cost: ${ethers.formatEther(totalCost)} ETH`);
}
```

### 2:

```javascript
async function sendBatchTransactions(recipients, amounts) {
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const feeData = await provider.getFeeData();

    const transactions = [];

    for (let i = 0; i < recipients.length; i++) {
        //    nonce 
        const nonce = await provider.getTransactionCount(await signer.getAddress()) + i;

        const tx = await signer.sendTransaction({
            to: recipients[i],
            value: ethers.parseEther(amounts[i]),
            nonce: nonce,
            maxFeePerGas: feeData.maxFeePerGas,
            maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
            type: 2
        });

        transactions.push(tx);
        console.log(`Transaction ${i + 1} sent:`, tx.hash);
    }

    //    
    const receipts = await Promise.all(
        transactions.map(tx => tx.wait())
    );

    console.log("All transactions confirmed");
    return receipts;
}
```

### 3:   ( )

```javascript
async function executeWhenGasIsLow(maxBaseFee, action) {
    const provider = new ethers.JsonRpcProvider("https://eth-mainnet...");

    console.log(`Waiting for base fee to drop below ${maxBaseFee} gwei...`);

    return new Promise((resolve, reject) => {
        const interval = setInterval(async () => {
            try {
                const block = await provider.getBlock("latest");
                const currentBaseFee = block.baseFeePerGas;
                const baseFeeGwei = Number(ethers.formatUnits(currentBaseFee, "gwei"));

                console.log(`Current base fee: ${baseFeeGwei.toFixed(2)} gwei`);

                if (currentBaseFee <= ethers.parseUnits(maxBaseFee.toString(), "gwei")) {
                    clearInterval(interval);
                    console.log("Base fee is acceptable, executing action...");
                    const result = await action();
                    resolve(result);
                }
            } catch (err) {
                clearInterval(interval);
                reject(err);
            }
        }, 12000);  // 12 
    });
}

//  
await executeWhenGasIsLow(30, async () => {
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();

    return await signer.sendTransaction({
        to: "0x...",
        value: ethers.parseEther("1.0"),
        type: 2
    });
});
```

### 4:  (Batch Call)

```javascript
// Multicall3   ( )
async function batchCallWithEIP1559(calls) {
    const MULTICALL3_ADDRESS = "0xcA11bde05977b3631167028862bE2a173976CA11";
    const MULTICALL3_ABI = [
        "function aggregate3(tuple(address target, bool allowFailure, bytes callData)[] calls) returns (tuple(bool success, bytes returnData)[] returnData)"
    ];

    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const multicall = new ethers.Contract(MULTICALL3_ADDRESS, MULTICALL3_ABI, signer);

    //     
    const feeData = await provider.getFeeData();

    const tx = await multicall.aggregate3(calls, {
        maxFeePerGas: feeData.maxFeePerGas,
        maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
        type: 2
    });

    const receipt = await tx.wait();
    console.log("Multicall executed with gas:", receipt.gasUsed.toString());

    return receipt;
}
```

---

##

###
- [EIP-1559 Specification](https://eips.ethereum.org/EIPS/eip-1559)
- [Ethereum.org - Gas and Fees](https://ethereum.org/en/developers/docs/gas/)
- [ethers.js Documentation](https://docs.ethers.org/)

###
- [ETH Gas Station](https://ethgasstation.info/)
- [Blocknative Gas Estimator](https://www.blocknative.com/gas-estimator)
- [Etherscan Gas Tracker](https://etherscan.io/gastracker)

### EIP
- [EIP-2930: Optional Access Lists](https://eips.ethereum.org/EIPS/eip-2930)
- [EIP-3529: Reduction in Gas Refunds](https://eips.ethereum.org/EIPS/eip-3529)
- [EIP-4844: Shard Blob Transactions](https://eips.ethereum.org/EIPS/eip-4844)

---

##

  `contracts/`     :

1. **GasAnalyzer.sol** -      
2. **FeeEstimator.sol** -   
3. **BaseFeeOracle.sol** - Base fee  
4. **ConditionalExecutor.sol** -   

      .

---

##

EIP-1559       :

1. **Base Fee + Priority Fee**    
2. **Base Fee ** ETH  
3. **  **   
4. **  UX**   

dApp  EIP-1559         .
