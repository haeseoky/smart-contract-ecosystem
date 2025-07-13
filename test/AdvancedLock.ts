import { expect } from "chai";
import hre from "hardhat";
import { parseEther, formatEther } from "viem";
import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";

describe("AdvancedLock", function () {
  async function deployAdvancedLockFixture() {
    const [owner, user1, user2] = await hre.viem.getWalletClients();
    
    const advancedLock = await hre.viem.deployContract("AdvancedLock");
    const publicClient = await hre.viem.getPublicClient();

    return {
      advancedLock,
      owner,
      user1,
      user2,
      publicClient,
    };
  }

  describe("다중 사용자 잠금 테스트", function () {
    it("여러 사용자가 동시에 잠금을 생성할 수 있어야 함", async function () {
      const { advancedLock, user1, user2 } = await loadFixture(deployAdvancedLockFixture);

      const lockDuration = 3600; // 1시간
      const lockAmount = parseEther("1.0"); // 1 ETH

      // User1이 잠금 생성
      await advancedLock.write.createLock([user1.account.address, lockDuration], {
        value: lockAmount,
        account: user1.account
      });

      // User2가 잠금 생성  
      await advancedLock.write.createLock([user2.account.address, lockDuration], {
        value: lockAmount,
        account: user2.account
      });

      // 각자의 잠금 확인
      const user1Locks = await advancedLock.read.getUserLocks([user1.account.address]);
      const user2Locks = await advancedLock.read.getUserLocks([user2.account.address]);

      expect(user1Locks).to.have.lengthOf(1);
      expect(user2Locks).to.have.lengthOf(1);
    });

    it("잠긴 총 금액을 정확히 추적해야 함", async function () {
      const { advancedLock, user1, user2 } = await loadFixture(deployAdvancedLockFixture);

      const lockAmount1 = parseEther("2.0");
      const lockAmount2 = parseEther("3.0");
      const lockDuration = 3600;

      await advancedLock.write.createLock([user1.account.address, lockDuration], {
        value: lockAmount1,
        account: user1.account
      });

      await advancedLock.write.createLock([user2.account.address, lockDuration], {
        value: lockAmount2,
        account: user2.account
      });

      const totalLocked = await advancedLock.read.totalLocked();
      expect(totalLocked).to.equal(lockAmount1 + lockAmount2);
    });
  });

  describe("시간 기반 인출 테스트", function () {
    it("시간이 지나면 인출할 수 있어야 함", async function () {
      const { advancedLock, user1, publicClient } = await loadFixture(deployAdvancedLockFixture);

      const lockDuration = 3600; // 1시간
      const lockAmount = parseEther("1.0");

      await advancedLock.write.createLock([user1.account.address, lockDuration], {
        value: lockAmount,
        account: user1.account
      });

      // 시간을 1시간 뒤로 이동
      await time.increase(lockDuration);

      // 인출 실행
      const initialBalance = await publicClient.getBalance({
        address: user1.account.address,
      });

      await advancedLock.write.withdraw([0n], {
        account: user1.account
      });

      const finalBalance = await publicClient.getBalance({
        address: user1.account.address,
      });

      // 가스비를 제외하고 거의 1 ETH 증가했는지 확인
      const balanceIncrease = finalBalance - initialBalance;
      expect(balanceIncrease).to.be.greaterThan(parseEther("0.99")); // 가스비 고려
    });
  });

  describe("보안 기능 테스트", function () {
    it("일시정지 기능이 작동해야 함", async function () {
      const { advancedLock, owner, user1 } = await loadFixture(deployAdvancedLockFixture);

      // 컨트랙트 일시정지
      await advancedLock.write.pause({ account: owner.account });

      // 일시정지 상태에서 잠금 생성 시도 (실패해야 함)
      await expect(
        advancedLock.write.createLock([user1.account.address, 3600], {
          value: parseEther("1.0"),
          account: user1.account
        })
      ).to.be.rejected;

      // 일시정지 해제
      await advancedLock.write.unpause({ account: owner.account });

      // 이제 정상 작동해야 함
      await expect(
        advancedLock.write.createLock([user1.account.address, 3600], {
          value: parseEther("1.0"),
          account: user1.account
        })
      ).to.be.fulfilled;
    });
  });
});
