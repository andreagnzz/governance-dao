// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {MyTimelock} from "../src/MyTimelock.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title Deploy
/// @notice Foundry script to deploy the full DAO governance stack.
contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // 1. Deploy governance token and self-delegate
        GovernanceToken token = new GovernanceToken(deployer);
        token.delegate(deployer);

        // 2. Deploy timelock with no initial proposers/executors
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        MyTimelock timelock = new MyTimelock(3600, proposers, executors, deployer);

        // 3. Deploy governor
        MyGovernor governor = new MyGovernor(IVotes(address(token)), TimelockController(payable(address(timelock))));

        // 4. Configure timelock roles
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0)); // anyone can execute
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer); // decentralise

        vm.stopBroadcast();

        console.log("GovernanceToken deployed at:", address(token));
        console.log("MyTimelock deployed at:", address(timelock));
        console.log("MyGovernor deployed at:", address(governor));
        console.log("Deployer:", deployer);
    }
}
