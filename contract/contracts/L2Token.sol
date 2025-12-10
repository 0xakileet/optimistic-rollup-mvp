// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title L2Token
 * @dev ERC20 token on L2 that can be minted/burned by bridge
 */
contract L2Token is ERC20, AccessControl {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    address public l1Token; // Corresponding L1 token address
    
    event BridgeMint(address indexed to, uint256 amount);
    event BridgeBurn(address indexed from, uint256 amount);
    
    constructor(
        string memory name,
        string memory symbol,
        address _l1Token,
        address bridge
    ) ERC20(name, symbol) {
        l1Token = _l1Token;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BRIDGE_ROLE, bridge);
        _grantRole(MINTER_ROLE, bridge);
    }
    
    /**
     * @dev Mint tokens (called by bridge on deposit)
     */
    function bridgeMint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
        emit BridgeMint(to, amount);
    }
    
    /**
     * @dev Burn tokens (called by bridge on withdrawal)
     */
    function bridgeBurn(address from, uint256 amount) external onlyRole(BRIDGE_ROLE) {
        _burn(from, amount);
        emit BridgeBurn(from, amount);
    }
}