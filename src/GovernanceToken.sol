// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/// @title GovernanceToken
/// @notice ERC20 token with voting and permit capabilities for on-chain governance.
/// @dev Inherits ERC20, ERC20Permit, and ERC20Votes from OpenZeppelin v5.x.
contract GovernanceToken is ERC20, ERC20Permit, ERC20Votes {
    /// @notice Deploys the GovernanceToken and mints the initial supply to the owner.
    /// @param _initialOwner Address that receives the full initial supply of 1,000,000 tokens.
    constructor(address _initialOwner) ERC20("Governance Token", "GOV") ERC20Permit("Governance Token") {
        _mint(_initialOwner, 1_000_000 ether);
    }

    /// @dev Required override for ERC20 and ERC20Votes.
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    /// @dev Required override for ERC20Permit and Nonces.
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
