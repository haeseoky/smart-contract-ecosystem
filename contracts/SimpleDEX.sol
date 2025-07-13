// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SimpleDEX
 * @dev 간단한 DEX (Decentralized Exchange) 컨트랙트
 * 
 * 주요 기능:
 * - 토큰 스왑 (A 토큰 → B 토큰)
 * - 유동성 공급 (Liquidity Providing)
 * - 수수료 수익 분배
 * - AMM (Automated Market Maker) 모델
 * 
 * 실제 사용 예시:
 * - Uniswap V2/V3
 * - PancakeSwap
 * - SushiSwap
 */
contract SimpleDEX is Ownable, ReentrancyGuard {
    IERC20 public tokenA;
    IERC20 public tokenB;
    
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidity;
    
    uint256 public constant FEE_NUMERATOR = 3;    // 0.3% 수수료
    uint256 public constant FEE_DENOMINATOR = 1000;
    
    mapping(address => uint256) public liquidityBalance;
    
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event TokenSwapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    
    constructor(address _tokenA, address _tokenB) Ownable(msg.sender) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }
    
    /**
     * @dev 유동성 공급
     */
    function addLiquidity(uint256 amountA, uint256 amountB) external nonReentrant {
        require(amountA > 0 && amountB > 0, "Amounts must be greater than 0");
        
        // 토큰 전송
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);
        
        uint256 liquidity;
        
        if (totalLiquidity == 0) {
            // 최초 유동성 공급
            liquidity = sqrt(amountA * amountB);
        } else {
            // 기존 비율에 맞춰 유동성 계산
            uint256 liquidityA = (amountA * totalLiquidity) / reserveA;
            uint256 liquidityB = (amountB * totalLiquidity) / reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
        }
        
        require(liquidity > 0, "Insufficient liquidity minted");
        
        liquidityBalance[msg.sender] += liquidity;
        totalLiquidity += liquidity;
        reserveA += amountA;
        reserveB += amountB;
        
        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }
    
    /**
     * @dev 유동성 제거
     */
    function removeLiquidity(uint256 liquidity) external nonReentrant {
        require(liquidity > 0, "Liquidity must be greater than 0");
        require(liquidityBalance[msg.sender] >= liquidity, "Insufficient liquidity balance");
        
        uint256 amountA = (liquidity * reserveA) / totalLiquidity;
        uint256 amountB = (liquidity * reserveB) / totalLiquidity;
        
        liquidityBalance[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;
        reserveA -= amountA;
        reserveB -= amountB;
        
        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);
        
        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }
    
    /**
     * @dev 토큰 A → 토큰 B 스왑
     */
    function swapAtoB(uint256 amountIn) external nonReentrant {
        require(amountIn > 0, "Amount must be greater than 0");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");
        
        uint256 amountOut = getAmountOut(amountIn, reserveA, reserveB);
        require(amountOut > 0, "Insufficient output amount");
        
        tokenA.transferFrom(msg.sender, address(this), amountIn);
        tokenB.transfer(msg.sender, amountOut);
        
        reserveA += amountIn;
        reserveB -= amountOut;
        
        emit TokenSwapped(msg.sender, address(tokenA), address(tokenB), amountIn, amountOut);
    }
    
    /**
     * @dev 토큰 B → 토큰 A 스왑
     */
    function swapBtoA(uint256 amountIn) external nonReentrant {
        require(amountIn > 0, "Amount must be greater than 0");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");
        
        uint256 amountOut = getAmountOut(amountIn, reserveB, reserveA);
        require(amountOut > 0, "Insufficient output amount");
        
        tokenB.transferFrom(msg.sender, address(this), amountIn);
        tokenA.transfer(msg.sender, amountOut);
        
        reserveB += amountIn;
        reserveA -= amountOut;
        
        emit TokenSwapped(msg.sender, address(tokenB), address(tokenA), amountIn, amountOut);
    }
    
    /**
     * @dev AMM 공식으로 출력 토큰 수량 계산 (x * y = k)
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) 
        public 
        pure 
        returns (uint256 amountOut) 
    {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        
        // 수수료 차감 후 계산
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_NUMERATOR);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        
        amountOut = numerator / denominator;
    }
    
    /**
     * @dev 현재 토큰 가격 조회 (A 기준)
     */
    function getPrice() external view returns (uint256 priceAinB, uint256 priceBinA) {
        require(reserveA > 0 && reserveB > 0, "No liquidity");
        
        priceAinB = (reserveB * 1e18) / reserveA;  // 1 토큰A = ? 토큰B
        priceBinA = (reserveA * 1e18) / reserveB;  // 1 토큰B = ? 토큰A
    }
    
    /**
     * @dev 유동성 공급자 수익률 계산
     */
    function calculateAPY() external view returns (uint256) {
        if (totalLiquidity == 0) return 0;
        
        // 24시간 거래량 기준 APY 추정 (실제로는 더 복잡한 계산 필요)
        uint256 dailyVolume = (reserveA + reserveB) / 10;  // 간단한 추정
        uint256 dailyFees = (dailyVolume * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 annualFees = dailyFees * 365;
        uint256 totalValue = reserveA + reserveB;
        
        return (annualFees * 10000) / totalValue;  // 백분율로 반환
    }
    
    /**
     * @dev 거래 수수료 및 통계
     */
    function getPoolStats() external view returns (
        uint256 _reserveA,
        uint256 _reserveB,
        uint256 _totalLiquidity,
        uint256 _feeRate
    ) {
        _reserveA = reserveA;
        _reserveB = reserveB;
        _totalLiquidity = totalLiquidity;
        _feeRate = (FEE_NUMERATOR * 100) / FEE_DENOMINATOR;  // 백분율
    }
    
    /**
     * @dev 사용자의 유동성 정보
     */
    function getUserLiquidityInfo(address user) external view returns (
        uint256 userLiquidity,
        uint256 userShareA,
        uint256 userShareB,
        uint256 sharePercentage
    ) {
        userLiquidity = liquidityBalance[user];
        
        if (totalLiquidity > 0) {
            userShareA = (userLiquidity * reserveA) / totalLiquidity;
            userShareB = (userLiquidity * reserveB) / totalLiquidity;
            sharePercentage = (userLiquidity * 10000) / totalLiquidity;  // 0.01% 단위
        }
    }
    
    /**
     * @dev 제곱근 계산 (Babylonian method)
     */
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
    
    /**
     * @dev 긴급 상황 시 유동성 전체 회수 (관리자만)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));
        
        if (balanceA > 0) tokenA.transfer(owner(), balanceA);
        if (balanceB > 0) tokenB.transfer(owner(), balanceB);
        
        reserveA = 0;
        reserveB = 0;
        totalLiquidity = 0;
    }
}
