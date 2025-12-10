// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title Paymaster
 * @dev Sponsors gas for users (ERC-4337 style paymaster)
 */
contract Paymaster is Ownable {
    using MessageHashUtils for bytes32;
    // Whitelist for sponsored addresses
    mapping(address => bool) public sponsoredUsers;
    
    // Global sponsorship mode
    bool public globalSponsorship;
    
    // Spending limits per user
    mapping(address => uint256) public userSpendingLimit;
    mapping(address => uint256) public userSpentAmount;
    
    // Trusted verifiers who can approve transactions
    mapping(address => bool) public verifiers;
    
    // Nonces for replay protection
    mapping(address => uint256) public nonces;
    
    event UserSponsored(address indexed user);
    event UserRemoved(address indexed user);
    event GasPaid(address indexed user, uint256 amount);
    event FundsDeposited(address indexed from, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);
    
    constructor() Ownable(msg.sender){
        verifiers[msg.sender] = true;
    }
    
    /**
     * @dev Deposit funds to sponsor gas
     */
    function deposit() external payable {
        emit FundsDeposited(msg.sender, msg.value);
    }
    
    /**
     * @dev Check if user should be sponsored
     */
    function shouldSponsor(address user) public view returns (bool) {
        if (globalSponsorship) return true;
        if (sponsoredUsers[user]) {
            if (userSpendingLimit[user] > 0) {
                return userSpentAmount[user] < userSpendingLimit[user];
            }
            return true;
        }
        return false;
    }
    
    /**
     * @dev Sponsor gas for a user transaction
     */
    function sponsorTransaction(
        address user,
        uint256 gasAmount,
        bytes calldata signature
    ) external returns (bool) {
        require(shouldSponsor(user), "User not eligible for sponsorship");
        
        // Verify signature from trusted verifier
        bytes32 hash = keccak256(abi.encodePacked(user, gasAmount, nonces[user]));
        bytes32 ethHash = hash.toEthSignedMessageHash();
        address signer = ECDSA.recover(ethHash, signature);

        require(verifiers[signer], "Invalid verifier");
        
        nonces[user]++;
        
        // Track spending
        if (userSpendingLimit[user] > 0) {
            userSpentAmount[user] += gasAmount;
        }
        
        emit GasPaid(user, gasAmount);
        return true;
    }
    
    /**
     * @dev Add user to sponsorship whitelist
     */
    function addSponsoredUser(address user, uint256 limit) external onlyOwner {
        sponsoredUsers[user] = true;
        userSpendingLimit[user] = limit;
        emit UserSponsored(user);
    }
    
    /**
     * @dev Remove user from sponsorship
     */
    function removeSponsoredUser(address user) external onlyOwner {
        sponsoredUsers[user] = false;
        emit UserRemoved(user);
    }
    
    /**
     * @dev Enable global sponsorship (all users)
     */
    function setGlobalSponsorship(bool enabled) external onlyOwner {
        globalSponsorship = enabled;
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
     * @dev Withdraw funds
     */
    function withdraw(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        emit FundsWithdrawn(msg.sender, amount);
    }
    
    receive() external payable {
        emit FundsDeposited(msg.sender, msg.value);
    }
}