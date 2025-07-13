import hre from "hardhat";
import { formatEther, parseEther } from "viem";

async function main() {
  console.log("🌟 스마트컨트랙트 종합 쇼케이스 시작!");
  console.log("=".repeat(60));
  
  // 계정 준비
  const [deployer, alice, bob, charlie, david] = await hre.viem.getWalletClients();
  const publicClient = await hre.viem.getPublicClient();
  
  console.log("\n👥 참여자 정보:");
  console.log(`배포자: ${deployer.account.address}`);
  console.log(`Alice: ${alice.account.address}`);
  console.log(`Bob: ${bob.account.address}`);
  console.log(`Charlie: ${charlie.account.address}`);
  console.log(`David: ${david.account.address}`);
  
  // 1. ERC-20 토큰 배포 및 테스트
  console.log("\n💰 1. ERC-20 토큰 시스템 테스트");
  console.log("-".repeat(40));
  
  const myToken = await hre.viem.deployContract("MyToken");
  console.log(`토큰 컨트랙트 배포: ${myToken.address}`);
  
  // 에어드랍 테스트
  console.log("Alice와 Bob이 에어드랍 claim...");
  await myToken.write.claimAirdrop({ account: alice.account });
  await myToken.write.claimAirdrop({ account: bob.account });
  
  const aliceBalance = await myToken.read.balanceOf([alice.account.address]);
  const bobBalance = await myToken.read.balanceOf([bob.account.address]);
  
  console.log(`Alice 토큰 잔액: ${formatEther(aliceBalance)} MTK`);
  console.log(`Bob 토큰 잔액: ${formatEther(bobBalance)} MTK`);
  
  // 스테이킹 테스트
  console.log("Alice가 50 MTK 스테이킹...");
  await myToken.write.stake([parseEther("50")], { account: alice.account });
  
  const aliceStaked = await myToken.read.stakedBalance([alice.account.address]);
  console.log(`Alice 스테이킹 금액: ${formatEther(aliceStaked)} MTK`);
  
  // 2. NFT 컨트랙트 테스트
  console.log("\n🎨 2. NFT 컬렉션 테스트");
  console.log("-".repeat(40));
  
  const myNFT = await hre.viem.deployContract("MyNFT");
  console.log(`NFT 컨트랙트 배포: ${myNFT.address}`);
  
  // 화이트리스트 추가
  await myNFT.write.addToWhitelist([[alice.account.address, bob.account.address]], {
    account: deployer.account
  });
  
  // 화이트리스트 민팅
  console.log("Alice가 화이트리스트로 NFT 민팅...");
  await myNFT.write.whitelistMint(["https://example.com/nft/1.json"], {
    value: parseEther("0.03"),
    account: alice.account
  });
  
  // 화이트리스트 종료 후 공개 민팅
  await myNFT.write.setWhitelistActive([false], { account: deployer.account });
  
  console.log("Bob이 공개 민팅...");
  await myNFT.write.publicMint(["https://example.com/nft/2.json"], {
    value: parseEther("0.05"),
    account: bob.account
  });
  
  const aliceNFTs = await myNFT.read.getUserNFTs([alice.account.address]);
  const bobNFTs = await myNFT.read.getUserNFTs([bob.account.address]);
  
  console.log(`Alice NFT 개수: ${aliceNFTs.length}`);
  console.log(`Bob NFT 개수: ${bobNFTs.length}`);
  
  // NFT 레벨업
  console.log("Alice NFT 레벨업...");
  await myNFT.write.levelUpNFT([aliceNFTs[0], 1500n], { account: alice.account });
  
  const aliceNFTInfo = await myNFT.read.getNFTInfo([aliceNFTs[0]]);
  console.log(`Alice NFT #${aliceNFTs[0]} 레벨: ${aliceNFTInfo[2]}`);
  
  // 3. DEX 컨트랙트 테스트
  console.log("\n🔄 3. DEX (토큰 스왑) 테스트");
  console.log("-".repeat(40));
  
  // 두 번째 토큰 생성 (DEX용)
  const tokenB = await hre.viem.deployContract("MyToken");
  
  // DEX 배포
  const dex = await hre.viem.deployContract("SimpleDEX", [myToken.address, tokenB.address]);
  console.log(`DEX 컨트랙트 배포: ${dex.address}`);
  
  // 배포자가 토큰 민팅
  await myToken.write.mint([deployer.account.address, parseEther("10000")], {
    account: deployer.account
  });
  await tokenB.write.mint([deployer.account.address, parseEther("10000")], {
    account: deployer.account
  });
  
  // DEX에 유동성 공급
  console.log("DEX에 유동성 공급...");
  await myToken.write.approve([dex.address, parseEther("1000")], {
    account: deployer.account
  });
  await tokenB.write.approve([dex.address, parseEther("1000")], {
    account: deployer.account
  });
  
  await dex.write.addLiquidity([parseEther("1000"), parseEther("1000")], {
    account: deployer.account
  });
  
  const poolStats = await dex.read.getPoolStats();
  console.log(`유동성 풀 - TokenA: ${formatEther(poolStats[0])}, TokenB: ${formatEther(poolStats[1])}`);
  
  // 스왑 테스트
  console.log("Alice가 토큰 스왑 진행...");
  await myToken.write.transfer([alice.account.address, parseEther("100")], {
    account: deployer.account
  });
  await myToken.write.approve([dex.address, parseEther("10")], {
    account: alice.account
  });
  
  await dex.write.swapAtoB([parseEther("10")], { account: alice.account });
  
  const aliceTokenBBalance = await tokenB.read.balanceOf([alice.account.address]);
  console.log(`스왑 후 Alice TokenB 잔액: ${formatEther(aliceTokenBBalance)}`);
  
  // 4. 게임 컨트랙트 테스트
  console.log("\n🎮 4. RPG 배틀 게임 테스트");
  console.log("-".repeat(40));
  
  const battleGame = await hre.viem.deployContract("BattleGame", [myToken.address]);
  console.log(`게임 컨트랙트 배포: ${battleGame.address}`);
  
  // 게임에 토큰 제공 (보상용)
  await myToken.write.transfer([battleGame.address, parseEther("10000")], {
    account: deployer.account
  });
  
  // 캐릭터 민팅
  console.log("Alice와 Bob이 캐릭터 생성...");
  await battleGame.write.mintCharacter(["Alice Warrior", 0n], {
    value: parseEther("0.1"),
    account: alice.account
  });
  
  await battleGame.write.mintCharacter(["Bob Mage", 1n], {
    value: parseEther("0.1"),
    account: bob.account
  });
  
  const aliceCharacters = await battleGame.read.getUserCharacters([alice.account.address]);
  const bobCharacters = await battleGame.read.getUserCharacters([bob.account.address]);
  
  console.log(`Alice 캐릭터 ID: ${aliceCharacters[0]}`);
  console.log(`Bob 캐릭터 ID: ${bobCharacters[0]}`);
  
  // 배틀 진행
  console.log("Alice vs Bob 배틀 시작!");
  await battleGame.write.startBattle([aliceCharacters[0], bobCharacters[0]], {
    account: alice.account
  });
  
  const aliceCharInfo = await battleGame.read.getCharacterInfo([aliceCharacters[0]]);
  const bobCharInfo = await battleGame.read.getCharacterInfo([bobCharacters[0]]);
  
  console.log(`배틀 후 Alice 캐릭터 - 승: ${aliceCharInfo[8]}, 패: ${aliceCharInfo[9]}`);
  console.log(`배틀 후 Bob 캐릭터 - 승: ${bobCharInfo[8]}, 패: ${bobCharInfo[9]}`);
  
  // 5. 멀티시그 지갑 테스트
  console.log("\n🔐 5. 멀티시그 지갑 테스트");
  console.log("-".repeat(40));
  
  const owners = [deployer.account.address, alice.account.address, bob.account.address];
  const requiredSignatures = 2;
  
  const multiSig = await hre.viem.deployContract("MultiSigWallet", [owners, requiredSignatures]);
  console.log(`멀티시그 지갑 배포: ${multiSig.address}`);
  
  // 지갑에 ETH 입금
  await deployer.sendTransaction({
    to: multiSig.address,
    value: parseEther("1.0")
  });
  
  const walletInfo = await multiSig.read.getWalletInfo();
  console.log(`멀티시그 잔액: ${formatEther(walletInfo[3])} ETH`);
  console.log(`필요 서명 수: ${walletInfo[1]}/${walletInfo[0].length}`);
  
  // 트랜잭션 제출
  console.log("Charlie에게 0.1 ETH 전송 제안...");
  await multiSig.write.submitTransaction([
    charlie.account.address,
    parseEther("0.1"),
    "0x"
  ], { account: deployer.account });
  
  // Alice가 승인
  await multiSig.write.confirmTransaction([0n], { account: alice.account });
  
  const txInfo = await multiSig.read.getTransaction([0n]);
  console.log(`트랜잭션 상태 - 실행됨: ${txInfo[3]}, 승인 수: ${txInfo[4]}`);
  
  // 6. DAO 거버넌스 테스트
  console.log("\n🏛️ 6. DAO 거버넌스 테스트");
  console.log("-".repeat(40));
  
  const dao = await hre.viem.deployContract("DAOGovernance", [myToken.address]);
  console.log(`DAO 컨트랙트 배포: ${dao.address}`);
  
  // Alice와 Bob이 토큰 스테이킹 (투표권 획득)
  await myToken.write.approve([dao.address, parseEther("200")], {
    account: alice.account
  });
  await dao.write.stakeTokens([parseEther("50")], { account: alice.account });
  
  const aliceVotingPower = await dao.read.getVotingPower([alice.account.address]);
  console.log(`Alice 투표권: ${formatEther(aliceVotingPower)} votes`);
  
  // 제안서 생성 (투표권이 충분한 배포자가)
  await myToken.write.approve([dao.address, parseEther("500")], {
    account: deployer.account
  });
  await dao.write.stakeTokens([parseEther("500")], { account: deployer.account });
  
  await dao.write.propose([
    "토큰 발행량 증가 제안",
    "게임 보상을 위해 추가 토큰 발행",
    "0x0000000000000000000000000000000000000000",
    "0x"
  ], { account: deployer.account });
  
  console.log("제안서 생성 완료!");
  
  const proposalDetails = await dao.read.getProposalDetails([0n]);
  console.log(`제안서 제목: ${proposalDetails[0]}`);
  
  // 7. 전체 시스템 통계
  console.log("\n📊 전체 시스템 통계");
  console.log("-".repeat(40));
  
  const totalTokenSupply = await myToken.read.totalSupply();
  const nftTotalSupply = Number(await myNFT.read.balanceOf([alice.account.address])) + 
                          Number(await myNFT.read.balanceOf([bob.account.address]));
  
  console.log(`총 토큰 공급량: ${formatEther(totalTokenSupply)} MTK`);
  console.log(`총 NFT 발행량: ${nftTotalSupply} NFTs`);
  console.log(`DEX 총 유동성: ${formatEther(poolStats[0] + poolStats[1])} 토큰`);
  console.log(`게임 캐릭터 수: ${aliceCharacters.length + bobCharacters.length}`);
  console.log(`멀티시그 지갑 잔액: ${formatEther(walletInfo[3])} ETH`);
  
  console.log("\n🎉 모든 컨트랙트 테스트 완료!");
  console.log("=".repeat(60));
  
  // 컨트랙트 주소 정리
  console.log("\n📝 배포된 컨트랙트 주소:");
  console.log(`- MyToken (ERC-20): ${myToken.address}`);
  console.log(`- MyNFT (ERC-721): ${myNFT.address}`);
  console.log(`- SimpleDEX: ${dex.address}`);
  console.log(`- BattleGame: ${battleGame.address}`);
  console.log(`- MultiSigWallet: ${multiSig.address}`);
  console.log(`- DAOGovernance: ${dao.address}`);
  
  console.log("\n🚀 이제 콘솔에서 이 주소들로 더 자세한 테스트를 해보세요!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
