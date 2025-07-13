// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title IntelligentMultiSig
 * @dev AI-Enhanced Multi-Signature Wallet with Dynamic Security Features
 * @notice Advanced security with AI risk analysis and adaptive confirmation requirements
 */
contract IntelligentMultiSig is ReentrancyGuard {
    using ECDSA for bytes32;
    
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        uint256 riskScore; // AI-calculated risk score (0-100)
        uint256 timelock; // Execution delay timestamp
        uint256 submissionTime;
        address submitter;
        TransactionType txType;
    }
    
    struct Owner {
        address addr;
        bool isActive;
        uint256 reputation; // Trust score (0-100)
        uint256 lastActivity;
        string name; // Optional human-readable name
        bool isEmergencyContact; // Can execute emergency transactions
    }
    
    enum TransactionType {
        NORMAL,
        HIGH_VALUE,
        CONTRACT_INTERACTION,
        EMERGENCY,
        GOVERNANCE,
        RECOVERY
    }
    
    struct SecurityPolicy {
        uint256 dailyLimit;
        uint256 monthlyLimit;
        uint256 emergencyDelay;
        uint256 highValueThreshold;
        bool emergencyMode;
        uint256 emergencyActivatedAt;
    }
    
    struct AIRiskFactors {
        uint256 amountRisk; // Risk based on transaction amount
        uint256 recipientRisk; // Risk based on recipient address
        uint256 dataComplexity; // Risk based on transaction data
        uint256 timeRisk; // Risk based on timing
        uint256 frequencyRisk; // Risk based on transaction frequency
    }
    
    Owner[] public owners;
    mapping(address => bool) public isOwner;
    mapping(address => uint256) public ownerIndex;
    mapping(uint256 => mapping(address => bool)) public confirmations;
    mapping(uint256 => mapping(address => uint256)) public confirmationTimestamps;
    
    Transaction[] public transactions;
    uint256 public required; // Base required confirmations
    
    // AI Risk Management
    mapping(uint256 => uint256) public requiredConfirmations; // Dynamic per transaction
    mapping(address => uint256) public suspiciousActivity; // Tracks suspicious addresses
    mapping(address => uint256) public dailySpent; // Daily spending tracking
    mapping(address => uint256) public monthlySpent; // Monthly spending tracking
    mapping(uint256 => uint256) public lastResetDay;
    mapping(uint256 => uint256) public lastResetMonth;
    
    SecurityPolicy public securityPolicy;
    
    // Emergency Features
    mapping(address => bool) public emergencyContacts;
    mapping(uint256 => bool) public emergencyTransactions;
    uint256 public emergencyCount;
    
    // Social Recovery
    mapping(address => address[]) public recoveryGuardians;
    mapping(address => mapping(address => bool)) public recoveryApprovals;
    mapping(address => uint256) public recoveryRequestTime;
    uint256 public constant RECOVERY_PERIOD = 7 days;
    
    event OwnerAdded(address indexed owner, string name);
    event OwnerRemoved(address indexed owner);
    event RequiredChanged(uint256 required);
    event TransactionSubmitted(
        uint256 indexed txId, 
        address indexed submitter, 
        address indexed to, 
        uint256 value,
        TransactionType txType
    );
    event TransactionConfirmed(uint256 indexed txId, address indexed owner);
    event TransactionExecuted(uint256 indexed txId, bool success);
    event RiskAnalysisCompleted(
        uint256 indexed txId, 
        uint256 riskScore, 
        uint256 requiredConfirmations
    );
    event SecurityPolicyUpdated(uint256 dailyLimit, uint256 monthlyLimit);
    event EmergencyModeActivated(address indexed activator);
    event EmergencyModeDeactivated(address indexed deactivator);
    event SuspiciousActivityDetected(address indexed target, uint256 riskLevel);
    event OwnerReputationUpdated(address indexed owner, uint256 newReputation);
    event RecoveryRequested(address indexed owner, address[] guardians);
    event RecoveryExecuted(address indexed oldOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }
    
    modifier onlyWallet() {
        require(msg.sender == address(this), "Only wallet can call");
        _;
    }
    
    modifier notInEmergencyMode() {
        require(!securityPolicy.emergencyMode, "Wallet in emergency mode");
        _;
    }
    
    constructor(
        address[] memory _owners,
        uint256 _required,
        string[] memory _names
    ) {
        require(_owners.length >= 3, "Need at least 3 owners");
        require(_required >= 2 && _required <= _owners.length, "Invalid required number");
        require(_owners.length == _names.length, "Names array length mismatch");
        
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner address");
            require(!isOwner[_owners[i]], "Duplicate owner");
            
            owners.push(Owner({
                addr: _owners[i],
                isActive: true,
                reputation: 100, // Start with perfect reputation
                lastActivity: block.timestamp,
                name: _names[i],
                isEmergencyContact: i < 2 // First 2 owners are emergency contacts
            }));
            
            isOwner[_owners[i]] = true;
            ownerIndex[_owners[i]] = i;
            
            if (i < 2) {
                emergencyContacts[_owners[i]] = true;
            }
        }
        
        required = _required;
        
        // Initialize security policy
        securityPolicy = SecurityPolicy({
            dailyLimit: 10 ether,
            monthlyLimit: 100 ether,
            emergencyDelay: 24 hours,
            highValueThreshold: 5 ether,
            emergencyMode: false,
            emergencyActivatedAt: 0
        });
    }
    
    /**
     * @dev Submit a new transaction with AI risk analysis
     */
    function submitTransaction(
        address to,
        uint256 value,
        bytes memory data,
        TransactionType txType
    ) external onlyOwner notInEmergencyMode returns (uint256) {
        require(to != address(0), "Invalid recipient");
        
        uint256 txId = transactions.length;
        
        // Perform AI risk analysis
        (uint256 riskScore, AIRiskFactors memory riskFactors) = analyzeTransactionRisk(
            to, 
            value, 
            data, 
            txType
        );
        
        // Calculate required confirmations based on risk
        uint256 requiredConfirmationsCount = calculateRequiredConfirmations(
            riskScore, 
            txType
        );
        
        // Calculate timelock delay based on risk
        uint256 timelockDelay = calculateTimelockDelay(riskScore, txType);
        
        transactions.push(Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 0,
            riskScore: riskScore,
            timelock: block.timestamp + timelockDelay,
            submissionTime: block.timestamp,
            submitter: msg.sender,
            txType: txType
        }));
        
        requiredConfirmations[txId] = requiredConfirmationsCount;
        
        // Update owner activity and reputation
        updateOwnerActivity(msg.sender, true);
        
        // Check for suspicious activity
        if (riskScore > 80) {
            suspiciousActivity[to]++;
            emit SuspiciousActivityDetected(to, riskScore);
        }
        
        emit TransactionSubmitted(txId, msg.sender, to, value, txType);
        emit RiskAnalysisCompleted(txId, riskScore, requiredConfirmationsCount);
        
        return txId;
    }
    
    /**
     * @dev Confirm a transaction
     */
    function confirmTransaction(uint256 txId) external onlyOwner {
        require(txId < transactions.length, "Transaction does not exist");
        require(!confirmations[txId][msg.sender], "Transaction already confirmed");
        require(!transactions[txId].executed, "Transaction already executed");
        
        Transaction storage txn = transactions[txId];
        
        // Additional checks for high-risk transactions
        if (txn.riskScore > 70) {
            require(
                block.timestamp >= txn.submissionTime + 1 hours,
                "High-risk transaction requires 1-hour delay before confirmation"
            );
        }
        
        confirmations[txId][msg.sender] = true;
        confirmationTimestamps[txId][msg.sender] = block.timestamp;
        txn.confirmations++;
        
        // Update owner reputation for participating in governance
        updateOwnerReputation(msg.sender, 2);
        updateOwnerActivity(msg.sender, true);
        
        emit TransactionConfirmed(txId, msg.sender);
        
        // Auto-execute if requirements are met
        if (isExecutable(txId)) {
            executeTransaction(txId);
        }
    }
    
    /**
     * @dev Execute a confirmed transaction
     */
    function executeTransaction(uint256 txId) public onlyOwner nonReentrant {
        require(txId < transactions.length, "Transaction does not exist");
        require(isExecutable(txId), "Transaction not executable");
        
        Transaction storage txn = transactions[txId];
        require(block.timestamp >= txn.timelock, "Transaction still in timelock");
        
        txn.executed = true;
        
        // Update spending limits
        if (txn.value > 0) {
            updateSpendingLimits(msg.sender, txn.value);
        }
        
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        
        // Update owner reputations based on execution success
        updateConfirmersReputation(txId, success);
        
        emit TransactionExecuted(txId, success);
    }
    
    /**
     * @dev Submit and execute emergency transaction (bypasses normal flow)
     */
    function emergencyTransaction(
        address to,
        uint256 value,
        bytes memory data
    ) external {
        require(emergencyContacts[msg.sender], "Not an emergency contact");
        require(
            securityPolicy.emergencyMode || 
            block.timestamp < securityPolicy.emergencyActivatedAt + 24 hours,
            "Emergency mode required"
        );
        
        uint256 txId = transactions.length;
        
        transactions.push(Transaction({
            to: to,
            value: value,
            data: data,
            executed: true,
            confirmations: 1,
            riskScore: 100, // Always high risk
            timelock: block.timestamp,
            submissionTime: block.timestamp,
            submitter: msg.sender,
            txType: TransactionType.EMERGENCY
        }));
        
        emergencyTransactions[txId] = true;
        emergencyCount++;
        
        (bool success, ) = to.call{value: value}(data);
        
        emit TransactionSubmitted(txId, msg.sender, to, value, TransactionType.EMERGENCY);
        emit TransactionExecuted(txId, success);
    }
    
    /**
     * @dev AI-powered transaction risk analysis
     */
    function analyzeTransactionRisk(
        address to,
        uint256 value,
        bytes memory data,
        TransactionType txType
    ) internal view returns (uint256 riskScore, AIRiskFactors memory factors) {
        // Amount-based risk
        uint256 amountRisk = 0;
        if (value > securityPolicy.highValueThreshold) {
            amountRisk = 30;
            if (value > address(this).balance / 2) {
                amountRisk = 60; // More than 50% of balance
            }
        }
        
        // Recipient-based risk
        uint256 recipientRisk = suspiciousActivity[to] * 20;
        if (recipientRisk > 50) recipientRisk = 50;
        
        // Data complexity risk
        uint256 dataComplexity = 0;
        if (data.length > 0) {
            dataComplexity = 15;
            if (data.length > 1000) {
                dataComplexity = 30;
            }
        }
        
        // Time-based risk (night time transactions are riskier)
        uint256 timeRisk = 0;
        uint256 hour = (block.timestamp / 3600) % 24;
        if (hour < 6 || hour > 22) { // Between 10 PM and 6 AM
            timeRisk = 15;
        }
        
        // Frequency risk (too many transactions in short period)
        uint256 frequencyRisk = 0;
        // This would require tracking recent transaction frequency
        
        // Transaction type base risk
        uint256 typeRisk = 0;
        if (txType == TransactionType.HIGH_VALUE) typeRisk = 25;
        else if (txType == TransactionType.CONTRACT_INTERACTION) typeRisk = 20;
        else if (txType == TransactionType.EMERGENCY) typeRisk = 50;
        
        factors = AIRiskFactors({
            amountRisk: amountRisk,
            recipientRisk: recipientRisk,
            dataComplexity: dataComplexity,
            timeRisk: timeRisk,
            frequencyRisk: frequencyRisk
        });
        
        riskScore = amountRisk + recipientRisk + dataComplexity + timeRisk + frequencyRisk + typeRisk;
        if (riskScore > 100) riskScore = 100;
        
        return (riskScore, factors);
    }
    
    /**
     * @dev Calculate required confirmations based on risk score
     */
    function calculateRequiredConfirmations(
        uint256 riskScore, 
        TransactionType txType
    ) internal view returns (uint256) {
        uint256 baseRequired = required;
        
        if (txType == TransactionType.EMERGENCY) {
            return owners.length; // All owners for emergency
        }
        
        if (riskScore >= 80) {
            return owners.length; // All owners for very high risk
        } else if (riskScore >= 60) {
            return (owners.length * 2) / 3; // 2/3 for high risk
        } else if (riskScore >= 40) {
            return (owners.length + 1) / 2; // Majority for medium risk
        }
        
        return baseRequired; // Base requirement for low risk
    }
    
    /**
     * @dev Calculate timelock delay based on risk
     */
    function calculateTimelockDelay(
        uint256 riskScore, 
        TransactionType txType
    ) internal view returns (uint256) {
        if (txType == TransactionType.EMERGENCY) {
            return 0; // No delay for emergencies
        }
        
        if (riskScore >= 80) {
            return 7 days; // 1 week for very high risk
        } else if (riskScore >= 60) {
            return 3 days; // 3 days for high risk
        } else if (riskScore >= 40) {
            return 1 days; // 1 day for medium risk
        }
        
        return 1 hours; // 1 hour minimum for low risk
    }
    
    /**
     * @dev Update owner activity and reputation
     */
    function updateOwnerActivity(address owner, bool positive) internal {
        uint256 idx = ownerIndex[owner];
        owners[idx].lastActivity = block.timestamp;
        
        if (positive && owners[idx].reputation < 100) {
            owners[idx].reputation += 1;
        }
    }
    
    /**
     * @dev Update owner reputation based on specific actions
     */
    function updateOwnerReputation(address owner, uint256 points) internal {
        uint256 idx = ownerIndex[owner];
        if (owners[idx].reputation + points > 100) {
            owners[idx].reputation = 100;
        } else {
            owners[idx].reputation += points;
        }
        
        emit OwnerReputationUpdated(owner, owners[idx].reputation);
    }
    
    /**
     * @dev Update spending limits tracking
     */
    function updateSpendingLimits(address spender, uint256 amount) internal {
        uint256 today = block.timestamp / 86400;
        uint256 thisMonth = block.timestamp / (86400 * 30);
        
        if (lastResetDay[today] != today) {
            dailySpent[spender] = 0;
            lastResetDay[today] = today;
        }
        
        if (lastResetMonth[thisMonth] != thisMonth) {
            monthlySpent[spender] = 0;
            lastResetMonth[thisMonth] = thisMonth;
        }
        
        dailySpent[spender] += amount;
        monthlySpent[spender] += amount;
        
        require(dailySpent[spender] <= securityPolicy.dailyLimit, "Daily limit exceeded");
        require(monthlySpent[spender] <= securityPolicy.monthlyLimit, "Monthly limit exceeded");
    }
    
    /**
     * @dev Update reputation of all confirmers based on transaction outcome
     */
    function updateConfirmersReputation(uint256 txId, bool success) internal {
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[txId][owners[i].addr]) {
                if (success) {
                    updateOwnerReputation(owners[i].addr, 3);
                } else {
                    if (owners[i].reputation >= 5) {
                        owners[i].reputation -= 5;
                    }
                }
            }
        }
    }
    
    /**
     * @dev Check if transaction is executable
     */
    function isExecutable(uint256 txId) public view returns (bool) {
        Transaction memory txn = transactions[txId];
        return !txn.executed && 
               txn.confirmations >= requiredConfirmations[txId] &&
               block.timestamp >= txn.timelock;
    }
    
    /**
     * @dev Activate emergency mode
     */
    function activateEmergencyMode() external {
        require(emergencyContacts[msg.sender], "Not authorized for emergency");
        
        securityPolicy.emergencyMode = true;
        securityPolicy.emergencyActivatedAt = block.timestamp;
        
        emit EmergencyModeActivated(msg.sender);
    }
    
    /**
     * @dev Deactivate emergency mode (requires majority)
     */
    function deactivateEmergencyMode() external onlyWallet {
        securityPolicy.emergencyMode = false;
        securityPolicy.emergencyActivatedAt = 0;
        
        emit EmergencyModeDeactivated(msg.sender);
    }
    
    /**
     * @dev Social recovery: Request owner replacement
     */
    function requestRecovery(
        address oldOwner,
        address newOwner,
        address[] memory guardians
    ) external {
        require(isOwner[oldOwner], "Not an owner");
        require(!isOwner[newOwner], "Already an owner");
        require(guardians.length >= 3, "Need at least 3 guardians");
        
        recoveryGuardians[oldOwner] = guardians;
        recoveryRequestTime[oldOwner] = block.timestamp;
        
        emit RecoveryRequested(oldOwner, guardians);
    }
    
    /**
     * @dev Guardian approves recovery
     */
    function approveRecovery(address oldOwner) external {
        require(recoveryRequestTime[oldOwner] > 0, "No recovery request");
        require(
            block.timestamp <= recoveryRequestTime[oldOwner] + RECOVERY_PERIOD,
            "Recovery period expired"
        );
        
        // Check if sender is a guardian
        bool isGuardian = false;
        for (uint256 i = 0; i < recoveryGuardians[oldOwner].length; i++) {
            if (recoveryGuardians[oldOwner][i] == msg.sender) {
                isGuardian = true;
                break;
            }
        }
        require(isGuardian, "Not a guardian");
        
        recoveryApprovals[oldOwner][msg.sender] = true;
    }
    
    /**
     * @dev Execute recovery if enough approvals
     */
    function executeRecovery(address oldOwner, address newOwner) external {
        require(recoveryRequestTime[oldOwner] > 0, "No recovery request");
        
        // Count approvals
        uint256 approvals = 0;
        for (uint256 i = 0; i < recoveryGuardians[oldOwner].length; i++) {
            if (recoveryApprovals[oldOwner][recoveryGuardians[oldOwner][i]]) {
                approvals++;
            }
        }
        
        require(approvals >= (recoveryGuardians[oldOwner].length * 2) / 3, "Not enough approvals");
        
        // Replace owner
        uint256 idx = ownerIndex[oldOwner];
        owners[idx].addr = newOwner;
        owners[idx].reputation = 50; // Reset reputation
        
        isOwner[oldOwner] = false;
        isOwner[newOwner] = true;
        ownerIndex[newOwner] = idx;
        
        // Clear recovery data
        delete recoveryGuardians[oldOwner];
        delete recoveryRequestTime[oldOwner];
        
        emit RecoveryExecuted(oldOwner, newOwner);
    }
    
    /**
     * @dev Get comprehensive wallet statistics
     */
    function getWalletStats() external view returns (
        uint256 balance,
        uint256 pendingTransactions,
        uint256 avgRiskScore,
        uint256 emergencyTransactionCount,
        bool isInEmergencyMode,
        uint256 totalOwners,
        uint256 baseRequired
    ) {
        balance = address(this).balance;
        baseRequired = required;
        totalOwners = owners.length;
        isInEmergencyMode = securityPolicy.emergencyMode;
        emergencyTransactionCount = emergencyCount;
        
        uint256 pending = 0;
        uint256 totalRisk = 0;
        uint256 totalTxns = 0;
        
        for (uint256 i = 0; i < transactions.length; i++) {
            if (!transactions[i].executed) {
                pending++;
            }
            totalRisk += transactions[i].riskScore;
            totalTxns++;
        }
        
        pendingTransactions = pending;
        avgRiskScore = totalTxns > 0 ? totalRisk / totalTxns : 0;
        
        return (
            balance,
            pendingTransactions,
            avgRiskScore,
            emergencyTransactionCount,
            isInEmergencyMode,
            totalOwners,
            baseRequired
        );
    }
    
    /**
     * @dev Get transaction details with risk analysis
     */
    function getTransactionDetails(uint256 txId) external view returns (
        Transaction memory transaction,
        AIRiskFactors memory riskFactors,
        uint256 requiredConfirmationsCount,
        bool executable
    ) {
        require(txId < transactions.length, "Transaction does not exist");
        
        transaction = transactions[txId];
        requiredConfirmationsCount = requiredConfirmations[txId];
        executable = isExecutable(txId);
        
        // Recalculate risk factors for display
        (, riskFactors) = analyzeTransactionRisk(
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.txType
        );
        
        return (transaction, riskFactors, requiredConfirmationsCount, executable);
    }
    
    /**
     * @dev Get owner information
     */
    function getOwnerInfo(address owner) external view returns (
        Owner memory ownerInfo,
        uint256 dailySpentAmount,
        uint256 monthlySpentAmount,
        bool isEmergencyContact
    ) {
        require(isOwner[owner], "Not an owner");
        
        uint256 idx = ownerIndex[owner];
        ownerInfo = owners[idx];
        dailySpentAmount = dailySpent[owner];
        monthlySpentAmount = monthlySpent[owner];
        isEmergencyContact = emergencyContacts[owner];
        
        return (ownerInfo, dailySpentAmount, monthlySpentAmount, isEmergencyContact);
    }
    
    // Wallet management functions (only callable by wallet itself)
    function addOwner(address owner, string memory name) external onlyWallet {
        require(!isOwner[owner], "Already an owner");
        
        owners.push(Owner({
            addr: owner,
            isActive: true,
            reputation: 100,
            lastActivity: block.timestamp,
            name: name,
            isEmergencyContact: false
        }));
        
        isOwner[owner] = true;
        ownerIndex[owner] = owners.length - 1;
        
        emit OwnerAdded(owner, name);
    }
    
    function removeOwner(address owner) external onlyWallet {
        require(isOwner[owner], "Not an owner");
        require(owners.length > 3, "Cannot have less than 3 owners");
        
        uint256 idx = ownerIndex[owner];
        uint256 lastIdx = owners.length - 1;
        
        if (idx != lastIdx) {
            owners[idx] = owners[lastIdx];
            ownerIndex[owners[idx].addr] = idx;
        }
        
        owners.pop();
        isOwner[owner] = false;
        delete ownerIndex[owner];
        
        if (required > owners.length) {
            required = owners.length;
        }
        
        emit OwnerRemoved(owner);
    }
    
    function changeRequired(uint256 _required) external onlyWallet {
        require(_required >= 2 && _required <= owners.length, "Invalid required number");
        required = _required;
        emit RequiredChanged(_required);
    }
    
    function updateSecurityPolicy(
        uint256 _dailyLimit,
        uint256 _monthlyLimit,
        uint256 _emergencyDelay,
        uint256 _highValueThreshold
    ) external onlyWallet {
        securityPolicy.dailyLimit = _dailyLimit;
        securityPolicy.monthlyLimit = _monthlyLimit;
        securityPolicy.emergencyDelay = _emergencyDelay;
        securityPolicy.highValueThreshold = _highValueThreshold;
        
        emit SecurityPolicyUpdated(_dailyLimit, _monthlyLimit);
    }
    
    receive() external payable {}
    
    fallback() external payable {}
}
