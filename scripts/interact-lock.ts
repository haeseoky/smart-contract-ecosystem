import hre from "hardhat";
import { formatEther, parseEther } from "viem";

async function main() {
  console.log("🔐 Lock 컨트랙트 상호작용 스크립트");
  
  // 배포된 주소 자동 감지 또는 수동 입력
  const deploymentFile = "ignition/deployments/chain-31337/deployed_addresses.json";
  let contractAddress: string;
  
  try {
    const fs = require('fs');
    const deployments = JSON.parse(fs.readFileSync(deploymentFile, 'utf8'));
    contractAddress = deployments["LockModule#Lock"];
    console.log(`📍 자동 감지된 컨트랙트 주소: ${contractAddress}`);
  } catch (error) {
    console.log("❌ 배포 주소를 찾을 수 없습니다.");
    console.log("먼저 'npm run deploy:local'을 실행하세요.");
    return;
  }
  
  // 계정 정보
  const [deployer, user1] = await hre.viem.getWalletClients();
  const publicClient = await hre.viem.getPublicClient();
  
  console.log(`👤 배포자: ${deployer.account.address}`);
  console.log(`👤 사용자1: ${user1.account.address}`);
  
  // 컨트랙트 연결
  const lock = await hre.viem.getContractAt("Lock", contractAddress as `0x${string}`);
  
  console.log("\n📊 현재 컨트랙트 상태:");
  
  // 기본 정보 읽기
  const unlockTime = await lock.read.unlockTime();
  const owner = await lock.read.owner();
  const balance = await publicClient.getBalance({ address: lock.address });
  
  console.log(`- 소유자: ${owner}`);
  console.log(`- 잠금 해제 시간: ${new Date(Number(unlockTime) * 1000).toLocaleString()}`);
  console.log(`- 컨트랙트 잔액: ${formatEther(balance)} ETH`);
  
  // 현재 시간 확인
  const latestBlock = await publicClient.getBlock();
  const currentTime = latestBlock.timestamp;
  console.log(`- 현재 시간: ${new Date(Number(currentTime) * 1000).toLocaleString()}`);
  
  // 인출 가능 여부 확인
  const canWithdraw = currentTime >= unlockTime;
  console.log(`- 인출 가능: ${canWithdraw ? '✅' : '❌'}`);
  
  if (!canWithdraw) {
    const timeLeft = Number(unlockTime) - Number(currentTime);
    const daysLeft = Math.floor(timeLeft / (24 * 60 * 60));
    console.log(`- 인출까지 ${daysLeft}일 남음`);
    
    console.log("\n⏰ 테스트를 위해 시간을 미래로 이동합니다...");
    
    // 시간 이동 (Hardhat 네트워크만 가능)
    await hre.network.provider.send("evm_mine", [Number(unlockTime)]);
    
    const newBlock = await publicClient.getBlock();
    console.log(`✅ 시간 이동 완료: ${new Date(Number(newBlock.timestamp) * 1000).toLocaleString()}`);
  }
  
  console.log("\n💸 인출 테스트:");
  
  try {
    // 인출 전 배포자 잔액
    const beforeBalance = await publicClient.getBalance({
      address: deployer.account.address,
    });
    
    console.log(`인출 전 배포자 잔액: ${formatEther(beforeBalance)} ETH`);
    
    // 인출 실행
    const txHash = await lock.write.withdraw({ account: deployer.account });
    console.log(`🚀 인출 트랜잭션 제출: ${txHash}`);
    
    // 트랜잭션 대기
    const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });
    console.log(`⛽ 가스 사용량: ${receipt.gasUsed.toString()}`);
    
    // 인출 후 잔액 확인
    const afterBalance = await publicClient.getBalance({
      address: deployer.account.address,
    });
    
    const newContractBalance = await publicClient.getBalance({ address: lock.address });
    
    console.log(`인출 후 배포자 잔액: ${formatEther(afterBalance)} ETH`);
    console.log(`인출 후 컨트랙트 잔액: ${formatEther(newContractBalance)} ETH`);
    
    // 순 이득 계산 (가스비 제외)
    const netGain = afterBalance - beforeBalance + receipt.gasUsed * receipt.effectiveGasPrice;
    console.log(`✅ 순 이득 (가스비 제외): ${formatEther(netGain)} ETH`);
    
  } catch (error: any) {
    console.log(`❌ 인출 실패: ${error.shortMessage || error.message}`);
  }
  
  // 이벤트 조회
  console.log("\n📡 이벤트 조회:");
  try {
    const events = await lock.getEvents.Withdrawal();
    console.log(`총 ${events.length}개의 Withdrawal 이벤트 발견`);
    
    events.forEach((event, index) => {
      console.log(`\n이벤트 ${index + 1}:`);
      console.log(`- 블록: ${event.blockNumber}`);
      console.log(`- 금액: ${formatEther(event.args.amount!)} ETH`);
      console.log(`- 시간: ${new Date(Number(event.args.when!) * 1000).toLocaleString()}`);
    });
  } catch (error) {
    console.log("이벤트 조회 중 오류 발생");
  }
  
  console.log("\n🎉 상호작용 완료!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
