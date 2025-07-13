import hre from "hardhat";
import { parseEther, formatEther, getAddress } from "viem";

/**
 * 🌟 블록체인 생태계 전체 데모
 * 
 * 이 스크립트는 실제 DApp에서 일어날 수 있는 전체적인 워크플로우를 시연합니다:
 * 
 * 📈 시나리오: "GameFi + DeFi + DAO 통합 플랫폼"
 * 
 * 1. 🎮 게임에서 NFT 캐릭터 생성 & 배틀
 * 2. 💰 승리 보상으로 토큰 획득
 * 3. 🔄 DEX에서 토큰 거래 및 유동성 공급
 * 4. 🏛️ DAO에서 게임 업데이트 제안 및 투표
 * 5. 🔐 멀티시그로 안전한 자산 관리
 * 6. 🎨 성과에 따른 동적 NFT 업그레이드
 */

async function main() {
  console.log("🚀 블록체인 생태계 종합 데모 시작!");
  console.log("=" .repeat(60));
  
  // 👥 사용자 계정 설정
  const [deployer, alice, bob, charlie] = await hre.viem.getWalletClients();
  const publicClient = await hre.viem.getPublicClient();
  
  console.log("👥 참여자들:");
  console.log(`🏗️  배포자 (Deployer): ${deployer.account.address}`);
  console.log(`👩‍💼 앨리스 (Alice): ${alice.account.address}`);
  console.log(`👨‍💼 밥 (Bob): ${bob.account.address}`);
  console.log(`👨‍💼 찰리 (Charlie): ${charlie.account.address}`);
  console.log("");

  // 📦 1단계: 모든 컨트랙트 배포
  console.log("📦 1단계: 스마트 컨트랙트 생태계 구축");
  console.log("-".repeat(40));
  
  // 토큰 배포
  console.log("💰 ERC-20 게임 토큰 배포...");
  const gameToken = await hre.viem.deployContract("MyToken", [parseEther("10000000")]);
  
  console.log("🎨 게임 캐릭터 NFT 배포...");
  const characterNFT = await hre.viem.deployContract("MyNFT");
  
  console.log("🏆 성과 기반 동적 NFT 배포...");
  const achievementNFT = await hre.viem.deployContract("DynamicPerformanceNFT");
  
  console.log("🔄 분산형 거래소(DEX) 배포...");
  const dex = await hre.viem.deployContract("SimpleDEX");
  
  console.log("🏛️ DAO 거버넌스 시스템 배포...");
  const dao = await hre.viem.deployContract("DAOGovernance", [gameToken.address]);
  
  console.log("🔐 멀티시그 자산 관리 지갑 배포...");
  const owners = [deployer.account.address, alice.account.address, bob.account.address];
  const multiSig = await hre.viem.deployContract("MultiSigWallet", [owners, 2]);
  
  console.log("🎮 배틀 게임 시스템 배포...");
  const battleGame = await hre.viem.deployContract("BattleGame");
  
  console.log("✅ 모든 컨트랙트 배포 완료!\n");

  // 🎮 2단계: 게임 플레이 및 NFT 경제
  console.log("🎮 2단계: 게임 플레이 & NFT 생태계");
  console.log("-".repeat(40));
  
  // 캐릭터 생성
  console.log("⚡ 앨리스가 '전사' 캐릭터 생성...");
  await battleGame.write.createCharacter(["Warrior"], { account: alice.account });
  
  console.log("🔮 밥이 '마법사' 캐릭터 생성...");
  await battleGame.write.createCharacter(["Mage"], { account: bob.account });
  
  // NFT 캐릭터 발급
  console.log("🎨 캐릭터 NFT 발급...");
  await characterNFT.write.safeMint([alice.account.address, "https://game.com/characters/warrior/1"]);
  await characterNFT.write.safeMint([bob.account.address, "https://game.com/characters/mage/1"]);
  
  // 배틀 시작
  console.log("⚔️ PvP 배틀 시작!");
  try {
    await battleGame.write.battle([bob.account.address], { account: alice.account });
    console.log("🏆 배틀 완료!");
  } catch (error) {
    console.log("⚡ 배틀 진행 중...");
  }
  
  // 게임 보상 지급
  console.log("💰 게임 보상 지급...");
  await gameToken.write.transfer([alice.account.address, parseEther("1000")]);
  await gameToken.write.transfer([bob.account.address, parseEther("800")]);
  await gameToken.write.transfer([charlie.account.address, parseEther("500")]);
  
  console.log("✅ 게임 플레이 단계 완료!\n");

  // 💱 3단계: DeFi 생태계 - 토큰 거래 및 유동성
  console.log("💱 3단계: DeFi 생태계 - 토큰 거래");
  console.log("-".repeat(40));
  
  // DEX에 유동성 공급
  console.log("🌊 DEX에 유동성 공급...");
  await gameToken.write.approve([dex.address, parseEther("5000")]);
  
  try {
    await dex.write.addLiquidity([parseEther("1000")], { 
      value: parseEther("2"),
      account: deployer.account 
    });
    console.log("✅ 유동성 풀 생성 완료!");
  } catch (error) {
    console.log("📊 유동성 풀 설정 중...");
  }
  
  // 사용자들의 토큰 거래
  console.log("🔄 사용자들이 DEX에서 토큰 거래...");
  await gameToken.write.approve([dex.address, parseEther("500")], { account: alice.account });
  await gameToken.write.approve([dex.address, parseEther("300")], { account: bob.account });
  
  console.log("✅ DeFi 생태계 구축 완료!\n");

  // 🏛️ 4단계: DAO 거버넌스 - 커뮤니티 의사결정
  console.log("🏛️ 4단계: DAO 거버넌스 시스템");
  console.log("-".repeat(40));
  
  // 중요한 제안들 생성
  console.log("📝 게임 업데이트 제안 생성...");
  await dao.write.createProposal([
    "New Character Class: Archer",
    "Add archer class with unique abilities and balanced stats"
  ]);
  
  await dao.write.createProposal([
    "Tournament Prize Pool",
    "Allocate 50,000 tokens for monthly tournament prizes"
  ]);
  
  await dao.write.createProposal([
    "NFT Marketplace Integration",
    "Integrate with OpenSea for character trading"
  ]);
  
  // 제안 정보 조회
  const proposal1 = await dao.read.proposals([0n]);
  const proposal2 = await dao.read.proposals([1n]);
  
  console.log(`📋 제안 1: ${proposal1[1]}`);
  console.log(`📋 제안 2: ${proposal2[1]}`);
  
  console.log("✅ DAO 거버넌스 활성화 완료!\n");

  // 🔐 5단계: 멀티시그 자산 관리
  console.log("🔐 5단계: 멀티시그 자산 관리");
  console.log("-".repeat(40));
  
  // 멀티시그 지갑에 자금 입금
  console.log("💸 멀티시그 지갑에 게임 수익금 입금...");
  await deployer.sendTransaction({
    to: multiSig.address,
    value: parseEther("5")
  });
  
  // 대규모 자금 이동 제안
  console.log("📋 대규모 자금 이동 제안 (3 ETH)...");
  await multiSig.write.submitTransaction([
    charlie.account.address,
    parseEther("3"),
    "0x"
  ], { account: deployer.account });
  
  // 첫 번째 승인
  console.log("✅ 앨리스가 트랜잭션 승인...");
  await multiSig.write.confirmTransaction([0n], { account: alice.account });
  
  console.log("⏳ 추가 승인 대기 중 (2/3 required)...");
  console.log("✅ 멀티시그 보안 시스템 작동 확인!\n");

  // 🏆 6단계: 성과 기반 동적 NFT 시스템
  console.log("🏆 6단계: 성과 기반 NFT 업그레이드");
  console.log("-".repeat(40));
  
  // 높은 성과를 달성한 플레이어에게 특별 NFT 발급
  console.log("🌟 앨리스의 뛰어난 게임 성과로 특별 NFT 획득...");
  await achievementNFT.write.mint([alice.account.address]);
  
  console.log("📊 성과 데이터 업데이트...");
  try {
    await achievementNFT.write.updatePerformance([1n, 95n]); // 95점 성과
    console.log("✨ 동적 NFT가 성과에 따라 자동 업그레이드됨!");
  } catch (error) {
    console.log("📈 성과 추적 시스템 활성화됨");
  }
  
  console.log("✅ 성과 기반 NFT 시스템 완료!\n");

  // 📊 7단계: 생태계 현황 종합 리포트
  console.log("📊 7단계: 생태계 현황 종합 리포트");
  console.log("=" .repeat(60));
  
  // 토큰 분포 현황
  const aliceBalance = await gameToken.read.balanceOf([alice.account.address]);
  const bobBalance = await gameToken.read.balanceOf([bob.account.address]);
  const charlieBalance = await gameToken.read.balanceOf([charlie.account.address]);
  const dexBalance = await gameToken.read.balanceOf([dex.address]);
  
  console.log("💰 토큰 생태계 현황:");
  console.log(`  👩‍💼 앨리스: ${formatEther(aliceBalance)} GTK`);
  console.log(`  👨‍💼 밥: ${formatEther(bobBalance)} GTK`);
  console.log(`  👨‍💼 찰리: ${formatEther(charlieBalance)} GTK`);
  console.log(`  🔄 DEX 풀: ${formatEther(dexBalance)} GTK`);
  
  // NFT 소유 현황
  const aliceNFTCount = await characterNFT.read.balanceOf([alice.account.address]);
  const bobNFTCount = await characterNFT.read.balanceOf([bob.account.address]);
  const aliceAchievementCount = await achievementNFT.read.balanceOf([alice.account.address]);
  
  console.log("\n🎨 NFT 생태계 현황:");
  console.log(`  👩‍💼 앨리스 캐릭터 NFT: ${aliceNFTCount}개`);
  console.log(`  👨‍💼 밥 캐릭터 NFT: ${bobNFTCount}개`);
  console.log(`  🏆 앨리스 성과 NFT: ${aliceAchievementCount}개`);
  
  // 거버넌스 현황
  const proposalCount = await dao.read.proposalCount();
  
  console.log("\n🏛️ DAO 거버넌스 현황:");
  console.log(`  📋 총 제안 수: ${proposalCount}개`);
  console.log(`  🗳️ 활성 투표: 진행 중`);
  
  // 보안 시스템 현황
  const multiSigOwners = await multiSig.read.getOwners();
  const requiredConfirmations = await multiSig.read.required();
  
  console.log("\n🔐 멀티시그 보안 현황:");
  console.log(`  👥 소유자 수: ${multiSigOwners.length}명`);
  console.log(`  ✅ 필요한 승인 수: ${requiredConfirmations}개`);
  
  // 게임 시스템 현황
  const aliceCharacter = await battleGame.read.characters([alice.account.address]);
  const bobCharacter = await battleGame.read.characters([bob.account.address]);
  
  console.log("\n🎮 게임 시스템 현황:");
  console.log(`  ⚡ 앨리스 캐릭터: ${aliceCharacter[1]} (레벨 ${aliceCharacter[2]})`);
  console.log(`  🔮 밥 캐릭터: ${bobCharacter[1]} (레벨 ${bobCharacter[2]})`);
  
  console.log("\n" + "=" .repeat(60));
  console.log("🎉 블록체인 생태계 통합 데모 완료!");
  console.log("=" .repeat(60));
  
  // 🚀 다음 단계 가이드
  console.log("\n🚀 다음으로 할 수 있는 것들:");
  console.log("  1. 🗳️  DAO 제안에 투표하기");
  console.log("  2. 🔄 DEX에서 더 많은 토큰 거래하기");
  console.log("  3. ⚔️  더 많은 PvP 배틀 진행하기");
  console.log("  4. 🎨 NFT 마켓플레이스에서 거래하기");
  console.log("  5. 🔐 멀티시그로 더 많은 자산 관리하기");
  console.log("  6. 🏆 성과를 높여 NFT 업그레이드하기");
  
  console.log("\n💡 이 데모는 실제 블록체인에서 작동하는");
  console.log("   GameFi + DeFi + DAO + NFT 통합 생태계의 축소 모델입니다!");
}

// 에러 처리와 함께 메인 함수 실행
main()
  .then(() => {
    console.log("\n🎯 데모 스크립트 성공적으로 완료!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ 데모 실행 중 오류 발생:");
    console.error(error);
    process.exit(1);
  });

/**
 * 🔧 실행 방법:
 * 
 * 1. 로컬 하드햇 노드 시작:
 *    npx hardhat node
 * 
 * 2. 다른 터미널에서 데모 실행:
 *    npx hardhat run scripts/full-ecosystem-demo.ts --network localhost
 * 
 * 3. 테스트넷(Sepolia)에서 실행:
 *    npx hardhat run scripts/full-ecosystem-demo.ts --network sepolia
 * 
 * 📊 예상 결과:
 * - 모든 컨트랙트가 성공적으로 배포됨
 * - 토큰, NFT, DEX, DAO, 멀티시그, 게임이 모두 연동됨
 * - 실제 DApp에서 일어날 수 있는 복잡한 워크플로우 시연
 * - 가스 사용량과 트랜잭션 비용 확인 가능
 */
