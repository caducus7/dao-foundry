//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MyGovernor} from "../src/MyGovernor.sol";
import {Test, console} from "forge-std/Test.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract MyGovernorTest is Test {
    MyGovernor public gov;
    Box public box;
    GovToken public govToken;
    TimelockController public timelock;
    address public user = makeAddr("user");
    address[] proposers;
    address[] executors;
    uint256[] values;
    address[] targets;
    bytes[] calldatas;
    uint256 public constant MIN_DELAY = 3600; //1hour after a vote passes
    uint256 public constant VALUE_TO_STORE = 888;
    uint256 public constant VOTING_DELAY = 1;
    uint256 public constant VOTING_PERIOD = 50400; //1 week

    function setUp() public {
        govToken = new GovToken(user);
        vm.startPrank(user);
        govToken.delegate(user);

        timelock = new TimelockController(MIN_DELAY, proposers, executors, msg.sender);
        gov = new MyGovernor(govToken, timelock);
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();
        vm.stopPrank();
        vm.startPrank(address(timelock));
        timelock.grantRole(proposerRole, address(gov));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, address(this));
        vm.stopPrank();
        box = new Box(address(timelock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdatesBox() public {
        //     function propose(
        //     address[] memory targets,
        //     uint256[] memory values,
        //     bytes[] memory calldatas,
        //     string memory description
        // ) public virtual returns (uint256)

        string memory description = "store 888 in box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", VALUE_TO_STORE);

        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        //1 propose
        uint256 proposalId = gov.propose(targets, values, calldatas, description);
        console.log("Proposal State:", uint256(gov.state(proposalId)));
        assertEq(uint256(gov.state(proposalId)), 0);
        // view proposal state
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);
        console.log("Proposal State 2: ", uint256(gov.state(proposalId)));

        //2 vote
        vm.prank(user);
        gov.castVoteWithReason(proposalId, 1, "I like it");

        //speed up vote
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);
        console.log("Proposal State 3: ", uint256(gov.state(proposalId)));

        //3 queue the tx
        //     function queue(
        //     address[] memory targets,
        //     uint256[] memory values,
        //     bytes[] memory calldatas,
        //     bytes32 descriptionHash
        // ) public virtual returns (uint256)
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        gov.queue(targets, values, calldatas, descriptionHash);

        //wait for queue
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);
        console.log("Proposal State 4: ", uint256(gov.state(proposalId)));

        //4 execute the tx

        //function execute(
        //     address[] memory targets,
        //     uint256[] memory values,
        //     bytes[] memory calldatas,
        //     bytes32 descriptionHash
        // ) public payable virtual returns (uint256) {

        gov.execute(targets, values, calldatas, descriptionHash);
        console.log("Proposal State 5: ", uint256(gov.state(proposalId)));
        assertEq(box.getNumber(), VALUE_TO_STORE);
    }
}
