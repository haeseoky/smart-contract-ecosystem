import hre from "hardhat";
import { parseEther, formatEther } from "viem";

async function main() {
  console.log("🚀 스마트컨트랙트 실전 데모 시작!");
  
  // 계정 준비
  const [deployer, alice, bob] = await hre.viem.getWalletClients();
  const publicClient = await hre.viem.getPublicClient();
  
  console.log("\n👥 참여자 정보:");
  console.log(`Deployer: ${deployer.account.address}`);
  console.log(`Alice: ${alice.account.address}`);
  console.log(`Bob: ${bob.account.address}`);
  
  // AdvancedLock 배포
  console.log("\n📦 AdvancedLock 컨트랙트 배포 중...");
  const advancedLock = await hre.viem.deployContract("AdvancedLock");
  console.log(`컨트랙트 주소: ${advancedLock.address}`);
  
  // Alice가 1 ETH로 6개월 잠금 생성
  console.log("\n💰 Alice: 1 ETH를 6개월간 잠금...");
  const sixMonths = 6 * 30 * 24 * 60 * 60; // 6개월 (초)
  
  await advancedLock.write.createLock([alice.account.address, sixMonths], {
    value: parseEther("1.0"),
    account: alice.account
  });
  
  // Bob이 2 ETH로 1년 잠금 생성
  console.log("💰 Bob: 2 ETH를 1년간 잠금...");
  const oneYear = 365 * 24 * 60 * 60; // 1년 (초)
  
  await advancedLock.write.createLock([bob.account.address, oneYear], {
    value: parseEther("2.0"),
    account: bob.account
  });
  
  // 현재 상태 확인
  console.log("\n📊 현재 컨트랙트 상태:");
  
  const totalLocked = await advancedLock.read.totalLocked();
  console.log(`총 잠긴 금액: ${formatEther(totalLocked)} ETH`);
  
  const aliceLocks = await advancedLock.read.getUserLocks([alice.account.address]);
  const bobLocks = await advancedLock.read.getUserLocks([bob.account.address]);
  
  console.log(`Alice의 잠금 개수: ${aliceLocks.length}`);
  console.log(`Bob의 잠금 개수: ${bobLocks.length}`);
  
  // Alice의 잠금 상세 정보
  if (aliceLocks.length > 0) {
    const aliceLock = await advancedLock.read.locks([aliceLocks[0]]);
    console.log(`Alice 잠금 #${aliceLocks[0]}:`);
    console.log(`  - 금액: ${formatEther(aliceLock[0])} ETH`);
    console.log(`  - 해제시간: ${new Date(Number(aliceLock[1]) * 1000).toLocaleString()}`);
    console.log(`  - 인출여부: ${aliceLock[2] ? '완료' : '대기중'}`);
  }
  
  // Bob의 잠금 상세 정보
  if (bobLocks.length > 0) {
    const bobLock = await advancedLock.read.locks([bobLocks[0]]);
    console.log(`Bob 잠금 #${bobLocks[0]}:`);
    console.log(`  - 금액: ${formatEther(bobLock[0])} ETH`);
    console.log(`  - 해제시간: ${new Date(Number(bobLock[1]) * 1000).toLocaleString()}`);
    console.log(`  - 인출여부: ${bobLock[2] ? '완료' : '대기중'}`);
  }
  
  console.log("\n✅ 데모 완료! 실제 블록체인에서는 시간이 지나야 인출 가능합니다.");
  console.log("🔧 테스트에서는 time.increase()로 시간을 빨리감기 할 수 있어요!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
