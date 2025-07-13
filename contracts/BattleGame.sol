// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BattleArenaP2E
 * @dev Advanced Play-to-Earn Battle Arena with Skill-Based Combat and Dynamic Economy
 * @notice Revolutionary P2E gaming with real skill requirements and balanced economy
 */
contract BattleArenaP2E is ReentrancyGuard, Ownable {
    IERC20 public rewardToken;
    IERC721 public characterNFT;
    
    struct Character {
        uint256 level;
        uint256 experience;
        uint256 health;
        uint256 maxHealth;
        uint256 attack;
        uint256 defense;
        uint256 speed;
        uint256 magic;
        uint256 lastBattle;
        uint256 winCount;
        uint256 lossCount;
        uint256 streak; // Current win streak
        uint256 maxStreak; // Best win streak
        CharacterClass class;
        uint256[] skillPoints; // Allocation of skill points
        uint256 prestigeLevel; // For max level characters
    }
    
    enum CharacterClass { WARRIOR, MAGE, ARCHER, ASSASSIN, HEALER }
    
    struct Battle {
        uint256 attacker;
        uint256 defender;
        address winner;
        uint256 timestamp;
        uint256 rewardAmount;
        BattleType battleType;
        uint256 spectators; // Number of spectators
        uint256 spectatorRewards; // Rewards distributed to spectators
    }
    
    enum BattleType { CASUAL, RANKED, TOURNAMENT, GUILD_WAR }
    
    struct Tournament {
        uint256 id;
        string name;
        uint256 entryFee;
        uint256 prizePool;
        uint256 startTime;
        uint256 endTime;
        uint256[] participants;
        mapping(uint256 => bool) isParticipant;
        uint256 winner;
        bool completed;
        TournamentType tournamentType;
    }
    
    enum TournamentType { SINGLE_ELIMINATION, ROUND_ROBIN, BATTLE_ROYALE }
    
    struct Guild {
        string name;
        address leader;
        uint256[] members;
        uint256 guildRating;
        uint256 totalWins;
        uint256 totalLosses;
        uint256 treasury;
        bool isActive;
    }
    
    struct SeasonStats {
        uint256 seasonId;
        uint256 startTime;
        uint256 endTime;
        mapping(uint256 => uint256) characterRatings;
        mapping(address => uint256) playerRewards;
        uint256[] topCharacters;
        bool active;
    }
    
    // Game State
    mapping(uint256 => Character) public characters;
    mapping(address => uint256[]) public playerCharacters;
    mapping(address => uint256) public playerEarnings;
    mapping(address => uint256) public playerRank;
    mapping(uint256 => uint256) public characterRating; // ELO-style rating
    
    Battle[] public battles;
    mapping(uint256 => Tournament) public tournaments;
    mapping(uint256 => Guild) public guilds;
    mapping(address => uint256) public playerGuild;
    mapping(uint256 => SeasonStats) public seasons;
    
    // Economic Parameters
    uint256 public constant BATTLE_COOLDOWN = 30 minutes;
    uint256 public constant BASE_REWARD = 10 * 1e18;
    uint256 public constant SPECTATOR_REWARD_PERCENTAGE = 5; // 5% of battle rewards go to spectators
    uint256 public constant GUILD_TAX_PERCENTAGE = 2; // 2% goes to guild treasury
    uint256 public constant TOURNAMENT_FEE_PERCENTAGE = 10; // 10% platform fee
    
    // Game Balance
    uint256 public rewardMultiplier = 100; // Can be adjusted for economy balance
    uint256 public experienceMultiplier = 100;
    uint256 public currentSeason = 1;
    uint256 public tournamentCount = 0;
    uint256 public guildCount = 0;
    
    // Battle Mechanics
    mapping(uint256 => mapping(uint256 => bool)) public hasRecentlyFought; // Prevent farming same opponent
    mapping(uint256 => uint256) public lastFightTime;
    mapping(address => bool) public spectators; // Players watching battles
    mapping(uint256 => address[]) public battleSpectators; // Spectators for specific battles
    
    event BattleCompleted(
        uint256 indexed attacker, 
        uint256 indexed defender, 
        address indexed winner, 
        uint256 rewardAmount,
        BattleType battleType
    );
    event CharacterLevelUp(uint256 indexed tokenId, uint256 newLevel);
    event CharacterPrestige(uint256 indexed tokenId, uint256 prestigeLevel);
    event RewardClaimed(address indexed player, uint256 amount);
    event TournamentCreated(uint256 indexed tournamentId, string name, uint256 prizePool);
    event TournamentCompleted(uint256 indexed tournamentId, uint256 winner, uint256 prize);
    event GuildCreated(uint256 indexed guildId, string name, address leader);
    event GuildJoined(address indexed player, uint256 indexed guildId);
    event SeasonStarted(uint256 indexed seasonId, uint256 startTime);
    event SeasonEnded(uint256 indexed seasonId, uint256[] topCharacters);
    event SpectatorReward(address indexed spectator, uint256 amount);
    event RatingUpdated(uint256 indexed characterId, uint256 oldRating, uint256 newRating);
    
    constructor(address _rewardToken, address _characterNFT) {
        rewardToken = IERC20(_rewardToken);
        characterNFT = IERC721(_characterNFT);
        
        // Initialize first season
        seasons[currentSeason].seasonId = currentSeason;
        seasons[currentSeason].startTime = block.timestamp;
        seasons[currentSeason].endTime = block.timestamp + 90 days; // 3 months
        seasons[currentSeason].active = true;
    }
    
    /**
     * @dev Initialize a new character or get existing stats
     */
    function initializeCharacter(uint256 tokenId, CharacterClass class) external {
        require(characterNFT.ownerOf(tokenId) == msg.sender, "Not your character");
        
        if (characters[tokenId].maxHealth == 0) {
            // New character initialization
            characters[tokenId] = Character({
                level: 1,
                experience: 0,
                health: 100,
                maxHealth: 100,
                attack: getClassBaseStats(class, 0), // attack
                defense: getClassBaseStats(class, 1), // defense
                speed: getClassBaseStats(class, 2), // speed
                magic: getClassBaseStats(class, 3), // magic
                lastBattle: 0,
                winCount: 0,
                lossCount: 0,
                streak: 0,
                maxStreak: 0,
                class: class,
                skillPoints: new uint256[](4), // [attack, defense, speed, magic]
                prestigeLevel: 0
            });
            
            characterRating[tokenId] = 1000; // Starting ELO rating
            playerCharacters[msg.sender].push(tokenId);
        }
    }
    
    /**
     * @dev Start a battle between two characters
     */
    function startBattle(
        uint256 attackerId, 
        uint256 defenderId, 
        BattleType battleType
    ) external nonReentrant {
        require(characterNFT.ownerOf(attackerId) == msg.sender, "Not your character");
        require(attackerId != defenderId, "Cannot battle yourself");
        require(
            block.timestamp >= characters[attackerId].lastBattle + BATTLE_COOLDOWN,
            "Character in cooldown"
        );
        require(
            !hasRecentlyFought[attackerId][defenderId] || 
            block.timestamp >= lastFightTime[attackerId] + 2 hours,
            "Recently fought this opponent"
        );
        
        Character storage attacker = characters[attackerId];
        Character storage defender = characters[defenderId];
        
        require(attacker.maxHealth > 0 && defender.maxHealth > 0, "Characters not initialized");
        require(attacker.health > 0, "Attacker needs healing");
        
        // Calculate battle outcome using skill-based system
        (bool attackerWins, uint256 damageDealt, uint256 damageReceived) = 
            calculateSkillBasedBattle(attackerId, defenderId);
        
        // Apply damage
        if (attackerWins) {
            if (defender.health > damageReceived) {
                defender.health -= damageReceived;
            } else {
                defender.health = 0;
            }
        } else {
            if (attacker.health > damageDealt) {
                attacker.health -= damageDealt;
            } else {
                attacker.health = 0;
            }
        }
        
        address winner;
        uint256 rewardAmount = calculateReward(attackerId, defenderId, battleType);
        
        attacker.lastBattle = block.timestamp;
        hasRecentlyFought[attackerId][defenderId] = true;
        lastFightTime[attackerId] = block.timestamp;
        
        if (attackerWins) {
            winner = msg.sender;
            attacker.winCount++;
            attacker.experience += calculateExperienceGain(attackerId, defenderId, true);
            attacker.streak++;
            
            defender.lossCount++;
            defender.experience += calculateExperienceGain(defenderId, attackerId, false);
            defender.streak = 0;
            
            // Update max streak
            if (attacker.streak > attacker.maxStreak) {
                attacker.maxStreak = attacker.streak;
            }
            
            // Distribute rewards
            distributeRewards(msg.sender, rewardAmount, battleType);
            
        } else {
            winner = characterNFT.ownerOf(defenderId);
            attacker.lossCount++;
            attacker.experience += calculateExperienceGain(attackerId, defenderId, false);
            attacker.streak = 0;
            
            defender.winCount++;
            defender.experience += calculateExperienceGain(defenderId, attackerId, true);
            if (defender.streak == 0) defender.streak = 1;
            else defender.streak++;
            
            if (defender.streak > defender.maxStreak) {
                defender.maxStreak = defender.streak;
            }
            
            // Distribute rewards to defender
            distributeRewards(winner, rewardAmount / 2, battleType); // Defender gets less
        }
        
        // Update ELO ratings
        updateRatings(attackerId, defenderId, attackerWins);
        
        // Level up checks
        checkLevelUp(attackerId);
        checkLevelUp(defenderId);
        
        // Record battle
        battles.push(Battle({
            attacker: attackerId,
            defender: defenderId,
            winner: winner,
            timestamp: block.timestamp,
            rewardAmount: rewardAmount,
            battleType: battleType,
            spectators: battleSpectators[battles.length].length,
            spectatorRewards: 0
        }));
        
        // Distribute spectator rewards
        distributeSpectatorRewards(battles.length - 1, rewardAmount);
        
        emit BattleCompleted(attackerId, defenderId, winner, rewardAmount, battleType);
    }
    
    /**
     * @dev Advanced skill-based battle calculation
     */
    function calculateSkillBasedBattle(
        uint256 attackerId, 
        uint256 defenderId
    ) internal view returns (bool attackerWins, uint256 damageDealt, uint256 damageReceived) {
        Character memory attacker = characters[attackerId];
        Character memory defender = characters[defenderId];
        
        // Calculate effective stats with class bonuses and skill points
        uint256 attackPower = attacker.attack + attacker.skillPoints[0] * 2;
        uint256 defensePower = defender.defense + defender.skillPoints[1] * 2;
        uint256 attackSpeed = attacker.speed + attacker.skillPoints[2] * 2;
        uint256 defenseSpeed = defender.speed + defender.skillPoints[2] * 2;
        uint256 attackMagic = attacker.magic + attacker.skillPoints[3] * 2;
        uint256 defenseMagic = defender.magic + defender.skillPoints[3] * 2;
        
        // Apply class bonuses
        (attackPower, attackMagic) = applyClassBonuses(attacker.class, attackPower, attackMagic);
        (defensePower, defenseMagic) = applyClassBonuses(defender.class, defensePower, defenseMagic);
        
        // Speed determines first strike advantage
        bool attackerFirst = attackSpeed >= defenseSpeed;
        
        // Calculate damage with defense mitigation
        uint256 physicalDamage = attackPower > defensePower ? 
            (attackPower - defensePower / 2) : attackPower / 3;
        uint256 magicalDamage = attackMagic > defenseMagic ? 
            (attackMagic - defenseMagic / 2) : attackMagic / 3;
        
        damageDealt = physicalDamage + magicalDamage;
        
        // Defender counter-attack
        uint256 counterPhysical = defensePower > attackPower / 2 ? 
            (defensePower - attackPower / 4) : defensePower / 3;
        uint256 counterMagical = defenseMagic > attackMagic / 2 ? 
            (defenseMagic - attackMagic / 4) : defenseMagic / 3;
        
        damageReceived = (counterPhysical + counterMagical) * 70 / 100; // Counter-attacks do 70% damage
        
        // First strike advantage
        if (attackerFirst) {
            damageDealt = damageDealt * 110 / 100; // 10% bonus for first strike
        } else {
            damageReceived = damageReceived * 110 / 100;
        }
        
        // Add controlled randomness (20% variance)
        uint256 randomness = uint256(keccak256(abi.encodePacked(
            block.timestamp, 
            attackerId, 
            defenderId,
            block.difficulty
        ))) % 41 + 80; // 80-120% multiplier
        
        damageDealt = damageDealt * randomness / 100;
        
        // Determine winner based on damage calculation
        attackerWins = damageDealt > damageReceived;
        
        // Cap damage to prevent one-shot kills
        if (damageDealt > defender.maxHealth * 60 / 100) {
            damageDealt = defender.maxHealth * 60 / 100;
        }
        if (damageReceived > attacker.maxHealth * 60 / 100) {
            damageReceived = attacker.maxHealth * 60 / 100;
        }
        
        return (attackerWins, damageDealt, damageReceived);
    }
    
    /**
     * @dev Apply class-specific bonuses
     */
    function applyClassBonuses(
        CharacterClass class, 
        uint256 attack, 
        uint256 magic
    ) internal pure returns (uint256 bonusAttack, uint256 bonusMagic) {
        if (class == CharacterClass.WARRIOR) {
            bonusAttack = attack * 130 / 100; // +30% attack
            bonusMagic = magic * 70 / 100;    // -30% magic
        } else if (class == CharacterClass.MAGE) {
            bonusAttack = attack * 70 / 100;  // -30% attack
            bonusMagic = magic * 150 / 100;   // +50% magic
        } else if (class == CharacterClass.ARCHER) {
            bonusAttack = attack * 120 / 100; // +20% attack
            bonusMagic = magic * 90 / 100;    // -10% magic
        } else if (class == CharacterClass.ASSASSIN) {
            bonusAttack = attack * 140 / 100; // +40% attack (glass cannon)
            bonusMagic = magic * 60 / 100;    // -40% magic
        } else { // HEALER
            bonusAttack = attack * 80 / 100;  // -20% attack
            bonusMagic = magic * 140 / 100;   // +40% magic
        }
        
        return (bonusAttack, bonusMagic);
    }
    
    /**
     * @dev Get base stats for character class
     */
    function getClassBaseStats(CharacterClass class, uint256 statIndex) 
        internal pure returns (uint256) {
        
        // statIndex: 0=attack, 1=defense, 2=speed, 3=magic
        if (class == CharacterClass.WARRIOR) {
            uint256[4] memory stats = [uint256(25), 20, 15, 10]; // High attack, defense
            return stats[statIndex];
        } else if (class == CharacterClass.MAGE) {
            uint256[4] memory stats = [uint256(15), 15, 20, 30]; // High magic
            return stats[statIndex];
        } else if (class == CharacterClass.ARCHER) {
            uint256[4] memory stats = [uint256(22), 16, 25, 12]; // High speed, attack
            return stats[statIndex];
        } else if (class == CharacterClass.ASSASSIN) {
            uint256[4] memory stats = [uint256(28), 12, 30, 8]; // Very high attack, speed
            return stats[statIndex];
        } else { // HEALER
            uint256[4] memory stats = [uint256(12), 18, 18, 25]; // Balanced with high magic
            return stats[statIndex];
        }
    }
    
    /**
     * @dev Calculate dynamic reward based on multiple factors
     */
    function calculateReward(
        uint256 attackerId, 
        uint256 defenderId, 
        BattleType battleType
    ) internal view returns (uint256) {
        Character memory attacker = characters[attackerId];
        Character memory defender = characters[defenderId];
        
        uint256 baseReward = BASE_REWARD * rewardMultiplier / 100;
        
        // Level difference bonus (fighting higher level = more reward)
        uint256 levelDiff = defender.level > attacker.level ? 
            defender.level - attacker.level : 0;
        uint256 levelBonus = levelDiff * 20; // 20% per level difference
        
        // Rating difference bonus
        uint256 attackerRating = characterRating[attackerId];
        uint256 defenderRating = characterRating[defenderId];
        uint256 ratingBonus = 0;
        
        if (defenderRating > attackerRating) {
            ratingBonus = ((defenderRating - attackerRating) * 50) / 100; // Up to 50% bonus
        }
        
        // Win streak bonus for defender
        uint256 streakBonus = defender.streak * 10; // 10% per win streak
        
        // Battle type multiplier
        uint256 typeMultiplier = 100;
        if (battleType == BattleType.RANKED) {
            typeMultiplier = 150; // 50% more for ranked
        } else if (battleType == BattleType.TOURNAMENT) {
            typeMultiplier = 200; // 100% more for tournament
        } else if (battleType == BattleType.GUILD_WAR) {
            typeMultiplier = 120; // 20% more for guild wars
        }
        
        // Prestige bonus
        uint256 prestigeBonus = (attacker.prestigeLevel + defender.prestigeLevel) * 25; // 25% per prestige level
        
        uint256 totalBonus = levelBonus + ratingBonus + streakBonus + prestigeBonus;
        uint256 finalReward = (baseReward * (100 + totalBonus) / 100) * typeMultiplier / 100;
        
        // Cap the reward to prevent inflation
        uint256 maxReward = BASE_REWARD * 10; // Max 10x base reward
        return finalReward > maxReward ? maxReward : finalReward;
    }
    
    /**
     * @dev Calculate experience gain from battle
     */
    function calculateExperienceGain(
        uint256 characterId, 
        uint256 opponentId, 
        bool won
    ) internal view returns (uint256) {
        Character memory character = characters[characterId];
        Character memory opponent = characters[opponentId];
        
        uint256 baseExp = 50 * experienceMultiplier / 100;
        
        if (won) {
            baseExp = baseExp * 2; // Winners get double experience
        }
        
        // Level difference bonus
        if (opponent.level > character.level) {
            uint256 levelDiff = opponent.level - character.level;
            baseExp += levelDiff * 25; // 25 exp per level difference
        }
        
        // Prestige bonus
        baseExp += opponent.prestigeLevel * 20;
        
        return baseExp;
    }
    
    /**
     * @dev Distribute rewards with guild tax and spectator rewards
     */
    function distributeRewards(address player, uint256 amount, BattleType battleType) internal {
        uint256 finalAmount = amount;
        
        // Guild tax
        if (playerGuild[player] != 0) {
            uint256 guildTax = amount * GUILD_TAX_PERCENTAGE / 100;
            guilds[playerGuild[player]].treasury += guildTax;
            finalAmount -= guildTax;
        }
        
        // Add to player earnings
        playerEarnings[player] += finalAmount;
        
        // Update season rewards
        if (seasons[currentSeason].active) {
            seasons[currentSeason].playerRewards[player] += finalAmount;
        }
    }
    
    /**
     * @dev Update ELO-style ratings for both characters
     */
    function updateRatings(uint256 attackerId, uint256 defenderId, bool attackerWon) internal {
        uint256 attackerRating = characterRating[attackerId];
        uint256 defenderRating = characterRating[defenderId];
        
        uint256 oldAttackerRating = attackerRating;
        uint256 oldDefenderRating = defenderRating;
        
        // Calculate expected scores (0.0 to 1.0, scaled to 0-100)
        uint256 expectedAttacker = calculateExpectedScore(attackerRating, defenderRating);
        uint256 expectedDefender = 100 - expectedAttacker;
        
        // Actual scores
        uint256 actualAttacker = attackerWon ? 100 : 0;
        uint256 actualDefender = attackerWon ? 0 : 100;
        
        // K-factor (rating sensitivity)
        uint256 kFactor = 32;
        
        // Calculate rating changes
        int256 attackerChange = int256(kFactor * (actualAttacker - expectedAttacker) / 100);
        int256 defenderChange = int256(kFactor * (actualDefender - expectedDefender) / 100);
        
        // Apply changes
        if (attackerChange >= 0) {
            attackerRating += uint256(attackerChange);
        } else {
            if (attackerRating > uint256(-attackerChange)) {
                attackerRating -= uint256(-attackerChange);
            } else {
                attackerRating = 100; // Minimum rating
            }
        }
        
        if (defenderChange >= 0) {
            defenderRating += uint256(defenderChange);
        } else {
            if (defenderRating > uint256(-defenderChange)) {
                defenderRating -= uint256(-defenderChange);
            } else {
                defenderRating = 100; // Minimum rating
            }
        }
        
        characterRating[attackerId] = attackerRating;
        characterRating[defenderId] = defenderRating;
        
        emit RatingUpdated(attackerId, oldAttackerRating, attackerRating);
        emit RatingUpdated(defenderId, oldDefenderRating, defenderRating);
    }
    
    /**
     * @dev Calculate expected score for ELO rating
     */
    function calculateExpectedScore(uint256 ratingA, uint256 ratingB) 
        internal pure returns (uint256) {
        
        if (ratingA == ratingB) return 50; // 50% if equal
        
        // Simplified ELO calculation
        if (ratingA > ratingB) {
            uint256 diff = ratingA - ratingB;
            if (diff >= 400) return 90; // 90% if 400+ rating difference
            return 50 + (diff * 40 / 400); // Linear interpolation
        } else {
            uint256 diff = ratingB - ratingA;
            if (diff >= 400) return 10; // 10% if opponent 400+ higher
            return 50 - (diff * 40 / 400); // Linear interpolation
        }
    }
    
    /**
     * @dev Check and handle level up
     */
    function checkLevelUp(uint256 tokenId) internal {
        Character storage character = characters[tokenId];
        uint256 expRequired = character.level * 200 + (character.level * character.level * 10);
        
        while (character.experience >= expRequired && character.level < 100) {
            character.level++;
            character.experience -= expRequired;
            
            // Stat increases on level up
            character.maxHealth += 10;
            character.health = character.maxHealth; // Full heal on level up
            character.attack += 2;
            character.defense += 2;
            character.speed += 1;
            character.magic += 1;
            
            // Give skill points to allocate
            character.skillPoints[0] += 1; // Extra skill point to allocate
            
            emit CharacterLevelUp(tokenId, character.level);
            
            // Check for prestige at level 100
            if (character.level == 100) {
                character.prestigeLevel++;
                character.level = 1; // Reset to level 1
                character.experience = 0;
                
                // Prestige bonuses
                character.maxHealth += 50;
                character.attack += 10;
                character.defense += 10;
                character.speed += 5;
                character.magic += 5;
                
                emit CharacterPrestige(tokenId, character.prestigeLevel);
            }
            
            expRequired = character.level * 200 + (character.level * character.level * 10);
        }
    }
    
    /**
     * @dev Allocate skill points to character stats
     */
    function allocateSkillPoints(
        uint256 tokenId, 
        uint256 attackPoints, 
        uint256 defensePoints, 
        uint256 speedPoints, 
        uint256 magicPoints
    ) external {
        require(characterNFT.ownerOf(tokenId) == msg.sender, "Not your character");
        
        Character storage character = characters[tokenId];
        uint256 totalPoints = attackPoints + defensePoints + speedPoints + magicPoints;
        
        require(character.skillPoints[0] >= totalPoints, "Not enough skill points");
        
        character.skillPoints[0] -= totalPoints; // Reduce available points
        character.attack += attackPoints;
        character.defense += defensePoints;
        character.speed += speedPoints;
        character.magic += magicPoints;
    }
    
    /**
     * @dev Heal character (costs tokens)
     */
    function healCharacter(uint256 tokenId) external {
        require(characterNFT.ownerOf(tokenId) == msg.sender, "Not your character");
        
        Character storage character = characters[tokenId];
        require(character.health < character.maxHealth, "Already at full health");
        
        uint256 healCost = BASE_REWARD / 4; // 25% of base reward
        require(playerEarnings[msg.sender] >= healCost, "Insufficient funds");
        
        playerEarnings[msg.sender] -= healCost;
        character.health = character.maxHealth;
    }
    
    /**
     * @dev Join as spectator for upcoming battles
     */
    function joinAsSpectator() external {
        spectators[msg.sender] = true;
    }
    
    /**
     * @dev Leave spectator mode
     */
    function leaveSpectatorMode() external {
        spectators[msg.sender] = false;
    }
    
    /**
     * @dev Distribute rewards to spectators
     */
    function distributeSpectatorRewards(uint256 battleId, uint256 totalReward) internal {
        uint256 spectatorPool = totalReward * SPECTATOR_REWARD_PERCENTAGE / 100;
        address[] memory battleSpecs = battleSpectators[battleId];
        
        if (battleSpecs.length > 0 && spectatorPool > 0) {
            uint256 rewardPerSpectator = spectatorPool / battleSpecs.length;
            
            for (uint256 i = 0; i < battleSpecs.length; i++) {
                playerEarnings[battleSpecs[i]] += rewardPerSpectator;
                emit SpectatorReward(battleSpecs[i], rewardPerSpectator);
            }
            
            battles[battleId].spectatorRewards = spectatorPool;
        }
    }
    
    /**
     * @dev Create a new tournament
     */
    function createTournament(
        string memory name,
        uint256 entryFee,
        uint256 startTime,
        TournamentType tournamentType
    ) external onlyOwner returns (uint256) {
        require(startTime > block.timestamp, "Start time must be in future");
        
        tournamentCount++;
        uint256 tournamentId = tournamentCount;
        
        Tournament storage tournament = tournaments[tournamentId];
        tournament.id = tournamentId;
        tournament.name = name;
        tournament.entryFee = entryFee;
        tournament.prizePool = 0;
        tournament.startTime = startTime;
        tournament.endTime = startTime + 1 days; // 24 hour tournament
        tournament.winner = 0;
        tournament.completed = false;
        tournament.tournamentType = tournamentType;
        
        emit TournamentCreated(tournamentId, name, 0);
        return tournamentId;
    }
    
    /**
     * @dev Create a guild
     */
    function createGuild(string memory name) external returns (uint256) {
        require(playerGuild[msg.sender] == 0, "Already in a guild");
        
        guildCount++;
        uint256 guildId = guildCount;
        
        Guild storage guild = guilds[guildId];
        guild.name = name;
        guild.leader = msg.sender;
        guild.guildRating = 1000;
        guild.totalWins = 0;
        guild.totalLosses = 0;
        guild.treasury = 0;
        guild.isActive = true;
        
        playerGuild[msg.sender] = guildId;
        guild.members.push(0); // Placeholder for leader's character
        
        emit GuildCreated(guildId, name, msg.sender);
        return guildId;
    }
    
    /**
     * @dev Join a guild
     */
    function joinGuild(uint256 guildId) external {
        require(playerGuild[msg.sender] == 0, "Already in a guild");
        require(guilds[guildId].isActive, "Guild not active");
        require(guilds[guildId].members.length < 50, "Guild is full");
        
        playerGuild[msg.sender] = guildId;
        guilds[guildId].members.push(0); // Placeholder
        
        emit GuildJoined(msg.sender, guildId);
    }
    
    /**
     * @dev Claim accumulated rewards
     */
    function claimRewards() external nonReentrant {
        uint256 amount = playerEarnings[msg.sender];
        require(amount > 0, "No rewards to claim");
        
        playerEarnings[msg.sender] = 0;
        rewardToken.transfer(msg.sender, amount);
        
        emit RewardClaimed(msg.sender, amount);
    }
    
    /**
     * @dev Get comprehensive character stats
     */
    function getCharacterStats(uint256 tokenId) external view returns (
        Character memory character,
        uint256 rating,
        uint256 winRate,
        uint256 totalBattles
    ) {
        character = characters[tokenId];
        rating = characterRating[tokenId];
        totalBattles = character.winCount + character.lossCount;
        winRate = totalBattles > 0 ? (character.winCount * 100) / totalBattles : 0;
        
        return (character, rating, winRate, totalBattles);
    }
    
    /**
     * @dev Get player statistics
     */
    function getPlayerStats(address player) external view returns (
        uint256 totalEarnings,
        uint256 charactersOwned,
        uint256 rank,
        uint256 guildId,
        uint256 seasonRewards
    ) {
        totalEarnings = playerEarnings[player];
        charactersOwned = playerCharacters[player].length;
        rank = playerRank[player];
        guildId = playerGuild[player];
        seasonRewards = seasons[currentSeason].playerRewards[player];
        
        return (totalEarnings, charactersOwned, rank, guildId, seasonRewards);
    }
    
    /**
     * @dev Get battle history for a character
     */
    function getCharacterBattleHistory(uint256 tokenId, uint256 limit) 
        external view returns (Battle[] memory recentBattles) {
        
        uint256 count = 0;
        uint256 totalBattles = battles.length;
        
        // Count relevant battles
        for (uint256 i = totalBattles; i > 0 && count < limit; i--) {
            if (battles[i-1].attacker == tokenId || battles[i-1].defender == tokenId) {
                count++;
            }
        }
        
        // Create array and populate
        recentBattles = new Battle[](count);
        uint256 index = 0;
        
        for (uint256 i = totalBattles; i > 0 && index < count; i--) {
            if (battles[i-1].attacker == tokenId || battles[i-1].defender == tokenId) {
                recentBattles[index] = battles[i-1];
                index++;
            }
        }
        
        return recentBattles;
    }
    
    /**
     * @dev Get guild information
     */
    function getGuildInfo(uint256 guildId) external view returns (
        Guild memory guild,
        uint256 memberCount,
        uint256 winRate
    ) {
        guild = guilds[guildId];
        memberCount = guild.members.length;
        
        uint256 totalBattles = guild.totalWins + guild.totalLosses;
        winRate = totalBattles > 0 ? (guild.totalWins * 100) / totalBattles : 0;
        
        return (guild, memberCount, winRate);
    }
    
    /**
     * @dev Start new season (only owner)
     */
    function startNewSeason() external onlyOwner {
        require(seasons[currentSeason].active, "No active season to end");
        require(
            block.timestamp >= seasons[currentSeason].endTime, 
            "Current season not ended"
        );
        
        // End current season
        seasons[currentSeason].active = false;
        emit SeasonEnded(currentSeason, seasons[currentSeason].topCharacters);
        
        // Start new season
        currentSeason++;
        seasons[currentSeason].seasonId = currentSeason;
        seasons[currentSeason].startTime = block.timestamp;
        seasons[currentSeason].endTime = block.timestamp + 90 days;
        seasons[currentSeason].active = true;
        
        emit SeasonStarted(currentSeason, block.timestamp);
    }
    
    /**
     * @dev Update game economy parameters (only owner)
     */
    function updateGameParameters(
        uint256 _rewardMultiplier,
        uint256 _experienceMultiplier
    ) external onlyOwner {
        require(_rewardMultiplier >= 50 && _rewardMultiplier <= 200, "Invalid reward multiplier");
        require(_experienceMultiplier >= 50 && _experienceMultiplier <= 200, "Invalid exp multiplier");
        
        rewardMultiplier = _rewardMultiplier;
        experienceMultiplier = _experienceMultiplier;
    }
    
    /**
     * @dev Emergency pause for battle system (only owner)
     */
    function pauseBattles() external onlyOwner {
        // Implementation would add a paused state
    }
    
    /**
     * @dev Get top rated characters for leaderboard
     */
    function getTopCharacters(uint256 limit) external view returns (
        uint256[] memory characterIds,
        uint256[] memory ratings
    ) {
        // This would require an off-chain sorting mechanism or 
        // a more complex on-chain implementation for gas efficiency
        // For now, returning empty arrays as placeholder
        characterIds = new uint256[](0);
        ratings = new uint256[](0);
        
        return (characterIds, ratings);
    }
}
