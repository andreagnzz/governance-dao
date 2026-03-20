// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title MyTimelock
/// @notice Timelock controller that enforces a minimum delay on governance actions.
/// @dev Wraps OpenZeppelin's TimelockController with a simpler constructor interface.
contract MyTimelock is TimelockController {
    /// @notice Deploys the timelock with given delay, roles, and admin.
    /// @param minDelay Minimum delay (in seconds) before a queued operation can be executed.
    /// @param proposers Addresses granted the proposer role.
    /// @param executors Addresses granted the executor role (address(0) means anyone).
    /// @param admin Address granted the default admin role (set to address(0) to renounce).
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}
}
