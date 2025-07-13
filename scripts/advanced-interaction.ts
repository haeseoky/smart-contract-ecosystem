import hre from "hardhat";
import { formatEther, parseEther } from "viem";

async function main() {
  console.log("🚀 AdvancedLock 고급 상호작용 데모");
  
  // 계정 준비
  const [deployer, alice, bob, charlie] = await hre.viem.getWalletClients();
  const publicClient = await hre.viem.getPublicClient();
  
  console.log("\n👥 참여자:");
  console.log(`배포자: ${deployer.account.address}`);
  console.log(`Alice: ${alice.account.address}`);
  console.log(`Bob: ${bob.account.address}`);
  console.log(`Charlie: ${charlie.account.address}`);
  
  // AdvancedLock 배포
  console.log("\n📦 AdvancedLock 배포...");
  const advancedLock = await hre.viem.deployContract("AdvancedLock");
  console.log(`컨트랙트 주소: ${advancedLock.address}`);
  
  // 시나리오 1: Alice가 3개월 잠금 생성
  console.log("\n🔒 시나리오 1: Alice의 3개월 잠금");
  const threeMonths = 3 * 30 * 24 * 60 * 60; // 3개월
  
  const aliceTxHash = await advancedLock.write.createLock(
    [alice.account.address, threeMonths],
    {
      value: parseEther("2.5"),
      account: alice.account
    }
  );
  
  console.log(`✅ Alice 잠금 생성: ${aliceTxHash}`);
  
  // 시나리오 2: Bob이 6개월 잠금 생성
  console.log("\n🔒 시나리오 2: Bob의 6개월 잠금");
  const sixMonths = 6 * 30 * 24 * 60 * 60; // 6개월
  
  const bobTxHash = await advancedLock.write.createLock(
    [bob.account.address, sixMonths],
    {
      value: parseEther("1.8"),
      account: bob.account
    }
  );
  
  console.log(`✅ Bob 잠금 생성: ${bobTxHash}`);
  
  // 시나리오 3: Charlie가 자신에게 1년 잠금 (선물)
  console.log("\n🎁 시나리오 3: Charlie의 자기 자신에게 선물");
  const oneYear = 365 * 24 * 60 * 60; // 1년
  
  const charlieTxHash = await advancedLock.write.createLock(
    [charlie.account.address, oneYear],
    {
      value: parseEther("0.5"),
      account: charlie.account
    }
  );
  
  console.log(`✅ Charlie 잠금 생성: ${charlieTxHash}`);
  
  // 현재 상태 조회
  console.log("\n📊 현재 상태:");
  
  const totalLocked = await advancedLock.read.totalLocked();
  console.log(`총 잠긴 금액: ${formatEther(totalLocked)} ETH`);
  
  // 각자의 잠금 정보 확인
  for (const [name, user] of [["Alice", alice], ["Bob", bob], ["Charlie", charlie]]) {
    const userLocks = await advancedLock.read.getUserLocks([user.account.address]);
    const userTotal = await advancedLock.read.getUserTotalLocked([user.account.address]);
    
    console.log(`\n${name}:`);
    console.log(`- 잠금 개수: ${userLocks.length}`);
    console.log(`- 총 잠긴 금액: ${formatEther(userTotal)} ETH`);
    
    // 각 잠금의 상세 정보
    for (let i = 0; i < userLocks.length; i++) {
      const lockInfo = await advancedLock.read.locks([userLocks[i]]);
      const unlockDate = new Date(Number(lockInfo[1]) * 1000);
      
      console.log(`  잠금 #${userLocks[i]}:`);
      console.log(`    - 금액: ${formatEther(lockInfo[0])} ETH`);
      console.log(`    - 해제일: ${unlockDate.toLocaleDateString()}`);
      console.log(`    - 상태: ${lockInfo[2] ? '인출완료' : '잠금중'}`);
    }
  }
  
  // 시나리오 4: 시간을 3개월 후로 이동 (Alice만 인출 가능)
  console.log("\n⏰ 시나리오 4: 3개월 후로 시간 이동");
  
  const currentBlock = await publicClient.getBlock();
  const newTime = Number(currentBlock.timestamp) + threeMonths;
  
  await hre.network.provider.send("evm_mine", [newTime]);
  
  const afterBlock = await publicClient.getBlock();
  console.log(`시간 이동 완료: ${new Date(Number(afterBlock.timestamp) * 1000).toLocaleDateString()}`);
  
  // Alice 인출 시도
  console.log("\n💸 Alice 인출 시도:");
  try {
    const aliceWithdrawTx = await advancedLock.write.withdraw([0n], {
      account: alice.account
    });
    
    console.log(`✅ Alice 인출 성공: ${aliceWithdrawTx}`);
    
    // 인출 후 상태 확인
    const newTotalLocked = await advancedLock.read.totalLocked();
    console.log(`인출 후 총 잠긴 금액: ${formatEther(newTotalLocked)} ETH`);
    
  } catch (error: any) {
    console.log(`❌ Alice 인출 실패: ${error.shortMessage}`);
  }
  
  // Bob 인출 시도 (아직 시간이 안됨)
  console.log("\n💸 Bob 인출 시도 (실패 예상):");
  try {
    await advancedLock.write.withdraw([1n], {
      account: bob.account
    });
    console.log("✅ Bob 인출 성공");
  } catch (error: any) {
    console.log(`❌ Bob 인출 실패 (예상됨): ${error.shortMessage}`);
  }
  
  // 시나리오 5: 관리자 권한 테스트
  console.log("\n🔧 시나리오 5: 관리자 기능 테스트");
  
  // 컨트랙트 일시정지
  console.log("컨트랙트 일시정지...");
  await advancedLock.write.pause({ account: deployer.account });
  
  // 일시정지 상태에서 새 잠금 생성 시도 (실패해야 함)
  try {
    await advancedLock.write.createLock([alice.account.address, 3600], {
      value: parseEther("1.0"),
      account: alice.account
    });
    console.log("❌ 일시정지 중인데 잠금 생성 성공 (버그!)");
  } catch (error) {
    console.log("✅ 일시정지 중 잠금 생성 차단됨");
  }
  
  // 일시정지 해제
  console.log("컨트랙트 일시정지 해제...");
  await advancedLock.write.unpause({ account: deployer.account });
  
  // 이제 정상 작동해야 함
  try {
    const newLockTx = await advancedLock.write.createLock([alice.account.address, 3600], {
      value: parseEther("0.1"),
      account: alice.account
    });
    console.log(`✅ 일시정지 해제 후 잠금 생성 성공: ${newLockTx}`);
  } catch (error) {
    console.log("❌ 일시정지 해제 후에도 실패");
  }
  
  // 이벤트 조회
  console.log("\n📡 모든 이벤트 조회:");
  
  try {
    const lockCreatedEvents = await advancedLock.getEvents.LockCreated();
    console.log(`\n🔒 LockCreated 이벤트: ${lockCreatedEvents.length}개`);
    
    lockCreatedEvents.forEach((event, index) => {
      console.log(`이벤트 ${index + 1}:`);
      console.log(`- 잠금 ID: ${event.args.lockId}`);
      console.log(`- 생성자: ${event.args.creator}`);
      console.log(`- 수혜자: ${event.args.beneficiary}`);
      console.log(`- 금액: ${formatEther(event.args.amount!)} ETH`);
    });
    
    const withdrawalEvents = await advancedLock.getEvents.Withdrawn();
    console.log(`\n💸 Withdrawal 이벤트: ${withdrawalEvents.length}개`);
    
    withdrawalEvents.forEach((event, index) => {
      console.log(`이벤트 ${index + 1}:`);
      console.log(`- 잠금 ID: ${event.args.lockId}`);
      console.log(`- 수혜자: ${event.args.beneficiary}`);
      console.log(`- 금액: ${formatEther(event.args.amount!)} ETH`);
    });
    
  } catch (error) {
    console.log("이벤트 조회 중 오류 발생");
  }
  
  console.log("\n🎉 고급 상호작용 데모 완료!");
  console.log(`컨트랙트 주소: ${advancedLock.address}`);
  console.log("이 주소로 콘솔에서 추가 실험을 해보세요!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
