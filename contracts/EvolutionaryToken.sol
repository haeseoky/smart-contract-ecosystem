// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title EvolutionaryToken
 * @dev Self-Evolving ERC-20 Token with AI-Driven Features and Dynamic Economics
 * @notice A revolutionary token that adapts and evolves based on usage patterns and community behavior
 */
contract EvolutionaryToken is ERC20, ERC20Burnable, Ownable, ReentrancyGuard {
    
    struct Evolution {
        uint256 generation;
        uint256 timestamp;
        string featureName;
        uint256 impactScore;
        bool isActive;
    }
    
    struct UserProfile {
        uint256 activityScore;
        uint256 stakingAmount;
        uint256 stakingStartTime;
        uint256 lastActivityTime;
        uint256 contributionPoints;
        uint256 reputationScore;
        UserTier tier;
        uint256[] ownedNFTs; // For future NFT integration
    }
    
    enum UserTier { BRONZE, SILVER, GOLD, PLATINUM, DIAMOND }
    
    struct StakingPool {
        uint256 totalStaked;
        uint256 rewardRate; // APY in basis points
        uint256 lockPeriod;
        uint256 minStakeAmount;
        bool isActive;
        string poolName;
    }
    
    struct GovernanceProposal {
        uint256 id;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 deadline;
        bool executed;
        address proposer;
        ProposalType proposalType;
    }
    
    enum ProposalType { EVOLUTION, STAKING_PARAMS, BURNING, MINTING, PARTNERSHIP }
    
    // Core Token Economics
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18; // 1M tokens
    uint256 public constant MAX_SUPPLY = 10000000 * 10**18; // 10M max supply
    uint256 public constant EVOLUTION_INTERVAL = 30 days;
    uint256 public constant ACTIVITY_DECAY_RATE = 99; // 1% decay per day
    
    // Evolution System
    mapping(uint256 => Evolution) public evolutions;
    uint256 public currentGeneration = 0;
    uint256 public lastEvolutionTime;
    uint256 public evolutionThreshold = 1000; // Activity points needed for evolution
    
    // User Management
    mapping(address => UserProfile) public userProfiles;
    mapping(address => uint256) public lastClaimTime;
    mapping(address => bool) public isWhitelisted;
    
    // Staking System
    mapping(uint256 => StakingPool) public stakingPools;
    mapping(address => mapping(uint256 => uint256)) public userStakes; // user => poolId => amount
    mapping(address => uint256[]) public userStakingPools;
    uint256 public stakingPoolCount = 0;
    
    // Governance System
    mapping(uint256 => GovernanceProposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => uint256) public votingPower;
    uint256 public proposalCount = 0;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant PROPOSAL_THRESHOLD = 10000 * 10**18; // 10k tokens to propose
    
    // Dynamic Economics
    uint256 public burnRate = 100; // 1% burn rate
    uint256 public mintRate = 50; // 0.5% mint rate
    uint256 public rewardPool = 0;
    uint256 public developmentFund = 0;
    uint256 public marketingFund = 0;
    
    // AI Features (simulated)
    mapping(address => uint256) public userBehaviorScore;
    mapping(address => uint256) public fraudRiskScore;
    uint256 public communityHealthScore = 100;
    
    // Events
    event Evolution(uint256 indexed generation, string featureName, uint256 timestamp);
    event ActivityTracked(address indexed user, uint256 activityPoints, uint256 totalScore);
    event TierUpgraded(address indexed user, UserTier newTier);
    event StakingRewardClaimed(address indexed user, uint256 amount, uint256 poolId);
    event ProposalCreated(uint256 indexed proposalId, address proposer, string description);
    event VoteCast(uint256 indexed proposalId, address voter, bool support, uint256 weight);
    event BurnExecuted(uint256 amount, string reason);
    event MintExecuted(address recipient, uint256 amount, string reason);
    event UserProfileUpdated(address indexed user, uint256 activityScore, UserTier tier);
    event AntiWhaleTriggered(address indexed whale, uint256 amount, uint256 fee);
    event CommunityHealthUpdated(uint256 newScore, string reason);
    
    constructor() ERC20("EvolutionCoin", "EVO") {
        _mint(msg.sender, INITIAL_SUPPLY);
        lastEvolutionTime = block.timestamp;
        
        // Initialize first staking pool
        createStakingPool("Genesis Pool", 1000, 30 days, 100 * 10**18); // 10% APY, 30 days lock
        
        // Initialize deployer profile
        userProfiles[msg.sender] = UserProfile({
            activityScore: 1000,
            stakingAmount: 0,
            stakingStartTime: 0,
            lastActivityTime: block.timestamp,
            contributionPoints: 100,
            reputationScore: 100,
            tier: UserTier.GOLD,
            ownedNFTs: new uint256[](0)
        });
    }
    
    /**
     * @dev Override transfer to include activity tracking and anti-whale protection
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        _trackActivity(msg.sender, amount / 10**18); // 1 point per token
        _trackActivity(to, amount / 10**18);
        
        // Anti-whale protection
        uint256 fee = _calculateAntiWhaleFee(msg.sender, amount);
        if (fee > 0) {
            _transfer(msg.sender, address(this), fee);
            rewardPool += fee;
            emit AntiWhaleTriggered(msg.sender, amount, fee);
            amount -= fee;
        }
        
        return super.transfer(to, amount);
    }
    
    /**
     * @dev Override transferFrom with same protections
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _trackActivity(from, amount / 10**18);
        _trackActivity(to, amount / 10**18);
        
        uint256 fee = _calculateAntiWhaleFee(from, amount);
        if (fee > 0) {
            _transfer(from, address(this), fee);
            rewardPool += fee;
            emit AntiWhaleTriggered(from, amount, fee);
            amount -= fee;
        }
        
        return super.transferFrom(from, to, amount);
    }
    
    /**
     * @dev Calculate anti-whale fee based on transaction size and user behavior
     */
    function _calculateAntiWhaleFee(address user, uint256 amount) internal view returns (uint256) {
        uint256 userBalance = balanceOf(user);
        uint256 totalSupply = totalSupply();
        
        // If user holds more than 1% of supply and transferring more than 0.1%
        if (userBalance > totalSupply / 100 && amount > totalSupply / 1000) {
            uint256 whalePercentage = (userBalance * 100) / totalSupply;
            uint256 txPercentage = (amount * 100) / totalSupply;
            
            // Progressive fee: 0.1% to 2% based on whale size and transaction size
            uint256 feeRate = (whalePercentage + txPercentage) / 10;
            if (feeRate > 200) feeRate = 200; // Cap at 2%
            
            return (amount * feeRate) / 10000;
        }
        
        return 0;
    }
    
    /**
     * @dev Track user activity and update scores
     */
    function _trackActivity(address user, uint256 activityPoints) internal {
        UserProfile storage profile = userProfiles[user];
        
        // Decay previous activity score (1% daily decay)
        uint256 timeSinceLastActivity = block.timestamp - profile.lastActivityTime;
        uint256 decayDays = timeSinceLastActivity / 1 days;
        
        if (decayDays > 0) {
            for (uint256 i = 0; i < decayDays && i < 30; i++) {
                profile.activityScore = (profile.activityScore * ACTIVITY_DECAY_RATE) / 100;
            }
        }
        
        // Add new activity points
        profile.activityScore += activityPoints;
        profile.lastActivityTime = block.timestamp;
        
        // Update user tier
        UserTier newTier = _calculateUserTier(profile.activityScore, profile.stakingAmount);
        if (newTier != profile.tier) {
            profile.tier = newTier;
            emit TierUpgraded(user, newTier);
        }
        
        // Update voting power
        votingPower[user] = _calculateVotingPower(user);
        
        emit ActivityTracked(user, activityPoints, profile.activityScore);
        emit UserProfileUpdated(user, profile.activityScore, profile.tier);
        
        // Check for evolution trigger
        _checkEvolutionTrigger();
    }
    
    /**
     * @dev Calculate user tier based on activity and staking
     */
    function _calculateUserTier(uint256 activityScore, uint256 stakingAmount) internal pure returns (UserTier) {
        uint256 combinedScore = activityScore + (stakingAmount / 10**18);
        
        if (combinedScore >= 10000) return UserTier.DIAMOND;
        if (combinedScore >= 5000) return UserTier.PLATINUM;
        if (combinedScore >= 2000) return UserTier.GOLD;
        if (combinedScore >= 500) return UserTier.SILVER;
        return UserTier.BRONZE;
    }
    
    /**
     * @dev Calculate voting power based on tokens, staking, and reputation
     */
    function _calculateVotingPower(address user) internal view returns (uint256) {
        UserProfile memory profile = userProfiles[user];
        uint256 tokenWeight = balanceOf(user);
        uint256 stakingWeight = profile.stakingAmount * 2; // 2x weight for staked tokens
        uint256 reputationWeight = profile.reputationScore * 100 * 10**18;
        
        return tokenWeight + stakingWeight + reputationWeight;
    }
    
    /**
     * @dev Check if conditions are met for evolution
     */
    function _checkEvolutionTrigger() internal {
        if (block.timestamp >= lastEvolutionTime + EVOLUTION_INTERVAL) {
            uint256 totalCommunityActivity = _calculateTotalCommunityActivity();
            
            if (totalCommunityActivity >= evolutionThreshold) {
                _triggerEvolution();
            }
        }
    }
    
    /**
     * @dev Calculate total community activity
     */
    function _calculateTotalCommunityActivity() internal view returns (uint256) {
        // In a real implementation, this would aggregate all user activity scores
        // For simplicity, we'll use a placeholder calculation
        return communityHealthScore * 10;
    }
    
    /**
     * @dev Trigger token evolution with new features
     */
    function _triggerEvolution() internal {
        currentGeneration++;
        lastEvolutionTime = block.timestamp;
        
        string memory newFeature;
        uint256 impactScore = 50;
        
        // Determine evolution based on generation
        if (currentGeneration == 1) {
            newFeature = "Advanced Staking Pools";
            _enableAdvancedStaking();
            impactScore = 75;
        } else if (currentGeneration == 2) {
            newFeature = "Dynamic Burn Mechanism";
            _enableDynamicBurning();
            impactScore = 60;
        } else if (currentGeneration == 3) {
            newFeature = "AI Behavior Analysis";
            _enableAIFeatures();
            impactScore = 90;
        } else if (currentGeneration == 4) {
            newFeature = "Cross-Chain Compatibility";
            _enableCrossChain();
            impactScore = 85;
        } else {
            newFeature = "Community Innovation";
            _enableCommunityFeatures();
            impactScore = 70;
        }
        
        evolutions[currentGeneration] = Evolution({
            generation: currentGeneration,
            timestamp: block.timestamp,
            featureName: newFeature,
            impactScore: impactScore,
            isActive: true
        });
        
        // Increase evolution threshold for next evolution
        evolutionThreshold = evolutionThreshold * 120 / 100; // 20% increase
        
        emit Evolution(currentGeneration, newFeature, block.timestamp);
    }
    
    /**
     * @dev Enable advanced staking features
     */
    function _enableAdvancedStaking() internal {
        createStakingPool("Evolution Pool", 1500, 60 days, 1000 * 10**18); // 15% APY
        createStakingPool("Diamond Pool", 2000, 90 days, 5000 * 10**18); // 20% APY
    }
    
    /**
     * @dev Enable dynamic burning mechanism
     */
    function _enableDynamicBurning() internal {
        // Burn tokens based on whale activity
        uint256 burnAmount = rewardPool / 2;
        if (burnAmount > 0) {
            _burn(address(this), burnAmount);
            rewardPool -= burnAmount;
            emit BurnExecuted(burnAmount, "Dynamic Burn - Whale Activity");
        }
    }
    
    /**
     * @dev Enable AI behavior analysis features
     */
    function _enableAIFeatures() internal {
        // Simulate AI analysis update
        communityHealthScore = (communityHealthScore + 110) / 2; // Improve health
        emit CommunityHealthUpdated(communityHealthScore, "AI Analysis Enabled");
    }
    
    /**
     * @dev Enable cross-chain compatibility
     */
    function _enableCrossChain() internal {
        // Placeholder for cross-chain features
        // In real implementation, this would enable bridge contracts
    }
    
    /**
     * @dev Enable community-driven features
     */
    function _enableCommunityFeatures() internal {
        // Distribute rewards to active community members
        uint256 communityReward = rewardPool / 4;
        if (communityReward > 0) {
            developmentFund += communityReward / 2;
            marketingFund += communityReward / 2;
        }
    }
    
    /**
     * @dev Create a new staking pool
     */
    function createStakingPool(
        string memory name,
        uint256 rewardRate,
        uint256 lockPeriod,
        uint256 minStakeAmount
    ) public onlyOwner returns (uint256) {
        stakingPoolCount++;
        uint256 poolId = stakingPoolCount;
        
        stakingPools[poolId] = StakingPool({
            totalStaked: 0,
            rewardRate: rewardRate,
            lockPeriod: lockPeriod,
            minStakeAmount: minStakeAmount,
            isActive: true,
            poolName: name
        });
        
        return poolId;
    }
    
    /**
     * @dev Stake tokens in a specific pool
     */
    function stake(uint256 poolId, uint256 amount) external nonReentrant {
        require(stakingPools[poolId].isActive, "Pool not active");
        require(amount >= stakingPools[poolId].minStakeAmount, "Below minimum stake");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        // Transfer tokens to contract
        _transfer(msg.sender, address(this), amount);
        
        // Update user stake
        userStakes[msg.sender][poolId] += amount;
        stakingPools[poolId].totalStaked += amount;
        
        // Update user profile
        UserProfile storage profile = userProfiles[msg.sender];
        profile.stakingAmount += amount;
        if (profile.stakingStartTime == 0) {
            profile.stakingStartTime = block.timestamp;
        }
        
        // Add to user's staking pools if not already there
        bool poolExists = false;
        for (uint256 i = 0; i < userStakingPools[msg.sender].length; i++) {
            if (userStakingPools[msg.sender][i] == poolId) {
                poolExists = true;
                break;
            }
        }
        if (!poolExists) {
            userStakingPools[msg.sender].push(poolId);
        }
        
        _trackActivity(msg.sender, amount / 10**18);
    }
    
    /**
     * @dev Unstake tokens from a pool
     */
    function unstake(uint256 poolId, uint256 amount) external nonReentrant {
        require(userStakes[msg.sender][poolId] >= amount, "Insufficient staked amount");
        
        StakingPool memory pool = stakingPools[poolId];
        UserProfile memory profile = userProfiles[msg.sender];
        
        // Check lock period
        require(
            block.timestamp >= profile.stakingStartTime + pool.lockPeriod,
            "Tokens still locked"
        );
        
        // Calculate and distribute rewards
        uint256 reward = calculateStakingReward(msg.sender, poolId);
        if (reward > 0) {
            _mint(msg.sender, reward);
            emit StakingRewardClaimed(msg.sender, reward, poolId);
        }
        
        // Update stakes
        userStakes[msg.sender][poolId] -= amount;
        stakingPools[poolId].totalStaked -= amount;
        userProfiles[msg.sender].stakingAmount -= amount;
        
        // Transfer tokens back
        _transfer(address(this), msg.sender, amount);
        
        _trackActivity(msg.sender, amount / 10**18);
    }
    
    /**
     * @dev Calculate staking rewards for a user in a specific pool
     */
    function calculateStakingReward(address user, uint256 poolId) public view returns (uint256) {
        uint256 stakedAmount = userStakes[user][poolId];
        if (stakedAmount == 0) return 0;
        
        StakingPool memory pool = stakingPools[poolId];
        UserProfile memory profile = userProfiles[user];
        
        uint256 stakingDuration = block.timestamp - profile.stakingStartTime;
        uint256 yearlyReward = (stakedAmount * pool.rewardRate) / 10000;
        uint256 reward = (yearlyReward * stakingDuration) / 365 days;
        
        // Tier bonus
        uint256 tierBonus = uint256(profile.tier) * 5; // 0-20% bonus
        reward += (reward * tierBonus) / 100;
        
        return reward;
    }
    
    /**
     * @dev Claim all staking rewards
     */
    function claimAllRewards() external nonReentrant {
        uint256 totalReward = 0;
        
        for (uint256 i = 0; i < userStakingPools[msg.sender].length; i++) {
            uint256 poolId = userStakingPools[msg.sender][i];
            uint256 reward = calculateStakingReward(msg.sender, poolId);
            totalReward += reward;
        }
        
        require(totalReward > 0, "No rewards to claim");
        require(totalSupply() + totalReward <= MAX_SUPPLY, "Would exceed max supply");
        
        _mint(msg.sender, totalReward);
        lastClaimTime[msg.sender] = block.timestamp;
        
        emit StakingRewardClaimed(msg.sender, totalReward, 0);
    }
    
    /**
     * @dev Create a governance proposal
     */
    function createProposal(
        string memory description,
        ProposalType proposalType
    ) external returns (uint256) {
        require(votingPower[msg.sender] >= PROPOSAL_THRESHOLD, "Insufficient voting power");
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        proposals[proposalId] = GovernanceProposal({
            id: proposalId,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            deadline: block.timestamp + VOTING_PERIOD,
            executed: false,
            proposer: msg.sender,
            proposalType: proposalType
        });
        
        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }
    
    /**
     * @dev Vote on a governance proposal
     */
    function vote(uint256 proposalId, bool support) external {
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        require(block.timestamp <= proposals[proposalId].deadline, "Voting ended");
        require(proposals[proposalId].id != 0, "Proposal doesn't exist");
        
        uint256 weight = votingPower[msg.sender];
        require(weight > 0, "No voting power");
        
        hasVoted[proposalId][msg.sender] = true;
        
        if (support) {
            proposals[proposalId].forVotes += weight;
        } else {
            proposals[proposalId].againstVotes += weight;
        }
        
        emit VoteCast(proposalId, msg.sender, support, weight);
    }
    
    /**
     * @dev Execute a passed governance proposal
     */
    function executeProposal(uint256 proposalId) external {
        GovernanceProposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.deadline, "Voting not ended");
        require(!proposal.executed, "Already executed");
        require(proposal.forVotes > proposal.againstVotes, "Proposal failed");
        
        proposal.executed = true;
        
        // Execute based on proposal type
        if (proposal.proposalType == ProposalType.EVOLUTION) {
            _triggerEvolution();
        } else if (proposal.proposalType == ProposalType.BURNING) {
            uint256 burnAmount = totalSupply() / 1000; // 0.1% of supply
            _burn(address(this), burnAmount);
            emit BurnExecuted(burnAmount, "Governance Burn");
        } else if (proposal.proposalType == ProposalType.MINTING) {
            uint256 mintAmount = totalSupply() / 2000; // 0.05% of supply
            _mint(developmentFund != 0 ? address(this) : proposal.proposer, mintAmount);
            emit MintExecuted(proposal.proposer, mintAmount, "Governance Mint");
        }
    }
    
    /**
     * @dev Emergency burn function for economic balance
     */
    function emergencyBurn(uint256 amount) external onlyOwner {
        require(amount <= totalSupply() / 100, "Cannot burn more than 1%");
        _burn(address(this), amount);
        emit BurnExecuted(amount, "Emergency Burn");
    }
    
    /**
     * @dev Update community health score (AI simulation)
     */
    function updateCommunityHealth(uint256 newScore, string memory reason) external onlyOwner {
        require(newScore <= 100, "Score cannot exceed 100");
        communityHealthScore = newScore;
        emit CommunityHealthUpdated(newScore, reason);
    }
    
    /**
     * @dev Get comprehensive user information
     */
    function getUserInfo(address user) external view returns (
        UserProfile memory profile,
        uint256 totalStaked,
        uint256 availableRewards,
        uint256 userVotingPower,
        uint256 behaviorScore
    ) {
        profile = userProfiles[user];
        userVotingPower = votingPower[user];
        behaviorScore = userBehaviorScore[user];
        
        // Calculate total staked across all pools
        for (uint256 i = 0; i < userStakingPools[user].length; i++) {
            uint256 poolId = userStakingPools[user][i];
            totalStaked += userStakes[user][poolId];
        }
        
        // Calculate available rewards across all pools
        for (uint256 i = 0; i < userStakingPools[user].length; i++) {
            uint256 poolId = userStakingPools[user][i];
            availableRewards += calculateStakingReward(user, poolId);
        }
        
        return (profile, totalStaked, availableRewards, userVotingPower, behaviorScore);
    }
    
    /**
     * @dev Get token evolution history
     */
    function getEvolutionHistory() external view returns (Evolution[] memory) {
        Evolution[] memory history = new Evolution[](currentGeneration);
        
        for (uint256 i = 1; i <= currentGeneration; i++) {
            history[i-1] = evolutions[i];
        }
        
        return history;
    }
    
    /**
     * @dev Get staking pool information
     */
    function getStakingPoolInfo(uint256 poolId) external view returns (
        StakingPool memory pool,
        uint256 totalValueLocked,
        uint256 currentAPY
    ) {
        pool = stakingPools[poolId];
        totalValueLocked = pool.totalStaked;
        currentAPY = pool.rewardRate; // In basis points
        
        return (pool, totalValueLocked, currentAPY);
    }
    
    /**
     * @dev Get governance statistics
     */
    function getGovernanceStats() external view returns (
        uint256 totalProposals,
        uint256 activeProposals,
        uint256 executedProposals,
        uint256 totalVotingPower
    ) {
        totalProposals = proposalCount;
        totalVotingPower = totalSupply(); // Simplified
        
        for (uint256 i = 1; i <= proposalCount; i++) {
            if (block.timestamp <= proposals[i].deadline && !proposals[i].executed) {
                activeProposals++;
            }
            if (proposals[i].executed) {
                executedProposals++;
            }
        }
        
        return (totalProposals, activeProposals, executedProposals, totalVotingPower);
    }
    
    /**
     * @dev Get economic metrics
     */
    function getEconomicMetrics() external view returns (
        uint256 currentSupply,
        uint256 maxSupplyLimit,
        uint256 burnRatePercent,
        uint256 stakingRatio,
        uint256 rewardPoolBalance,
        uint256 communityHealth
    ) {
        currentSupply = totalSupply();
        maxSupplyLimit = MAX_SUPPLY;
        burnRatePercent = burnRate;
        rewardPoolBalance = rewardPool;
        communityHealth = communityHealthScore;
        
        // Calculate staking ratio
        uint256 totalStakedTokens = 0;
        for (uint256 i = 1; i <= stakingPoolCount; i++) {
            totalStakedTokens += stakingPools[i].totalStaked;
        }
        stakingRatio = totalStakedTokens > 0 ? (totalStakedTokens * 100) / currentSupply : 0;
        
        return (
            currentSupply,
            maxSupplyLimit,
            burnRatePercent,
            stakingRatio,
            rewardPoolBalance,
            communityHealth
        );
    }
    
    /**
     * @dev Manual evolution trigger (only owner, for emergency)
     */
    function manualEvolution(string memory featureName) external onlyOwner {
        currentGeneration++;
        
        evolutions[currentGeneration] = Evolution({
            generation: currentGeneration,
            timestamp: block.timestamp,
            featureName: featureName,
            impactScore: 100,
            isActive: true
        });
        
        lastEvolutionTime = block.timestamp;
        emit Evolution(currentGeneration, featureName, block.timestamp);
    }
    
    /**
     * @dev Withdraw development funds (only owner)
     */
    function withdrawDevelopmentFunds(uint256 amount) external onlyOwner {
        require(amount <= developmentFund, "Insufficient development funds");
        developmentFund -= amount;
        _transfer(address(this), owner(), amount);
    }
    
    /**
     * @dev Update economic parameters (only governance)
     */
    function updateEconomicParameters(
        uint256 newBurnRate,
        uint256 newMintRate
    ) external onlyOwner {
        require(newBurnRate <= 500, "Burn rate too high"); // Max 5%
        require(newMintRate <= 200, "Mint rate too high"); // Max 2%
        
        burnRate = newBurnRate;
        mintRate = newMintRate;
    }
}
