// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title L1Bridge
 * @dev Bridge contract on Ethereum mainnet for deposits/withdrawals
 */


contract L1Bridge is ReentrancyGuard , Ownable {
    
    // Sequencer address authorized to process withdrawals | Also L2 to L1 
    address public sequencer;
    
    // Mapping of token addresses to their L2 counterparts 
    mapping(address => address) public tokenMapping;
    
    // Deposit nonce for tracking
  uint256 public depositNonce;
    
    // Withdrawal tracking
    mapping(bytes32 => bool) public processedWithdrawals;
    
    // Challenge period (7 days)
    uint256 public constant CHALLENGE_PERIOD = 7 days;
    
    // Pending withdrawals
    struct Withdrawal {
        address token;
        address recipient;
        uint256 amount;
        uint256 timestamp;
    }
    
    mapping(bytes32 => Withdrawal) public pendingWithdrawals;

  
    // Events
    event Deposited(
        address indexed token,
        address indexed depositor,
        address indexed l2Recipient,
        uint256 amount,
        uint256 nonce
    );
    
    event WithdrawalInitiated(
        bytes32 indexed withdrawalId,
        address indexed token,
        address indexed recipient,
        uint256 amount
    );
    

  event WithdrawalFinalized(
        bytes32 indexed withdrawalId,
        address indexed recipient,
        uint256 amount
    );

    constructor(address _sequencer) Ownable(_sequencer) {
        sequencer = _sequencer;
    }
    
    /**
     * @dev Deposit tokens to L2
     */
    function depositERC20(
        address token,
        uint256 amount,
        address l2Recipient

  ) external nonReentrant {
        require(tokenMapping[token] != address(0), "Token not supported");
        require(amount > 0, "Amount must be > 0");
        
        // Transfer tokens from user to bridge
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        emit Deposited(token, msg.sender, l2Recipient, amount, depositNonce);
        depositNonce++;
    }
    
    /**
     * @dev Deposit ETH to L2
     */
    function depositETH(address l2Recipient) external payable nonReentrant {
        require(msg.value > 0, "Must send ETH"); // get Security Check msg.data
        
      emit Deposited(address(0), msg.sender, l2Recipient, msg.value, depositNonce);
        depositNonce++;
    }
    
    /**
     * @dev Initiate withdrawal (called by sequencer)
     */
    function initiateWithdrawal(
        address token,
        address recipient,
        uint256 amount,
        bytes32 withdrawalId
    ) external {
        require(msg.sender == sequencer, "Only sequencer");
        require(!processedWithdrawals[withdrawalId], "Already processed");
        
        pendingWithdrawals[withdrawalId] = Withdrawal({
          token: token,
            recipient: recipient,
            amount: amount,
            timestamp: block.timestamp
        });
        
        emit WithdrawalInitiated(withdrawalId, token, recipient, amount);
    }
    
    /**
     * @dev Finalize withdrawal after challenge period
     */
    function finalizeWithdrawal(bytes32 withdrawalId) external nonReentrant {
        Withdrawal memory w = pendingWithdrawals[withdrawalId];
        require(w.amount > 0, "Withdrawal not found");
        require(
            block.timestamp >= w.timestamp + CHALLENGE_PERIOD,
          "Challenge period not ended"
        );
        require(!processedWithdrawals[withdrawalId], "Already processed");
        
        processedWithdrawals[withdrawalId] = true;
        delete pendingWithdrawals[withdrawalId];
        
        // Transfer tokens
        if (w.token == address(0)) {
            // ETH withdrawal
            (bool success, ) = w.recipient.call{value: w.amount}("");
            require(success, "ETH transfer failed");
        } else {
            // ERC20 withdrawal
            IERC20(w.token).transfer(w.recipient, w.amount);
        }
        
      emit WithdrawalFinalized(withdrawalId, w.recipient, w.amount);
    }
    
    /**
     * @dev Add token mapping
     */
    function addTokenMapping(address l1Token, address l2Token) external onlyOwner {
        tokenMapping[l1Token] = l2Token;
    }
    
    /**
     * @dev Update sequencer
     */
    function updateSequencer(address _sequencer) external onlyOwner {
        sequencer = _sequencer;
    }
    
    receive() external payable {}
}