// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IL2Token {
    function bridgeMint(address to, uint256 amount) external;
    function bridgeBurn(address from, uint256 amount) external;
}

/**
 * @title L2Bridge
 * @dev Bridge contract on L2 for handling deposits/withdrawals
 */
contract L2Bridge is ReentrancyGuard, Ownable {
    
    // L1 bridge address
    address public l1Bridge;
    
    // Sequencer address
    address public sequencer;
    
    // Token mappings (L1 -> L2)
    mapping(address => address) public l1ToL2Tokens;
    mapping(address => address) public l2ToL1Tokens;
    
    // Withdrawal nonce
    uint256 public withdrawalNonce;
    
    // Events
    event DepositFinalized(
        address indexed l1Token,
        address indexed l2Token,
        address indexed to,
        uint256 amount,
        uint256 l1DepositNonce
    );
    
    event WithdrawalInitiated(
        address indexed l2Token,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 nonce
    );
    
    constructor(address _l1Bridge, address _sequencer) Ownable(msg.sender){
        l1Bridge = _l1Bridge;
        sequencer = _sequencer;
    }
    
    /**
     * @dev Finalize deposit from L1 (called by sequencer)
     */
    function finalizeDeposit(
        address l1Token,
        address to,
        uint256 amount,
        uint256 l1DepositNonce
    ) external {
        require(msg.sender == sequencer, "Only sequencer");
        
        address l2Token = l1ToL2Tokens[l1Token];
        require(l2Token != address(0), "Token not mapped");
        
        // Mint L2 tokens
        IL2Token(l2Token).bridgeMint(to, amount);
        
        emit DepositFinalized(l1Token, l2Token, to, amount, l1DepositNonce);
    }
    
    /**
     * @dev Initiate withdrawal to L1
     */
    function withdraw(
        address l2Token,
        uint256 amount,
        address l1Recipient
    ) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        
        address l1Token = l2ToL1Tokens[l2Token];
        require(l1Token != address(0), "Token not mapped");
        
        // Burn L2 tokens
        IL2Token(l2Token).bridgeBurn(msg.sender, amount);
        
        emit WithdrawalInitiated(
            l2Token,
            msg.sender,
            l1Recipient,
            amount,
            withdrawalNonce
        );
        
        withdrawalNonce++;
    }
    
    /**
     * @dev Withdraw ETH to L1
     */
    function withdrawETH(uint256 amount, address l1Recipient) external payable nonReentrant {
        require(msg.value == amount, "Incorrect ETH amount");
        require(amount > 0, "Amount must be > 0");
        
        emit WithdrawalInitiated(
            address(0),
            msg.sender,
            l1Recipient,
            amount,
            withdrawalNonce
        );
        
        withdrawalNonce++;
    }
    
    /**
     * @dev Add token pair mapping
     */
    function addTokenPair(address l1Token, address l2Token) external onlyOwner {
        l1ToL2Tokens[l1Token] = l2Token;
        l2ToL1Tokens[l2Token] = l1Token;
    }
    
    /**
     * @dev Update sequencer
     */
    function updateSequencer(address _sequencer) external onlyOwner {
        sequencer = _sequencer;
    }
    
    receive() external payable {}
}