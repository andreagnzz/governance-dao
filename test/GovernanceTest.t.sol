// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {MyTimelock} from "../src/MyTimelock.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract GovernanceTest is Test {
    GovernanceToken public token;
    MyTimelock public timelock;
    MyGovernor public governor;

    address public deployer;
    address public voter1;
    address public voter2;

    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 public constant VOTER1_TOKENS = 100_000 ether;
    uint256 public constant VOTER2_TOKENS = 50_000 ether;
    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant VOTING_DELAY = 7200; // blocks
    uint256 public constant VOTING_PERIOD = 50400; // blocks

    function setUp() public {
        deployer = address(this);
        voter1 = makeAddr("voter1");
        voter2 = makeAddr("voter2");

        // Deploy token
        token = new GovernanceToken(deployer);

        // Deploy timelock
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new MyTimelock(MIN_DELAY, proposers, executors, deployer);

        // Deploy governor
        governor = new MyGovernor(IVotes(address(token)), TimelockController(payable(address(timelock))));

        // Configure timelock roles
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        // Distribute tokens to voters
        token.transfer(voter1, VOTER1_TOKENS);
        token.transfer(voter2, VOTER2_TOKENS);

        // Voters delegate to themselves
        vm.prank(voter1);
        token.delegate(voter1);
        vm.prank(voter2);
        token.delegate(voter2);

        // Advance one block to register checkpoints
        vm.roll(block.number + 1);
    }

    // --- Test 1: Initial Supply ---

    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    // --- Test 2: Token Distribution ---

    function test_TokenDistribution() public view {
        assertEq(token.balanceOf(voter1), VOTER1_TOKENS);
        assertEq(token.balanceOf(voter2), VOTER2_TOKENS);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - VOTER1_TOKENS - VOTER2_TOKENS);
    }

    // --- Test 3: Voting Power After Delegation ---

    function test_VotingPowerAfterDelegation() public view {
        assertEq(token.getVotes(voter1), VOTER1_TOKENS);
        assertEq(token.getVotes(voter2), VOTER2_TOKENS);
    }

    // --- Test 4: Delegation Required ---

    function test_DelegationRequired() public {
        address undelegated = makeAddr("undelegated");
        token.transfer(undelegated, 1000 ether);
        vm.roll(block.number + 1);
        assertEq(token.getVotes(undelegated), 0);
    }

    // --- Test 5: Governor Settings ---

    function test_GovernorSettings() public view {
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(governor.proposalThreshold(), 0);
        assertEq(governor.name(), "MyGovernor");
    }

    // --- Test 6: Quorum Value ---

    function test_QuorumValue() public view {
        // 4% of 1M = 40,000 tokens
        assertEq(governor.quorum(block.number - 1), 40_000 ether);
    }

    // --- Test 7: Timelock Roles ---

    function test_TimelockRoles() public view {
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        assertTrue(timelock.hasRole(proposerRole, address(governor)));
        assertTrue(timelock.hasRole(executorRole, address(0)));
        assertFalse(timelock.hasRole(adminRole, deployer));
    }

    // --- Test 8: Full Proposal Lifecycle ---

    function test_FullProposalLifecycle() public {
        address recipient = makeAddr("recipient");

        // Send 10k tokens to timelock so it can execute the transfer
        token.transfer(address(timelock), 10_000 ether);

        // Build proposal: transfer 1000 GOV to recipient
        address[] memory targets = new address[](1);
        targets[0] = address(token);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", recipient, 1000 ether);
        string memory description = "Transfer 1000 GOV to recipient";

        // Propose
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Advance past voting delay → Active
        vm.roll(block.number + VOTING_DELAY + 1);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active));

        // voter1 and voter2 vote FOR
        vm.prank(voter1);
        governor.castVote(proposalId, 1); // 1 = For
        vm.prank(voter2);
        governor.castVote(proposalId, 1);

        // Advance past voting period → Succeeded
        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        // Queue → Queued
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Queued));

        // Warp past timelock delay
        vm.warp(block.timestamp + MIN_DELAY + 1);

        // Execute → Executed
        governor.execute(targets, values, calldatas, descriptionHash);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));

        // Verify recipient received the tokens
        assertEq(token.balanceOf(recipient), 1000 ether);
    }

    // --- Test 9: Proposal Fails Without Quorum ---

    function test_ProposalFailsWithoutQuorum() public {
        // Create a small voter who alone cannot meet quorum (4% = 40k)
        address smallVoter = makeAddr("smallVoter");
        token.transfer(smallVoter, 1000 ether);
        vm.prank(smallVoter);
        token.delegate(smallVoter);
        vm.roll(block.number + 1);

        // Propose
        address[] memory targets = new address[](1);
        targets[0] = address(token);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", smallVoter, 100 ether);
        string memory description = "Small proposal without quorum";

        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Advance past voting delay
        vm.roll(block.number + VOTING_DELAY + 1);

        // Only small voter votes FOR (1000 < 40000 quorum)
        vm.prank(smallVoter);
        governor.castVote(proposalId, 1);

        // Advance past voting period → Defeated (quorum not met)
        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }

    // --- Test 10: Proposal Defeated by Majority ---

    function test_ProposalDefeatedByMajority() public {
        // Propose
        address[] memory targets = new address[](1);
        targets[0] = address(token);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", voter1, 100 ether);
        string memory description = "Proposal to be defeated";

        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Advance past voting delay
        vm.roll(block.number + VOTING_DELAY + 1);

        // voter1 votes FOR, voter2 votes AGAINST
        // But we need majority against, so let's have voter1 vote AGAINST (100k) and voter2 vote FOR (50k)
        vm.prank(voter1);
        governor.castVote(proposalId, 0); // 0 = Against
        vm.prank(voter2);
        governor.castVote(proposalId, 1); // 1 = For

        // Advance past voting period → Defeated (majority against)
        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }
}
