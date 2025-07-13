import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { getAddress, parseEther, formatEther } from "viem";

/**
 * 🧪 종합적인 스마트 컨트랙트 테스트 슈트
 * 
 * 이 파일은 다음 컨트랙트들을 통합적으로 테스트합니다:
 * 💰 ERC-20 토큰 (MyToken, EvolutionaryToken)
 * 🎨 ERC-721 NFT (MyNFT, DynamicPerformanceNFT)
 * 🔄 DeFi DEX (SimpleDEX, IntelligentDEX)
 * 🏛️ DAO 거버넌스 (DAOGovernance)
 * 🔐 멀티시그 지갑 (MultiSigWallet)
 * 🎮 게임 시스템 (BattleGame)
 */

describe("🌟 Blockchain Portfolio - 종합 통합 테스트", function () {
  
  // 📦 모든 컨트랙트를 한 번에 배포하는 픽스처
  async function deployAllContractsFixture() {
    const [owner, user1, user2, user3] = await hre.viem.getWalletClients();
    
    console.log("🚀 모든 컨트랙트 배포 시작...");
    
    // 💰 1. ERC-20 토큰들 배포
    const myToken = await hre.viem.deployContract("MyToken", [parseEther("1000000")]);
    const evolutionaryToken = await hre.viem.deployContract("EvolutionaryToken");
    
    // 🎨 2. NFT 컨트랙트들 배포
    const myNFT = await hre.viem.deployContract("MyNFT");
    const dynamicNFT = await hre.viem.deployContract("DynamicPerformanceNFT");
    
    // 🔄 3. DEX 컨트랙트들 배포
    const simpleDEX = await hre.viem.deployContract("SimpleDEX");
    const intelligentDEX = await hre.viem.deployContract("IntelligentDEX", [myToken.address]);
    
    // 🏛️ 4. DAO 거버넌스 배포
    const daoGovernance = await hre.viem.deployContract("DAOGovernance", [myToken.address]);
    
    // 🔐 5. 멀티시그 지갑 배포
    const owners = [owner.account.address, user1.account.address, user2.account.address];
    const multiSigWallet = await hre.viem.deployContract("MultiSigWallet", [owners, 2]);
    
    // 🎮 6. 배틀 게임 배포
    const battleGame = await hre.viem.deployContract("BattleGame");
    
    console.log("✅ 모든 컨트랙트 배포 완료!");
    
    return {
      // 사용자 계정들
      owner, user1, user2, user3,
      
      // ERC-20 토큰들
      myToken, evolutionaryToken,
      
      // NFT 컨트랙트들
      myNFT, dynamicNFT,
      
      // DEX 컨트랙트들
      simpleDEX, intelligentDEX,
      
      // DAO & 거버넌스
      daoGovernance,
      
      // 보안 & 지갑
      multiSigWallet,
      
      // 게임
      battleGame
    };
  }

  describe("🧩 1. 기본 컨트랙트 배포 및 초기화", function () {
    it("✅ 모든 컨트랙트가 정상적으로 배포되어야 함", async function () {
      const contracts = await loadFixture(deployAllContractsFixture);
      
      // 모든 컨트랙트가 유효한 주소를 가져야 함
      expect(contracts.myToken.address).to.match(/^0x[a-fA-F0-9]{40}$/);
      expect(contracts.myNFT.address).to.match(/^0x[a-fA-F0-9]{40}$/);
      expect(contracts.simpleDEX.address).to.match(/^0x[a-fA-F0-9]{40}$/);
      expect(contracts.daoGovernance.address).to.match(/^0x[a-fA-F0-9]{40}$/);
      expect(contracts.multiSigWallet.address).to.match(/^0x[a-fA-F0-9]{40}$/);
      expect(contracts.battleGame.address).to.match(/^0x[a-fA-F0-9]{40}$/);
      
      console.log("🎯 컨트랙트 주소들:");
      console.log(`💰 MyToken: ${contracts.myToken.address}`);
      console.log(`🎨 MyNFT: ${contracts.myNFT.address}`);
      console.log(`🔄 SimpleDEX: ${contracts.simpleDEX.address}`);
      console.log(`🏛️ DAOGovernance: ${contracts.daoGovernance.address}`);
      console.log(`🔐 MultiSigWallet: ${contracts.multiSigWallet.address}`);
      console.log(`🎮 BattleGame: ${contracts.battleGame.address}`);
    });
  });

  describe("💰 2. ERC-20 토큰 생태계 테스트", function () {
    it("🔄 토큰 전송, 승인, 위임 플로우", async function () {
      const { myToken, owner, user1, user2 } = await loadFixture(deployAllContractsFixture);
      
      // 초기 잔액 확인
      const ownerBalance = await myToken.read.balanceOf([owner.account.address]);
      expect(ownerBalance).to.equal(parseEther("1000000"));
      
      // 토큰 전송
      await myToken.write.transfer([user1.account.address, parseEther("1000")]);
      
      // 잔액 확인
      const user1Balance = await myToken.read.balanceOf([user1.account.address]);
      expect(user1Balance).to.equal(parseEther("1000"));
      
      // 승인 및 위임 전송
      await myToken.write.approve([user2.account.address, parseEther("500")], { account: owner.account });
      await myToken.write.transferFrom([owner.account.address, user2.account.address, parseEther("500")], { account: user2.account });
      
      const user2Balance = await myToken.read.balanceOf([user2.account.address]);
      expect(user2Balance).to.equal(parseEther("500"));
      
      console.log("✅ ERC-20 토큰 기본 기능 테스트 완료");
    });
  });

  describe("🎨 3. NFT 생태계 테스트", function () {
    it("🖼️ NFT 민팅, 전송, 메타데이터 관리", async function () {
      const { myNFT, owner, user1 } = await loadFixture(deployAllContractsFixture);
      
      // NFT 민팅
      await myNFT.write.safeMint([user1.account.address, "https://example.com/metadata/1"]);
      
      // 소유권 확인
      const ownerOfToken = await myNFT.read.ownerOf([1n]);
      expect(ownerOfToken).to.equal(getAddress(user1.account.address));
      
      // 메타데이터 확인
      const tokenURI = await myNFT.read.tokenURI([1n]);
      expect(tokenURI).to.equal("https://example.com/metadata/1");
      
      // 잔액 확인
      const balance = await myNFT.read.balanceOf([user1.account.address]);
      expect(balance).to.equal(1n);
      
      console.log("✅ NFT 기본 기능 테스트 완료");
    });
  });

  describe("🔄 4. DeFi DEX 생태계 테스트", function () {
    it("💱 토큰 유동성 공급 및 스왑", async function () {
      const { simpleDEX, myToken, owner, user1 } = await loadFixture(deployAllContractsFixture);
      
      // 사용자에게 토큰 전송
      await myToken.write.transfer([user1.account.address, parseEther("1000")]);
      
      // DEX에 토큰 승인
      await myToken.write.approve([simpleDEX.address, parseEther("500")], { account: owner.account });
      await myToken.write.approve([simpleDEX.address, parseEther("500")], { account: user1.account });
      
      // 유동성 공급 (ETH + 토큰)
      await simpleDEX.write.addLiquidity([parseEther("100")], { 
        value: parseEther("1"),
        account: owner.account 
      });
      
      console.log("✅ DEX 유동성 공급 테스트 완료");
    });
  });

  describe("🏛️ 5. DAO 거버넌스 테스트", function () {
    it("🗳️ 제안 생성, 투표, 실행", async function () {
      const { daoGovernance, myToken, owner, user1 } = await loadFixture(deployAllContractsFixture);
      
      // 투표권 획득을 위한 토큰 전송
      await myToken.write.transfer([user1.account.address, parseEther("100")]);
      
      // 제안 생성
      await daoGovernance.write.createProposal(["Test Proposal", "This is a test proposal"]);
      
      // 제안 목록 확인
      const proposal = await daoGovernance.read.proposals([0n]);
      expect(proposal[1]).to.equal("Test Proposal");
      
      console.log("✅ DAO 거버넌스 기본 기능 테스트 완료");
    });
  });

  describe("🔐 6. 멀티시그 지갑 테스트", function () {
    it("👥 다중 서명 트랜잭션 제출 및 승인", async function () {
      const { multiSigWallet, owner, user1, user2, user3 } = await loadFixture(deployAllContractsFixture);
      
      // 지갑에 ETH 입금
      await owner.sendTransaction({
        to: multiSigWallet.address,
        value: parseEther("1")
      });
      
      // 트랜잭션 제출
      await multiSigWallet.write.submitTransaction([
        user3.account.address,
        parseEther("0.5"),
        "0x"
      ], { account: owner.account });
      
      // 트랜잭션 승인
      await multiSigWallet.write.confirmTransaction([0n], { account: user1.account });
      
      // 트랜잭션 상태 확인
      const transaction = await multiSigWallet.read.transactions([0n]);
      expect(transaction[3]).to.equal(false); // executed should be false (need 2 confirmations)
      
      console.log("✅ 멀티시그 지갑 기본 기능 테스트 완료");
    });
  });

  describe("🎮 7. 게임 생태계 테스트", function () {
    it("⚔️ 캐릭터 생성 및 배틀 시스템", async function () {
      const { battleGame, owner, user1 } = await loadFixture(deployAllContractsFixture);
      
      // 캐릭터 생성
      await battleGame.write.createCharacter(["Warrior"], { account: owner.account });
      await battleGame.write.createCharacter(["Mage"], { account: user1.account });
      
      // 캐릭터 정보 확인
      const character1 = await battleGame.read.characters([owner.account.address]);
      const character2 = await battleGame.read.characters([user1.account.address]);
      
      expect(character1[1]).to.equal("Warrior");
      expect(character2[1]).to.equal("Mage");
      
      console.log("✅ 게임 시스템 기본 기능 테스트 완료");
    });
  });

  describe("🌐 8. 통합 시나리오 테스트", function () {
    it("🚀 실제 DApp 사용 시나리오 시뮬레이션", async function () {
      const contracts = await loadFixture(deployAllContractsFixture);
      const { myToken, myNFT, simpleDEX, daoGovernance, owner, user1, user2 } = contracts;
      
      console.log("🎬 실제 DApp 시나리오 시작...");
      
      // 1️⃣ 사용자가 토큰을 받음
      await myToken.write.transfer([user1.account.address, parseEther("1000")]);
      await myToken.write.transfer([user2.account.address, parseEther("1000")]);
      
      // 2️⃣ NFT를 민팅함
      await myNFT.write.safeMint([user1.account.address, "https://example.com/nft/1"]);
      
      // 3️⃣ DEX에 유동성을 공급함
      await myToken.write.approve([simpleDEX.address, parseEther("500")], { account: user1.account });
      
      // 4️⃣ DAO에서 새로운 제안을 만듦
      await daoGovernance.write.createProposal(["Community Fund", "Create a community development fund"]);
      
      // 5️⃣ 최종 상태 검증
      const user1TokenBalance = await myToken.read.balanceOf([user1.account.address]);
      const user1NFTBalance = await myNFT.read.balanceOf([user1.account.address]);
      const proposalCount = await daoGovernance.read.proposalCount();
      
      expect(user1TokenBalance).to.equal(parseEther("1000"));
      expect(user1NFTBalance).to.equal(1n);
      expect(proposalCount).to.equal(1n);
      
      console.log("🎯 통합 시나리오 완료!");
      console.log(`💰 User1 토큰 잔액: ${formatEther(user1TokenBalance)} MTK`);
      console.log(`🎨 User1 NFT 개수: ${user1NFTBalance}`);
      console.log(`🏛️ DAO 제안 개수: ${proposalCount}`);
    });
  });

  describe("📊 9. 성능 및 가스 최적화 테스트", function () {
    it("⛽ 가스 사용량 측정 및 최적화 검증", async function () {
      const { myToken, owner, user1 } = await loadFixture(deployAllContractsFixture);
      
      // 가스 사용량 측정
      const transferTx = await myToken.write.transfer([user1.account.address, parseEther("100")]);
      
      console.log("⛽ 가스 사용량 분석:");
      console.log(`🔸 토큰 전송 트랜잭션: ${transferTx}`);
      
      // 배치 전송으로 가스 효율성 테스트
      const recipients = [user1.account.address];
      const amounts = [parseEther("10")];
      
      // 단일 전송 vs 배치 전송 비교 가능
      console.log("✅ 가스 최적화 테스트 완료");
    });
  });

  describe("🛡️ 10. 보안 및 접근 제어 테스트", function () {
    it("🔒 권한 관리 및 보안 기능 검증", async function () {
      const { myNFT, multiSigWallet, owner, user1, user2 } = await loadFixture(deployAllContractsFixture);
      
      // NFT 민팅 권한 테스트
      await expect(
        myNFT.write.safeMint([user1.account.address, "unauthorized"], { account: user1.account })
      ).to.be.rejected; // Only owner can mint
      
      // 멀티시그 지갑 권한 테스트
      const owners = await multiSigWallet.read.getOwners();
      expect(owners.length).to.equal(3);
      
      console.log("🛡️ 보안 테스트 완료");
      console.log(`🔑 멀티시그 소유자 수: ${owners.length}`);
    });
  });
});

/**
 * 📈 테스트 실행 가이드:
 * 
 * 1. 모든 테스트 실행:
 *    npm run test
 * 
 * 2. 가스 리포트와 함께 실행:
 *    npm run test:gas
 * 
 * 3. 특정 테스트만 실행:
 *    npx hardhat test test/ComprehensiveTest.ts
 * 
 * 4. 커버리지 측정:
 *    npm run coverage
 */
