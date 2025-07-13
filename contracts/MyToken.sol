// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title MyToken
 * @dev 실제 사용되는 ERC-20 토큰 컨트랙트
 * 
 * 주요 기능:
 * - 표준 ERC-20 기능 (전송, 승인, 잔액 조회)
 * - 민팅/번 기능
 * - 일시정지 기능
 * - 소유자 권한 관리
 * 
 * 실제 사용 예시:
 * - USDC (Circle USD Coin)
 * - LINK (Chainlink Token)
 * - UNI (Uniswap Token)
 */
contract MyToken is ERC20, Ownable, Pausable {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 10억 토큰
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 1억 토큰
    
    // 에어드랍 관련
    mapping(address => bool) public hasClaimedAirdrop;
    uint256 public constant AIRDROP_AMOUNT = 100 * 10**18; // 100 토큰
    
    // 스테이킹 관련
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakingStartTime;
    uint256 public constant STAKING_REWARD_RATE = 10; // 10% 연이율
    
    event AirdropClaimed(address indexed user, uint256 amount);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    
    constructor() ERC20("MyToken", "MTK") Ownable(msg.sender) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
    
    /**
     * @dev 관리자가 새로운 토큰을 발행
     */
    function mint(address to, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }
    
    /**
     * @dev 토큰 소각 (디플레이션 메커니즘)
     */
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
    
    /**
     * @dev 에어드랍 claim (1회만 가능)
     */
    function claimAirdrop() public whenNotPaused {
        require(!hasClaimedAirdrop[msg.sender], "Already claimed");
        require(totalSupply() + AIRDROP_AMOUNT <= MAX_SUPPLY, "Exceeds max supply");
        
        hasClaimedAirdrop[msg.sender] = true;
        _mint(msg.sender, AIRDROP_AMOUNT);
        
        emit AirdropClaimed(msg.sender, AIRDROP_AMOUNT);
    }
    
    /**
     * @dev 토큰 스테이킹
     */
    function stake(uint256 amount) public whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        // 기존 스테이킹이 있다면 보상 먼저 정산
        if (stakedBalance[msg.sender] > 0) {
            _claimStakingReward();
        }
        
        _transfer(msg.sender, address(this), amount);
        stakedBalance[msg.sender] += amount;
        stakingStartTime[msg.sender] = block.timestamp;
        
        emit Staked(msg.sender, amount);
    }
    
    /**
     * @dev 스테이킹 해제
     */
    function unstake(uint256 amount) public {
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");
        
        uint256 reward = calculateStakingReward(msg.sender);
        
        stakedBalance[msg.sender] -= amount;
        _transfer(address(this), msg.sender, amount);
        
        // 보상 지급
        if (reward > 0 && totalSupply() + reward <= MAX_SUPPLY) {
            _mint(msg.sender, reward);
        }
        
        stakingStartTime[msg.sender] = block.timestamp;
        
        emit Unstaked(msg.sender, amount, reward);
    }
    
    /**
     * @dev 스테이킹 보상 계산
     */
    function calculateStakingReward(address user) public view returns (uint256) {
        if (stakedBalance[user] == 0) return 0;
        
        uint256 stakingDuration = block.timestamp - stakingStartTime[user];
        uint256 annualReward = (stakedBalance[user] * STAKING_REWARD_RATE) / 100;
        
        return (annualReward * stakingDuration) / 365 days;
    }
    
    /**
     * @dev 스테이킹 보상만 claim
     */
    function claimStakingReward() public {
        _claimStakingReward();
    }
    
    function _claimStakingReward() internal {
        uint256 reward = calculateStakingReward(msg.sender);
        if (reward > 0 && totalSupply() + reward <= MAX_SUPPLY) {
            _mint(msg.sender, reward);
            stakingStartTime[msg.sender] = block.timestamp;
        }
    }
    
    /**
     * @dev 긴급 상황 시 일시정지
     */
    function pause() public onlyOwner {
        _pause();
    }
    
    function unpause() public onlyOwner {
        _unpause();
    }
    
    /**
     * @dev 일시정지 중에는 전송 불가
     */
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }
}
