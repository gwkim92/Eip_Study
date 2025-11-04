// EIP-712 테스트 예제 (Hardhat 기반)
// 설치: npm install --save-dev @nomicfoundation/hardhat-toolbox

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EIP712Example", function () {
  let eip712Example;
  let owner, spender;

  // EIP-712 Domain
  let domain;

  // EIP-712 Types
  const types = {
    Permit: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
      { name: "value", type: "uint256" },
      { name: "nonce", type: "uint256" },
      { name: "deadline", type: "uint256" },
    ],
  };

  beforeEach(async function () {
    [owner, spender] = await ethers.getSigners();

    // 컨트랙트 배포
    const EIP712Example = await ethers.getContractFactory("EIP712Example");
    eip712Example = await EIP712Example.deploy();
    await eip712Example.waitForDeployment();

    // Domain 설정
    domain = {
      name: await eip712Example.name(),
      version: await eip712Example.version(),
      chainId: (await ethers.provider.getNetwork()).chainId,
      verifyingContract: await eip712Example.getAddress(),
    };
  });

  describe("Domain Separator", function () {
    it("올바른 domain separator를 생성해야 함", async function () {
      const domainSeparator = await eip712Example.DOMAIN_SEPARATOR();
      expect(domainSeparator).to.not.equal(ethers.ZeroHash);
    });

    it("name과 version이 올바르게 설정되어야 함", async function () {
      expect(await eip712Example.name()).to.equal("EIP712Example");
      expect(await eip712Example.version()).to.equal("1");
    });
  });

  describe("Permit 서명 검증", function () {
    it("유효한 서명을 검증할 수 있어야 함", async function () {
      const value = ethers.parseEther("100");
      const nonce = await eip712Example.nonces(owner.address);
      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1시간 후

      // 메시지 생성
      const message = {
        owner: owner.address,
        spender: spender.address,
        value: value,
        nonce: nonce,
        deadline: deadline,
      };

      // 서명 생성
      const signature = await owner.signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);

      // 서명 검증
      const isValid = await eip712Example.verify(
        owner.address,
        spender.address,
        value,
        deadline,
        v,
        r,
        s
      );

      expect(isValid).to.be.true;
    });

    it("permit 함수가 정상 동작해야 함", async function () {
      const value = ethers.parseEther("100");
      const nonce = await eip712Example.nonces(owner.address);
      const deadline = Math.floor(Date.now() / 1000) + 3600;

      const message = {
        owner: owner.address,
        spender: spender.address,
        value: value,
        nonce: nonce,
        deadline: deadline,
      };

      const signature = await owner.signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);

      // Permit 실행
      await expect(
        eip712Example.permit(
          owner.address,
          spender.address,
          value,
          deadline,
          v,
          r,
          s
        )
      )
        .to.emit(eip712Example, "Approval")
        .withArgs(owner.address, spender.address, value);

      // Allowance 확인
      const allowance = await eip712Example.allowances(
        owner.address,
        spender.address
      );
      expect(allowance).to.equal(value);

      // Nonce 증가 확인
      const newNonce = await eip712Example.nonces(owner.address);
      expect(newNonce).to.equal(nonce + 1n);
    });

    it("잘못된 서명은 거부해야 함", async function () {
      const value = ethers.parseEther("100");
      const nonce = await eip712Example.nonces(owner.address);
      const deadline = Math.floor(Date.now() / 1000) + 3600;

      const message = {
        owner: owner.address,
        spender: spender.address,
        value: value,
        nonce: nonce,
        deadline: deadline,
      };

      // 다른 사람이 서명
      const signature = await spender.signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);

      // Permit 실행 (실패해야 함)
      await expect(
        eip712Example.permit(
          owner.address,
          spender.address,
          value,
          deadline,
          v,
          r,
          s
        )
      ).to.be.revertedWith("EIP712: unauthorized");
    });

    it("만료된 deadline은 거부해야 함", async function () {
      const value = ethers.parseEther("100");
      const nonce = await eip712Example.nonces(owner.address);
      const deadline = Math.floor(Date.now() / 1000) - 3600; // 1시간 전 (만료)

      const message = {
        owner: owner.address,
        spender: spender.address,
        value: value,
        nonce: nonce,
        deadline: deadline,
      };

      const signature = await owner.signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        eip712Example.permit(
          owner.address,
          spender.address,
          value,
          deadline,
          v,
          r,
          s
        )
      ).to.be.revertedWith("EIP712: expired deadline");
    });

    it("재사용된 nonce는 거부해야 함", async function () {
      const value = ethers.parseEther("100");
      const nonce = await eip712Example.nonces(owner.address);
      const deadline = Math.floor(Date.now() / 1000) + 3600;

      const message = {
        owner: owner.address,
        spender: spender.address,
        value: value,
        nonce: nonce,
        deadline: deadline,
      };

      const signature = await owner.signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);

      // 첫 번째 permit (성공)
      await eip712Example.permit(
        owner.address,
        spender.address,
        value,
        deadline,
        v,
        r,
        s
      );

      // 같은 서명으로 두 번째 permit (실패해야 함)
      await expect(
        eip712Example.permit(
          owner.address,
          spender.address,
          value,
          deadline,
          v,
          r,
          s
        )
      ).to.be.revertedWith("EIP712: unauthorized");
    });
  });

  describe("일반 approve 함수", function () {
    it("approve가 정상 동작해야 함", async function () {
      const value = ethers.parseEther("100");

      await expect(eip712Example.connect(owner).approve(spender.address, value))
        .to.emit(eip712Example, "Approval")
        .withArgs(owner.address, spender.address, value);

      const allowance = await eip712Example.allowances(
        owner.address,
        spender.address
      );
      expect(allowance).to.equal(value);
    });
  });
});
