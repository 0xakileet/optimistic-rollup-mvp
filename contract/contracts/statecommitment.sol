// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StateCommitment
 * @dev Stores L2 state roots and batch data on L1
 */
contract StateCommitment is Ownable {
    
    struct Batch {
        bytes32 stateRoot;
        bytes32 transactionRoot;
        uint256 timestamp;
        uint256 l2BlockNumber;
        address sequencer;
        bool finalized;
    }
    
    // Batch ID => Batch data
    mapping(uint256 => Batch) public batches;
    
    // Current batch ID
    uint256 public currentBatchId;
    
    // Sequencer address
    address public sequencer;
    
    // Finalization delay (for fraud proofs)
    uint256 public constant FINALIZATION_PERIOD = 7 days;
    
    // Verifiers who can challenge batches
    mapping(address => bool) public verifiers;
    
    // Events
    event BatchSubmitted(
        uint256 indexed batchId,
        bytes32 stateRoot,
        bytes32 transactionRoot,
        uint256 l2BlockNumber
    );
    
    event BatchFinalized(uint256 indexed batchId);
    event BatchChallenged(uint256 indexed batchId, address challenger);
    event BatchReverted(uint256 indexed batchId);
    
    constructor(address _sequencer) Ownable(msg.sender) {
        sequencer = _sequencer;
        verifiers[msg.sender] = true;
    }
    
    /**
     * @dev Submit a new batch of L2 transactions
     */
    function submitBatch(
        bytes32 stateRoot,
        bytes32 transactionRoot,
        uint256 l2BlockNumber,
        bytes calldata batchData
    ) external {
        require(msg.sender == sequencer, "Only sequencer");
        
        uint256 batchId = currentBatchId;
        
        batches[batchId] = Batch({
            stateRoot: stateRoot,
            transactionRoot: transactionRoot,
            timestamp: block.timestamp,
            l2BlockNumber: l2BlockNumber,
            sequencer: msg.sender,
            finalized: false
        });
        
        emit BatchSubmitted(batchId, stateRoot, transactionRoot, l2BlockNumber);
        
        currentBatchId++;
    }
    
    /**
     * @dev Finalize a batch after challenge period
     */
    function finalizeBatch(uint256 batchId) external {
        Batch storage batch = batches[batchId];
        require(batch.timestamp > 0, "Batch does not exist");
        require(!batch.finalized, "Already finalized");
        require(
            block.timestamp >= batch.timestamp + FINALIZATION_PERIOD,
            "Challenge period not ended"
        );
        
        batch.finalized = true;
        emit BatchFinalized(batchId);
    }
    
    /**
     * @dev Challenge a batch (fraud proof)
     */
    function challengeBatch(
        uint256 batchId,
        bytes calldata fraudProof
    ) external {
        require(verifiers[msg.sender], "Not a verifier");
        
        Batch storage batch = batches[batchId];
        require(batch.timestamp > 0, "Batch does not exist");
        require(!batch.finalized, "Already finalized");
        
        // In a real system, verify the fraud proof here
        // For now, we'll trust the verifier
        
        emit BatchChallenged(batchId, msg.sender);
        
        // Revert the batch
        delete batches[batchId];
        emit BatchReverted(batchId);
    }
    
    /**
     * @dev Get batch state root
     */
    function getBatchStateRoot(uint256 batchId) external view returns (bytes32) {
        return batches[batchId].stateRoot;
    }
    
    /**
     * @dev Check if batch is finalized
     */
    function isBatchFinalized(uint256 batchId) external view returns (bool) {
        return batches[batchId].finalized;
    }
    
    /**
     * @dev Add verifier
     */
    function addVerifier(address verifier) external onlyOwner {
        verifiers[verifier] = true;
    }
    
    /**
     * @dev Remove verifier
     */
    function removeVerifier(address verifier) external onlyOwner {
        verifiers[verifier] = false;
    }
    
    /**
     * @dev Update sequencer
     */
    function updateSequencer(address _sequencer) external onlyOwner {
        sequencer = _sequencer;
    }
}