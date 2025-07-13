// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title AIEnhancedDAO
 * @dev Advanced DAO with AI-assisted governance and smart proposal analysis
 * @notice This represents the next generation of decentralized governance
 */
contract AIEnhancedDAO is Ownable, ReentrancyGuard {
    IERC20 public governanceToken;
    
    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 deadline;
        bool executed;
        uint256 aiScore; // AI evaluation score (0-100)
        uint256 communityScore; // Community sentiment score
        ProposalType proposalType;
        ProposalStatus status;
        bytes executionData; // For on-chain execution
    }
    
    enum ProposalType { 
        FUNDING,      // Treasury funding requests
        UPGRADE,      // Protocol upgrades
        PARAMETER,    // Parameter changes
        EMERGENCY,    // Emergency actions
        PARTNERSHIP,  // Strategic partnerships
        TREASURY      // Treasury management
    }
    
    enum ProposalStatus {
        PENDING,      // Waiting for voting to start
        ACTIVE,       // Currently accepting votes
        SUCCEEDED,    // Passed and ready for execution
        DEFEATED,     // Failed to pass
        EXECUTED,     // Successfully executed
        EXPIRED       // Deadline passed without execution
    }
    
    enum VoteType { AGAINST, FOR, ABSTAIN }
    
    struct AIAnalysis {
        uint256 feasibilityScore;    // Technical feasibility (0-100)
        uint256 riskAssessment;      // Risk level (0-100)
        uint256 impactPrediction;    // Expected impact (0-100)
        uint256 costBenefit;         // Cost-benefit ratio (0-100)
        string[] keyInsights;        // AI-generated insights
        uint256 analysisTimestamp;
    }
    
    struct VoterProfile {
        uint256 totalVotesCast;
        uint256 successfulVotes;     // Votes on winning side
        uint256 reputationScore;     // Voter reputation (0-100)
        uint256 lastVoteTime;
        bool isExpert;               // Expert voter status
    }
    
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => VoteType)) public votes;
    mapping(uint256 => mapping(address => uint256)) public voteWeights;
    mapping(uint256 => AIAnalysis) public aiAnalyses;
    mapping(address => VoterProfile) public voterProfiles;
    
    // DAO Configuration
    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000 * 1e18; // 1000 tokens
    uint256 public quorumPercentage = 20; // 20% of total supply
    uint256 public proposalThreshold = 51; // 51% for normal proposals
    uint256 public emergencyThreshold = 67; // 67% for emergency proposals
    
    // AI Enhancement Features
    uint256 public aiAnalysisDelay = 2 hours; // Time for AI analysis
    mapping(uint256 => uint256) public requiredMajority; // Custom majority per proposal
    
    // Treasury Management
    address public treasury;
    uint256 public treasuryBalance;
    
    event ProposalCreated(
        uint256 indexed id, 
        address indexed proposer, 
        string title, 
        ProposalType proposalType
    );
    event VoteCast(
        uint256 indexed proposalId, 
        address indexed voter, 
        VoteType support, 
        uint256 weight,
        string reason
    );
    event ProposalExecuted(uint256 indexed id, bool success);
    event AIAnalysisCompleted(
        uint256 indexed proposalId, 
        uint256 aiScore, 
        uint256 feasibility,
        uint256 risk
    );
    event ProposalStatusChanged(uint256 indexed proposalId, ProposalStatus newStatus);
    event VoterReputationUpdated(address indexed voter, uint256 newReputation);
    event QuorumReached(uint256 indexed proposalId, uint256 totalVotes);
    
    modifier onlyGovernance() {
        require(msg.sender == address(this), "Only governance");
        _;
    }
    
    constructor(address _governanceToken, address _treasury) {
        governanceToken = IERC20(_governanceToken);
        treasury = _treasury;
        treasuryBalance = address(this).balance;
    }
    
    /**
     * @dev Submit a new proposal with AI analysis integration
     * @param title Proposal title
     * @param description Detailed description
     * @param proposalType Type of proposal
     * @param executionData Optional execution data for on-chain actions
     */
    function submitProposal(
        string memory title,
        string memory description,
        ProposalType proposalType,
        bytes memory executionData
    ) external returns (uint256) {
        require(
            governanceToken.balanceOf(msg.sender) >= MIN_PROPOSAL_THRESHOLD, 
            "Insufficient tokens to propose"
        );
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length >= 100, "Description too short");
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        // Determine voting period based on proposal type
        uint256 votingPeriod = VOTING_PERIOD;
        if (proposalType == ProposalType.EMERGENCY) {
            votingPeriod = 3 days; // Faster for emergencies
        } else if (proposalType == ProposalType.UPGRADE) {
            votingPeriod = 14 days; // Longer for major upgrades
        }
        
        // Create the proposal
        proposals[proposalId] = Proposal({
            id: proposalId,
            title: title,
            description: description,
            proposer: msg.sender,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            deadline: block.timestamp + aiAnalysisDelay + votingPeriod,
            executed: false,
            aiScore: 0, // Will be set by AI analysis
            communityScore: 50, // Default neutral score
            proposalType: proposalType,
            status: ProposalStatus.PENDING,
            executionData: executionData
        });
        
        // Initiate AI analysis (simulated)
        uint256 aiScore = simulateAIAnalysis(description, proposalType);
        aiAnalyses[proposalId] = AIAnalysis({
            feasibilityScore: aiScore,
            riskAssessment: calculateRiskScore(proposalType, executionData),
            impactPrediction: calculateImpactScore(proposalType),
            costBenefit: calculateCostBenefit(proposalType),
            keyInsights: new string[](0),
            analysisTimestamp: block.timestamp
        });
        
        proposals[proposalId].aiScore = aiScore;
        
        // Set required majority based on AI analysis and proposal type
        requiredMajority[proposalId] = calculateRequiredMajority(proposalType, aiScore);
        
        // Update proposal status to active after AI analysis
        proposals[proposalId].status = ProposalStatus.ACTIVE;
        
        emit ProposalCreated(proposalId, msg.sender, title, proposalType);
        emit AIAnalysisCompleted(
            proposalId, 
            aiScore, 
            aiAnalyses[proposalId].feasibilityScore,
            aiAnalyses[proposalId].riskAssessment
        );
        
        return proposalId;
    }
    
    /**
     * @dev Cast a vote on a proposal with weighted voting and reputation consideration
     * @param proposalId The proposal to vote on
     * @param support Vote type (FOR, AGAINST, ABSTAIN)
     * @param reason Optional reason for the vote
     */
    function vote(
        uint256 proposalId, 
        VoteType support, 
        string memory reason
    ) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.ACTIVE, "Proposal not active");
        require(block.timestamp <= proposal.deadline, "Voting period ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        
        uint256 votingPower = governanceToken.balanceOf(msg.sender);
        require(votingPower > 0, "No voting power");
        
        // Apply reputation weighting
        VoterProfile storage voter = voterProfiles[msg.sender];
        uint256 reputationMultiplier = 100 + voter.reputationScore / 4; // Max 25% bonus
        uint256 weightedVotingPower = (votingPower * reputationMultiplier) / 100;
        
        // Expert voters get additional weight for technical proposals
        if (voter.isExpert && 
            (proposal.proposalType == ProposalType.UPGRADE || 
             proposal.proposalType == ProposalType.PARAMETER)) {
            weightedVotingPower = (weightedVotingPower * 120) / 100; // 20% expert bonus
        }
        
        hasVoted[proposalId][msg.sender] = true;
        votes[proposalId][msg.sender] = support;
        voteWeights[proposalId][msg.sender] = weightedVotingPower;
        
        // Update vote tallies
        if (support == VoteType.FOR) {
            proposal.forVotes += weightedVotingPower;
        } else if (support == VoteType.AGAINST) {
            proposal.againstVotes += weightedVotingPower;
        } else {
            proposal.abstainVotes += weightedVotingPower;
        }
        
        // Update voter profile
        voter.totalVotesCast++;
        voter.lastVoteTime = block.timestamp;
        
        // Check if quorum is reached
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 totalSupply = governanceToken.totalSupply();
        uint256 quorumRequired = (totalSupply * quorumPercentage) / 100;
        
        if (totalVotes >= quorumRequired) {
            emit QuorumReached(proposalId, totalVotes);
        }
        
        emit VoteCast(proposalId, msg.sender, support, weightedVotingPower, reason);
    }
    
    /**
     * @dev Execute a proposal that has passed
     * @param proposalId The proposal to execute
     */
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.ACTIVE, "Proposal not active");
        require(block.timestamp > proposal.deadline, "Voting period not ended");
        require(!proposal.executed, "Already executed");
        
        // Check if proposal passed
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        require(totalVotes > 0, "No votes cast");
        
        uint256 supportPercentage = (proposal.forVotes * 100) / totalVotes;
        uint256 required = requiredMajority[proposalId];
        
        if (supportPercentage >= required) {
            proposal.status = ProposalStatus.SUCCEEDED;
            
            // Execute the proposal if it has execution data
            bool success = true;
            if (proposal.executionData.length > 0) {
                (success,) = address(this).call(proposal.executionData);
            }
            
            if (success) {
                proposal.executed = true;
                proposal.status = ProposalStatus.EXECUTED;
                
                // Update voter reputations based on outcome
                updateVoterReputations(proposalId, true);
            }
            
            emit ProposalExecuted(proposalId, success);
        } else {
            proposal.status = ProposalStatus.DEFEATED;
            updateVoterReputations(proposalId, false);
        }
        
        emit ProposalStatusChanged(proposalId, proposal.status);
    }
    
    /**
     * @dev Simulate AI analysis for a proposal
     */
    function simulateAIAnalysis(
        string memory description, 
        ProposalType proposalType
    ) internal pure returns (uint256) {
        uint256 score = 50; // Base score
        
        // Proposal type scoring
        if (proposalType == ProposalType.EMERGENCY) {
            score += 20; // Emergency proposals get urgency bonus
        } else if (proposalType == ProposalType.FUNDING) {
            score += 10; // Funding proposals are common and understood
        } else if (proposalType == ProposalType.UPGRADE) {
            score -= 10; // Upgrades are riskier
        }
        
        // Description quality analysis
        uint256 descLength = bytes(description).length;
        if (descLength > 1000) {
            score += 15; // Detailed descriptions score higher
        } else if (descLength < 200) {
            score -= 20; // Too short descriptions score lower
        }
        
        // Keyword analysis (simplified)
        if (containsKeyword(description, "security") || 
            containsKeyword(description, "audit")) {
            score += 10;
        }
        
        if (containsKeyword(description, "risk") || 
            containsKeyword(description, "danger")) {
            score -= 15;
        }
        
        return score > 100 ? 100 : (score < 0 ? 0 : score);
    }
    
    /**
     * @dev Calculate required majority based on proposal type and AI score
     */
    function calculateRequiredMajority(
        ProposalType proposalType, 
        uint256 aiScore
    ) internal view returns (uint256) {
        uint256 baseMajority = proposalThreshold;
        
        if (proposalType == ProposalType.EMERGENCY) {
            baseMajority = emergencyThreshold;
        } else if (proposalType == ProposalType.UPGRADE) {
            baseMajority = 60; // Higher threshold for upgrades
        }
        
        // Adjust based on AI score
        if (aiScore < 40) {
            baseMajority += 15; // Require higher majority for low-scored proposals
        } else if (aiScore > 80) {
            baseMajority -= 5; // Lower requirement for high-scored proposals
        }
        
        return baseMajority > 80 ? 80 : baseMajority; // Cap at 80%
    }
    
    /**
     * @dev Calculate risk score for a proposal
     */
    function calculateRiskScore(
        ProposalType proposalType, 
        bytes memory executionData
    ) internal pure returns (uint256) {
        uint256 riskScore = 30; // Base risk
        
        if (proposalType == ProposalType.EMERGENCY) {
            riskScore += 40;
        } else if (proposalType == ProposalType.UPGRADE) {
            riskScore += 30;
        } else if (proposalType == ProposalType.TREASURY) {
            riskScore += 20;
        }
        
        if (executionData.length > 0) {
            riskScore += 20; // On-chain execution adds risk
        }
        
        return riskScore > 100 ? 100 : riskScore;
    }
    
    /**
     * @dev Calculate impact score for a proposal
     */
    function calculateImpactScore(ProposalType proposalType) internal pure returns (uint256) {
        if (proposalType == ProposalType.UPGRADE) return 90;
        if (proposalType == ProposalType.EMERGENCY) return 85;
        if (proposalType == ProposalType.TREASURY) return 70;
        if (proposalType == ProposalType.PARAMETER) return 60;
        if (proposalType == ProposalType.FUNDING) return 50;
        if (proposalType == ProposalType.PARTNERSHIP) return 40;
        return 30;
    }
    
    /**
     * @dev Calculate cost-benefit ratio
     */
    function calculateCostBenefit(ProposalType proposalType) internal pure returns (uint256) {
        // Simplified cost-benefit analysis
        if (proposalType == ProposalType.FUNDING) return 40; // High cost, uncertain benefit
        if (proposalType == ProposalType.UPGRADE) return 80; // High benefit, manageable cost
        if (proposalType == ProposalType.PARAMETER) return 90; // Low cost, good benefit
        return 60; // Default
    }
    
    /**
     * @dev Update voter reputations based on proposal outcome
     */
    function updateVoterReputations(uint256 proposalId, bool proposalPassed) internal {
        // This is a simplified reputation update
        // In practice, this would iterate through voters more carefully
        emit VoterReputationUpdated(msg.sender, 75); // Placeholder
    }
    
    /**
     * @dev Set expert status for a voter (only governance can call)
     */
    function setExpertStatus(address voter, bool isExpert) external onlyGovernance {
        voterProfiles[voter].isExpert = isExpert;
    }
    
    /**
     * @dev Update DAO parameters (only governance can call)
     */
    function updateDAOParameters(
        uint256 _quorumPercentage,
        uint256 _proposalThreshold,
        uint256 _emergencyThreshold
    ) external onlyGovernance {
        require(_quorumPercentage <= 50, "Quorum too high");
        require(_proposalThreshold <= 80, "Threshold too high");
        require(_emergencyThreshold <= 90, "Emergency threshold too high");
        
        quorumPercentage = _quorumPercentage;
        proposalThreshold = _proposalThreshold;
        emergencyThreshold = _emergencyThreshold;
    }
    
    /**
     * @dev Get comprehensive proposal information
     */
    function getProposalInfo(uint256 proposalId) external view returns (
        Proposal memory proposal,
        AIAnalysis memory aiAnalysis,
        uint256 requiredMajorityPercent,
        uint256 currentSupport
    ) {
        proposal = proposals[proposalId];
        aiAnalysis = aiAnalyses[proposalId];
        requiredMajorityPercent = requiredMajority[proposalId];
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        currentSupport = totalVotes > 0 ? (proposal.forVotes * 100) / totalVotes : 0;
        
        return (proposal, aiAnalysis, requiredMajorityPercent, currentSupport);
    }
    
    /**
     * @dev Get voter statistics
     */
    function getVoterStats(address voter) external view returns (
        VoterProfile memory profile,
        uint256 votingPower,
        uint256 weightedPower
    ) {
        profile = voterProfiles[voter];
        votingPower = governanceToken.balanceOf(voter);
        
        uint256 reputationMultiplier = 100 + profile.reputationScore / 4;
        weightedPower = (votingPower * reputationMultiplier) / 100;
        
        return (profile, votingPower, weightedPower);
    }
    
    /**
     * @dev Get DAO statistics
     */
    function getDAOStats() external view returns (
        uint256 totalProposals,
        uint256 activeProposals,
        uint256 executedProposals,
        uint256 avgAIScore,
        uint256 totalTokenSupply,
        uint256 treasuryBalanceETH
    ) {
        totalProposals = proposalCount;
        
        uint256 active = 0;
        uint256 executed = 0;
        uint256 totalScore = 0;
        
        for (uint256 i = 1; i <= proposalCount; i++) {
            if (proposals[i].status == ProposalStatus.ACTIVE) {
                active++;
            }
            if (proposals[i].status == ProposalStatus.EXECUTED) {
                executed++;
            }
            totalScore += proposals[i].aiScore;
        }
        
        activeProposals = active;
        executedProposals = executed;
        avgAIScore = proposalCount > 0 ? totalScore / proposalCount : 0;
        totalTokenSupply = governanceToken.totalSupply();
        treasuryBalanceETH = address(this).balance;
        
        return (
            totalProposals,
            activeProposals, 
            executedProposals,
            avgAIScore,
            totalTokenSupply,
            treasuryBalanceETH
        );
    }
    
    // Utility functions
    function containsKeyword(string memory text, string memory keyword) 
        internal pure returns (bool) {
        bytes memory textBytes = bytes(text);
        bytes memory keywordBytes = bytes(keyword);
        
        if (keywordBytes.length > textBytes.length) return false;
        
        for (uint i = 0; i <= textBytes.length - keywordBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < keywordBytes.length; j++) {
                if (textBytes[i + j] != keywordBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
    
    // Treasury functions
    receive() external payable {
        treasuryBalance += msg.value;
    }
    
    function withdrawTreasury(uint256 amount, address payable recipient) 
        external onlyGovernance {
        require(amount <= address(this).balance, "Insufficient treasury");
        recipient.transfer(amount);
        treasuryBalance -= amount;
    }
}
