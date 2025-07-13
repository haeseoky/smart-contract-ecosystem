// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title DynamicPerformanceNFT
 * @dev 게임 성능에 따라 동적으로 변화하고 소유권이 이전되는 혁신적인 NFT
 * @notice 성능이 떨어지면 다른 플레이어에게 자동 이전되는 경쟁적 NFT 시스템
 */
contract DynamicPerformanceNFT is ERC721URIStorage, Ownable {
    uint256 private _tokenIds;
    address public gameOracle; // 게임 성능 데이터를 제공하는 오라클
    
    struct NFTStats {
        uint256 level;
        uint256 experience;
        uint256 lastBattle;
        address currentChampion;
        uint256 performanceScore;
        uint256 winStreak;
        string[] evolutionStages;
        uint256 lastPerformanceUpdate;
    }
    
    mapping(uint256 => NFTStats) public nftStats;
    mapping(address => uint256[]) public userNFTs;
    mapping(address => uint256) public playerPerformance;
    
    uint256 public constant PERFORMANCE_THRESHOLD = 80; // 80% 성능 유지 필요
    uint256 public constant BATTLE_COOLDOWN = 1 hours;
    
    event LevelUp(uint256 tokenId, uint256 newLevel);
    event ChampionshipWon(uint256 tokenId, address newChampion);
    event PerformanceTransfer(uint256 tokenId, address from, address to, uint256 newScore);
    event EvolutionStageReached(uint256 tokenId, string stage);
    
    modifier onlyOracle() {
        require(msg.sender == gameOracle, "Only oracle can call this");
        _;
    }
    
    constructor() ERC721("DynamicWarrior", "DWAR") {
        gameOracle = msg.sender; // 초기에는 컨트랙트 배포자가 오라클
    }
    
    /**
     * @dev 오라클 주소 설정
     * @param _oracle 새로운 오라클 주소
     */
    function setOracle(address _oracle) external onlyOwner {
        gameOracle = _oracle;
    }
    
    /**
     * @dev NFT 민팅 (초기 스탯 설정)
     * @param to 민팅받을 주소
     * @return 새로 생성된 토큰 ID
     */
    function mintWarrior(address to) external onlyOwner returns (uint256) {
        _tokenIds++;
        uint256 newTokenId = _tokenIds;
        
        _mint(to, newTokenId);
        userNFTs[to].push(newTokenId);
        
        // 초기 스탯 설정
        nftStats[newTokenId] = NFTStats({
            level: 1,
            experience: 0,
            lastBattle: block.timestamp,
            currentChampion: to,
            performanceScore: 100, // 초기 성능 100%
            winStreak: 0,
            evolutionStages: new string[](0),
            lastPerformanceUpdate: block.timestamp
        });
        
        // 초기 메타데이터 설정
        _setTokenURI(newTokenId, generateMetadata(newTokenId));
        
        return newTokenId;
    }
    
    /**
     * @dev 게임 성능 업데이트 (오라클에서 호출)
     * @param tokenId 업데이트할 NFT ID
     * @param newScore 새로운 성능 점수 (0-100)
     */
    function updatePerformance(uint256 tokenId, uint256 newScore) external onlyOracle {
        require(_exists(tokenId), "Token does not exist");
        require(newScore <= 100, "Score cannot exceed 100");
        
        NFTStats storage stats = nftStats[tokenId];
        address currentOwner = ownerOf(tokenId);
        uint256 previousScore = stats.performanceScore;
        
        stats.performanceScore = newScore;
        stats.lastPerformanceUpdate = block.timestamp;
        
        // 성능이 임계값 이하로 떨어지면 다른 플레이어에게 이전
        if (newScore < PERFORMANCE_THRESHOLD && previousScore >= PERFORMANCE_THRESHOLD) {
            address newOwner = findBestPerformer();
            if (newOwner != address(0) && newOwner != currentOwner) {
                _performanceTransfer(tokenId, currentOwner, newOwner, newScore);
            }
        }
        
        // 메타데이터 업데이트
        _setTokenURI(tokenId, generateMetadata(tokenId));
    }
    
    /**
     * @dev 배틀 시스템 (경험치 획득)
     * @param attackerId 공격자 NFT ID
     * @param defenderId 수비자 NFT ID
     */
    function battle(uint256 attackerId, uint256 defenderId) external {
        require(ownerOf(attackerId) == msg.sender, "Not your NFT");
        require(_exists(defenderId), "Defender NFT does not exist");
        require(attackerId != defenderId, "Cannot battle yourself");
        require(
            block.timestamp >= nftStats[attackerId].lastBattle + BATTLE_COOLDOWN, 
            "Cooldown active"
        );
        
        NFTStats storage attacker = nftStats[attackerId];
        NFTStats storage defender = nftStats[defenderId];
        
        // 배틀 결과 계산
        bool attackerWins = calculateBattleOutcome(attackerId, defenderId);
        
        attacker.lastBattle = block.timestamp;
        
        if (attackerWins) {
            // 승리: 경험치 및 연승 증가
            attacker.experience += 100;
            attacker.winStreak += 1;
            defender.winStreak = 0; // 수비자 연승 초기화
            
            // 레벨업 체크
            checkLevelUp(attackerId);
            
            // 성능 점수 향상
            if (attacker.performanceScore < 100) {
                attacker.performanceScore = 
                    attacker.performanceScore + 5 > 100 ? 
                    100 : attacker.performanceScore + 5;
            }
            
            // 챔피언 결정
            if (attacker.level > defender.level) {
                attacker.currentChampion = ownerOf(attackerId);
                emit ChampionshipWon(attackerId, ownerOf(attackerId));
            }
        } else {
            // 패배: 적은 경험치, 성능 하락
            attacker.experience += 25;
            attacker.winStreak = 0;
            
            if (attacker.performanceScore > 10) {
                attacker.performanceScore -= 10;
            }
        }
        
        // 메타데이터 업데이트
        _setTokenURI(attackerId, generateMetadata(attackerId));
        _setTokenURI(defenderId, generateMetadata(defenderId));
    }
    
    /**
     * @dev 배틀 결과 계산
     */
    function calculateBattleOutcome(uint256 attackerId, uint256 defenderId) 
        internal view returns (bool) {
        
        NFTStats memory attacker = nftStats[attackerId];
        NFTStats memory defender = nftStats[defenderId];
        
        // 공격력 = (레벨 * 10) + (성능점수 / 2) + 연승보너스
        uint256 attackPower = (attacker.level * 10) + 
                             (attacker.performanceScore / 2) + 
                             (attacker.winStreak * 5);
        
        uint256 defensePower = (defender.level * 10) + 
                              (defender.performanceScore / 2) + 
                              (defender.winStreak * 5);
        
        // 20% 랜덤 요소 추가
        uint256 randomBonus = uint256(keccak256(abi.encodePacked(
            block.timestamp, 
            attackerId, 
            defenderId,
            block.difficulty
        ))) % 21; // 0-20%
        
        attackPower += (attackPower * randomBonus) / 100;
        
        return attackPower > defensePower;
    }
    
    /**
     * @dev 레벨업 체크 및 진화 단계 관리
     */
    function checkLevelUp(uint256 tokenId) internal {
        NFTStats storage stats = nftStats[tokenId];
        uint256 requiredExp = stats.level * 200;
        
        if (stats.experience >= requiredExp) {
            stats.level++;
            stats.experience = 0;
            
            // 진화 단계 추가
            if (stats.level == 5) {
                stats.evolutionStages.push("Warrior");
                emit EvolutionStageReached(tokenId, "Warrior");
            } else if (stats.level == 10) {
                stats.evolutionStages.push("Champion");
                emit EvolutionStageReached(tokenId, "Champion");
            } else if (stats.level == 20) {
                stats.evolutionStages.push("Legend");
                emit EvolutionStageReached(tokenId, "Legend");
            } else if (stats.level == 50) {
                stats.evolutionStages.push("Mythic");
                emit EvolutionStageReached(tokenId, "Mythic");
            }
            
            emit LevelUp(tokenId, stats.level);
        }
    }
    
    /**
     * @dev 최고 성능 플레이어 찾기
     */
    function findBestPerformer() internal view returns (address) {
        // 간단한 구현: 가장 최근에 기록된 높은 성능 플레이어
        // 실제로는 더 복잡한 알고리즘 사용
        address bestPlayer = address(0);
        uint256 bestScore = 0;
        
        for (uint256 i = 1; i <= _tokenIds; i++) {
            if (_exists(i)) {
                address owner = ownerOf(i);
                if (playerPerformance[owner] > bestScore) {
                    bestScore = playerPerformance[owner];
                    bestPlayer = owner;
                }
            }
        }
        
        return bestPlayer;
    }
    
    /**
     * @dev 성능 기반 소유권 이전
     */
    function _performanceTransfer(
        uint256 tokenId, 
        address from, 
        address to, 
        uint256 newScore
    ) internal {
        // 기존 소유자 NFT 목록에서 제거
        uint256[] storage fromNFTs = userNFTs[from];
        for (uint256 i = 0; i < fromNFTs.length; i++) {
            if (fromNFTs[i] == tokenId) {
                fromNFTs[i] = fromNFTs[fromNFTs.length - 1];
                fromNFTs.pop();
                break;
            }
        }
        
        // 새 소유자에게 추가
        userNFTs[to].push(tokenId);
        
        // NFT 이전
        _transfer(from, to, tokenId);
        
        emit PerformanceTransfer(tokenId, from, to, newScore);
    }
    
    /**
     * @dev 플레이어 성능 업데이트 (오라클용)
     */
    function updatePlayerPerformance(address player, uint256 score) external onlyOracle {
        playerPerformance[player] = score;
    }
    
    /**
     * @dev 동적 메타데이터 생성
     */
    function generateMetadata(uint256 tokenId) internal view returns (string memory) {
        NFTStats memory stats = nftStats[tokenId];
        
        string memory evolutionString = "";
        for (uint256 i = 0; i < stats.evolutionStages.length; i++) {
            evolutionString = string(abi.encodePacked(
                evolutionString, 
                stats.evolutionStages[i],
                i < stats.evolutionStages.length - 1 ? "," : ""
            ));
        }
        
        return string(abi.encodePacked(
            '{"name":"Dynamic Warrior #', 
            Strings.toString(tokenId),
            '","level":', 
            Strings.toString(stats.level),
            ',"experience":', 
            Strings.toString(stats.experience),
            ',"performance":', 
            Strings.toString(stats.performanceScore),
            ',"winStreak":', 
            Strings.toString(stats.winStreak),
            ',"evolutionStages":"[', 
            evolutionString,
            ']","image":"https://api.warrior-nft.com/image/', 
            Strings.toString(stats.level),
            '/',
            Strings.toString(stats.performanceScore),
            '.png"}'
        ));
    }
    
    /**
     * @dev NFT 통계 조회
     */
    function getNFTStats(uint256 tokenId) external view returns (
        uint256 level,
        uint256 experience,
        uint256 performanceScore,
        uint256 winStreak,
        string[] memory evolutionStages
    ) {
        NFTStats memory stats = nftStats[tokenId];
        return (
            stats.level,
            stats.experience,
            stats.performanceScore,
            stats.winStreak,
            stats.evolutionStages
        );
    }
}
