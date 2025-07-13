// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title AdvancedLock
 * @dev 고급 기능을 포함한 시간 기반 잠금 컨트랙트
 * @notice 다중 사용자, 부분 인출, 긴급 정지 기능 포함
 */
contract AdvancedLock is Ownable, ReentrancyGuard, Pausable {
    
    // 잠금 정보 구조체
    struct LockInfo {
        uint256 amount;      // 잠긴 금액
        uint256 unlockTime;  // 잠금 해제 시간
        bool withdrawn;      // 인출 여부
        address beneficiary; // 수혜자 주소
    }
    
    // 상태 변수
    mapping(uint256 => LockInfo) public locks;
    mapping(address => uint256[]) public userLocks;
    uint256 public nextLockId;
    uint256 public totalLocked;
    uint256 public constant MIN_LOCK_DURATION = 1 hours;
    uint256 public constant MAX_LOCK_DURATION = 365 days;
    
    // 이벤트
    event LockCreated(
        uint256 indexed lockId,
        address indexed creator,
        address indexed beneficiary,
        uint256 amount,
        uint256 unlockTime
    );
    
    event Withdrawn(
        uint256 indexed lockId,
        address indexed beneficiary,
        uint256 amount
    );
    
    event EmergencyWithdrawal(
        uint256 indexed lockId,
        address indexed owner,
        uint256 amount
    );
    
    // 수정자
    modifier validLockDuration(uint256 _duration) {
        require(
            _duration >= MIN_LOCK_DURATION && _duration <= MAX_LOCK_DURATION,
            "Invalid lock duration"
        );
        _;
    }
    
    modifier lockExists(uint256 _lockId) {
        require(_lockId < nextLockId, "Lock does not exist");
        _;
    }
    
    modifier onlyBeneficiary(uint256 _lockId) {
        require(
            msg.sender == locks[_lockId].beneficiary,
            "Not the beneficiary"
        );
        _;
    }
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev 새로운 잠금 생성
     * @param _beneficiary 수혜자 주소
     * @param _duration 잠금 기간 (초)
     */
    function createLock(
        address _beneficiary,
        uint256 _duration
    ) 
        external 
        payable 
        whenNotPaused 
        validLockDuration(_duration) 
    {
        require(msg.value > 0, "Amount must be greater than 0");
        require(_beneficiary != address(0), "Invalid beneficiary address");
        
        uint256 unlockTime = block.timestamp + _duration;
        uint256 lockId = nextLockId++;
        
        locks[lockId] = LockInfo({
            amount: msg.value,
            unlockTime: unlockTime,
            withdrawn: false,
            beneficiary: _beneficiary
        });
        
        userLocks[_beneficiary].push(lockId);
        totalLocked += msg.value;
        
        emit LockCreated(lockId, msg.sender, _beneficiary, msg.value, unlockTime);
    }
    
    /**
     * @dev 잠금된 자금 인출
     * @param _lockId 잠금 ID
     */
    function withdraw(uint256 _lockId) 
        external 
        nonReentrant 
        whenNotPaused 
        lockExists(_lockId) 
        onlyBeneficiary(_lockId) 
    {
        LockInfo storage lock = locks[_lockId];
        
        require(!lock.withdrawn, "Already withdrawn");
        require(block.timestamp >= lock.unlockTime, "Lock not yet expired");
        
        lock.withdrawn = true;
        totalLocked -= lock.amount;
        
        emit Withdrawn(_lockId, msg.sender, lock.amount);
        
        (bool success, ) = payable(msg.sender).call{value: lock.amount}("");
        require(success, "Transfer failed");
    }
    
    /**
     * @dev 사용자의 모든 잠금 ID 조회
     * @param _user 사용자 주소
     * @return 잠금 ID 배열
     */
    function getUserLocks(address _user) external view returns (uint256[] memory) {
        return userLocks[_user];
    }
    
    /**
     * @dev 사용자의 총 잠긴 금액 조회
     * @param _user 사용자 주소
     * @return 총 잠긴 금액
     */
    function getUserTotalLocked(address _user) external view returns (uint256) {
        uint256[] memory lockIds = userLocks[_user];
        uint256 total = 0;
        
        for (uint256 i = 0; i < lockIds.length; i++) {
            LockInfo memory lock = locks[lockIds[i]];
            if (!lock.withdrawn) {
                total += lock.amount;
            }
        }
        
        return total;
    }
    
    /**
     * @dev 긴급 상황 시 컨트랙트 일시 정지
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev 컨트랙트 일시 정지 해제
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev 긴급 상황 시 자금 인출 (소유자만)
     * @param _lockId 잠금 ID
     */
    function emergencyWithdraw(uint256 _lockId)
        external 
        onlyOwner 
        lockExists(_lockId) 
    {
        LockInfo storage lock = locks[_lockId];
        require(!lock.withdrawn, "Already withdrawn");
        
        lock.withdrawn = true;
        totalLocked -= lock.amount;
        
        emit EmergencyWithdrawal(_lockId, msg.sender, lock.amount);
        
        (bool success, ) = payable(owner()).call{value: lock.amount}("");
        require(success, "Transfer failed");
    }
    
    /**
     * @dev 컨트랙트 자체 파괴 (긴급 상황 시)
     */
    function destroy() external onlyOwner {
        require(totalLocked == 0, "Cannot destroy with locked funds");
        selfdestruct(payable(owner()));
    }
}
