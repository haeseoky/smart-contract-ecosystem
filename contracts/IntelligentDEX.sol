// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IntelligentDEX
 * @dev AI-Enhanced Decentralized Exchange with Dynamic Fees and Smart Routing
 * @notice This contract represents the future of DeFi with AI integration
 */
contract IntelligentDEX is ReentrancyGuard, Ownable {
    struct Pool {
        IERC20 tokenA;
        IERC20 tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        uint256 lastUpdate;
        uint256 volume24h;
        uint256 feesCollected;
    }
    
    struct SwapData {
        uint256 timestamp;
        uint256 volume;
        uint256 fee;
        address user;
    }
    
    struct AIAnalytics {
        uint256 volatilityScore;
        uint256 liquidityHealth;
        uint256 tradingActivity;
        uint256 riskLevel;
    }
    
    mapping(bytes32 => Pool) public pools;
    mapping(bytes32 => SwapData[]) public swapHistory;
    mapping(address => mapping(bytes32 => uint256)) public userLiquidity;
    mapping(bytes32 => AIAnalytics) public poolAnalytics;
    
    // AI-Enhanced Features
    mapping(address => uint256) public userTradingScore;
    mapping(address => uint256) public userRewards;
    
    uint256 public constant BASE_FEE = 30; // 0.3%
    uint256 public constant MAX_FEE = 100; // 1%
    uint256 public constant MIN_FEE = 10; // 0.1%
    uint256 public totalVolumeAllTime;
    uint256 public aiUpdateInterval = 1 hours;
    
    event PoolCreated(address indexed tokenA, address indexed tokenB, bytes32 indexed poolId);
    event LiquidityAdded(bytes32 indexed poolId, address indexed provider, uint256 amountA, uint256 amountB);
    event Swap(bytes32 indexed poolId, address indexed user, uint256 amountIn, uint256 amountOut, uint256 fee);
    event AIAnalyticsUpdated(bytes32 indexed poolId, uint256 volatility, uint256 liquidity, uint256 activity);
    event DynamicFeeCalculated(bytes32 indexed poolId, uint256 oldFee, uint256 newFee);
    event UserRewardCalculated(address indexed user, uint256 rewardAmount);
    
    constructor() {}
    
    /**
     * @dev Creates a new trading pool for two tokens
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return poolId The unique identifier for the created pool
     */
    function createPool(address tokenA, address tokenB) external returns (bytes32) {
        require(tokenA != tokenB, "Identical tokens");
        require(tokenA != address(0) && tokenB != address(0), "Zero address");
        
        // Create deterministic pool ID
        bytes32 poolId = keccak256(abi.encodePacked(tokenA, tokenB));
        require(address(pools[poolId].tokenA) == address(0), "Pool exists");
        
        pools[poolId] = Pool({
            tokenA: IERC20(tokenA),
            tokenB: IERC20(tokenB),
            reserveA: 0,
            reserveB: 0,
            totalLiquidity: 0,
            lastUpdate: block.timestamp,
            volume24h: 0,
            feesCollected: 0
        });
        
        // Initialize AI analytics
        poolAnalytics[poolId] = AIAnalytics({
            volatilityScore: 50,
            liquidityHealth: 50,
            tradingActivity: 0,
            riskLevel: 50
        });
        
        emit PoolCreated(tokenA, tokenB, poolId);
        return poolId;
    }
    
    /**
     * @dev Adds liquidity to an existing pool
     * @param poolId The pool to add liquidity to
     * @param amountA Amount of token A
     * @param amountB Amount of token B
     */
    function addLiquidity(
        bytes32 poolId,
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant {
        Pool storage pool = pools[poolId];
        require(address(pool.tokenA) != address(0), "Pool not exists");
        require(amountA > 0 && amountB > 0, "Invalid amounts");
        
        // Calculate optimal amounts if pool has existing liquidity
        if (pool.reserveA > 0 && pool.reserveB > 0) {
            uint256 amountBOptimal = (amountA * pool.reserveB) / pool.reserveA;
            require(amountBOptimal <= amountB, "Insufficient B amount");
            amountB = amountBOptimal;
        }
        
        // Transfer tokens
        pool.tokenA.transferFrom(msg.sender, address(this), amountA);
        pool.tokenB.transferFrom(msg.sender, address(this), amountB);
        
        // Calculate liquidity tokens (simplified geometric mean)
        uint256 liquidity;
        if (pool.totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min(
                (amountA * pool.totalLiquidity) / pool.reserveA,
                (amountB * pool.totalLiquidity) / pool.reserveB
            );
        }
        
        require(liquidity > 0, "Insufficient liquidity minted");
        
        // Update pool state
        userLiquidity[msg.sender][poolId] += liquidity;
        pool.totalLiquidity += liquidity;
        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.lastUpdate = block.timestamp;
        
        // Update AI analytics
        updateLiquidityHealth(poolId);
        
        emit LiquidityAdded(poolId, msg.sender, amountA, amountB);
    }
    
    /**
     * @dev Executes a token swap with AI-enhanced dynamic pricing
     * @param poolId The pool to trade in
     * @param tokenIn The input token address
     * @param amountIn Amount of tokens to swap
     * @param minAmountOut Minimum amount to receive (slippage protection)
     */
    function swap(
        bytes32 poolId,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant {
        Pool storage pool = pools[poolId];
        require(address(pool.tokenA) != address(0), "Pool not exists");
        require(amountIn > 0, "Invalid input amount");
        
        bool isTokenA = tokenIn == address(pool.tokenA);
        require(isTokenA || tokenIn == address(pool.tokenB), "Invalid token");
        
        // AI-Enhanced Dynamic Fee Calculation
        uint256 dynamicFee = calculateAIDynamicFee(poolId, amountIn);
        
        // Calculate output amount using constant product formula
        uint256 amountOut = calculateAmountOut(poolId, tokenIn, amountIn, dynamicFee);
        require(amountOut >= minAmountOut, "Insufficient output amount");
        
        // Execute the swap
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        
        if (isTokenA) {
            pool.tokenB.transfer(msg.sender, amountOut);
            pool.reserveA += amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.tokenA.transfer(msg.sender, amountOut);
            pool.reserveB += amountIn;
            pool.reserveA -= amountOut;
        }
        
        // Record swap data for AI learning
        swapHistory[poolId].push(SwapData({
            timestamp: block.timestamp,
            volume: amountIn,
            fee: dynamicFee,
            user: msg.sender
        }));
        
        // Update metrics
        pool.volume24h += amountIn;
        pool.feesCollected += (amountIn * dynamicFee) / 10000;
        totalVolumeAllTime += amountIn;
        
        // Update user trading score
        updateUserTradingScore(msg.sender, amountIn);
        
        // Update AI analytics
        updateTradingActivity(poolId);
        updateVolatilityScore(poolId);
        
        emit Swap(poolId, msg.sender, amountIn, amountOut, dynamicFee);
        emit DynamicFeeCalculated(poolId, BASE_FEE, dynamicFee);
    }
    
    /**
     * @dev AI-powered dynamic fee calculation
     * @param poolId The pool ID
     * @param amountIn Trade amount
     * @return Dynamic fee in basis points
     */
    function calculateAIDynamicFee(bytes32 poolId, uint256 amountIn) internal view returns (uint256) {
        Pool memory pool = pools[poolId];
        AIAnalytics memory analytics = poolAnalytics[poolId];
        
        uint256 dynamicFee = BASE_FEE;
        
        // Factor 1: Liquidity ratio impact
        uint256 totalReserves = pool.reserveA + pool.reserveB;
        if (totalReserves > 0) {
            uint256 liquidityRatio = (amountIn * 100) / totalReserves;
            if (liquidityRatio > 10) { // Large trade
                dynamicFee += liquidityRatio / 2;
            }
        }
        
        // Factor 2: Volatility adjustment
        if (analytics.volatilityScore > 70) {
            dynamicFee += 20; // High volatility surcharge
        } else if (analytics.volatilityScore < 30) {
            dynamicFee -= 10; // Low volatility discount
        }
        
        // Factor 3: Trading activity bonus/penalty
        uint256 recentSwaps = getRecentSwapCount(poolId);
        if (recentSwaps > 50) { // High activity
            dynamicFee += 15;
        } else if (recentSwaps < 5) { // Low activity incentive
            dynamicFee -= 5;
        }
        
        // Factor 4: Liquidity health adjustment
        if (analytics.liquidityHealth < 30) {
            dynamicFee += 25; // Penalize unhealthy liquidity
        } else if (analytics.liquidityHealth > 80) {
            dynamicFee -= 10; // Reward healthy liquidity
        }
        
        // Ensure fee is within bounds
        if (dynamicFee > MAX_FEE) return MAX_FEE;
        if (dynamicFee < MIN_FEE) return MIN_FEE;
        
        return dynamicFee;
    }
    
    /**
     * @dev Calculates output amount for a given input
     */
    function calculateAmountOut(
        bytes32 poolId,
        address tokenIn,
        uint256 amountIn,
        uint256 fee
    ) internal view returns (uint256) {
        Pool memory pool = pools[poolId];
        
        uint256 amountInWithFee = amountIn * (10000 - fee) / 10000;
        
        if (tokenIn == address(pool.tokenA)) {
            return (amountInWithFee * pool.reserveB) / (pool.reserveA + amountInWithFee);
        } else {
            return (amountInWithFee * pool.reserveA) / (pool.reserveB + amountInWithFee);
        }
    }
    
    /**
     * @dev Updates AI analytics for liquidity health
     */
    function updateLiquidityHealth(bytes32 poolId) internal {
        Pool memory pool = pools[poolId];
        AIAnalytics storage analytics = poolAnalytics[poolId];
        
        // Calculate liquidity balance ratio
        uint256 ratio;
        if (pool.reserveA > pool.reserveB) {
            ratio = (pool.reserveB * 100) / pool.reserveA;
        } else {
            ratio = (pool.reserveA * 100) / pool.reserveB;
        }
        
        // Health score based on how balanced the pool is
        analytics.liquidityHealth = ratio > 50 ? 100 : ratio * 2;
    }
    
    /**
     * @dev Updates trading activity analytics
     */
    function updateTradingActivity(bytes32 poolId) internal {
        AIAnalytics storage analytics = poolAnalytics[poolId];
        uint256 recentSwaps = getRecentSwapCount(poolId);
        
        // Normalize activity score (0-100)
        analytics.tradingActivity = recentSwaps > 100 ? 100 : recentSwaps;
    }
    
    /**
     * @dev Updates volatility score based on recent price movements
     */
    function updateVolatilityScore(bytes32 poolId) internal {
        Pool memory pool = pools[poolId];
        AIAnalytics storage analytics = poolAnalytics[poolId];
        
        // Simple volatility calculation based on reserve ratio changes
        uint256 currentRatio = pool.reserveA * 1e18 / pool.reserveB;
        
        // In a real implementation, this would track historical ratios
        // For now, we'll use a simplified approach
        analytics.volatilityScore = 50; // Placeholder
    }
    
    /**
     * @dev Updates user trading score for rewards
     */
    function updateUserTradingScore(address user, uint256 volume) internal {
        userTradingScore[user] += volume;
        
        // Calculate rewards based on trading volume
        uint256 rewardAmount = volume / 1000; // 0.1% reward rate
        userRewards[user] += rewardAmount;
        
        emit UserRewardCalculated(user, rewardAmount);
    }
    
    /**
     * @dev Gets recent swap count for analytics
     */
    function getRecentSwapCount(bytes32 poolId) internal view returns (uint256) {
        SwapData[] memory swaps = swapHistory[poolId];
        uint256 count = 0;
        uint256 timeLimit = block.timestamp - 1 hours;
        
        for (uint256 i = swaps.length; i > 0; i--) {
            if (swaps[i-1].timestamp < timeLimit) break;
            count++;
        }
        
        return count;
    }
    
    /**
     * @dev Allows users to claim their trading rewards
     */
    function claimRewards() external {
        uint256 reward = userRewards[msg.sender];
        require(reward > 0, "No rewards available");
        
        userRewards[msg.sender] = 0;
        
        // In a real implementation, this would mint reward tokens
        // For now, we'll emit an event
        emit UserRewardCalculated(msg.sender, reward);
    }
    
    /**
     * @dev Gets comprehensive pool information
     */
    function getPoolInfo(bytes32 poolId) external view returns (
        address tokenA,
        address tokenB,
        uint256 reserveA,
        uint256 reserveB,
        uint256 totalLiquidity,
        uint256 volume24h,
        uint256 feesCollected,
        AIAnalytics memory analytics
    ) {
        Pool memory pool = pools[poolId];
        return (
            address(pool.tokenA),
            address(pool.tokenB),
            pool.reserveA,
            pool.reserveB,
            pool.totalLiquidity,
            pool.volume24h,
            pool.feesCollected,
            poolAnalytics[poolId]
        );
    }
    
    /**
     * @dev Gets user statistics
     */
    function getUserStats(address user) external view returns (
        uint256 tradingScore,
        uint256 availableRewards,
        uint256 totalLiquidityProvided
    ) {
        return (
            userTradingScore[user],
            userRewards[user],
            0 // This would require tracking across all pools
        );
    }
    
    // Utility functions
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }
    
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
