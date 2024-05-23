// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SimpleVotingSystem.sol";

contract SimpleVotingSystemTest is Test {
    SimpleVotingSystem voting;
    address owner = address(1);
    address admin = address(4);
    address founder = address(5);
    address voter1 = address(2);
    address voter2 = address(3);

    function setUp() public {
        vm.startPrank(owner);
        voting = new SimpleVotingSystem();
        voting.addAdmin(admin);
        voting.addFounder(founder);
        vm.stopPrank();
    }

    function testOwnerIsSetCorrectly() public {
        assertTrue(voting.hasRole(voting.DEFAULT_ADMIN_ROLE(), owner));
    }

    function testAdminRoleAssigned() public {
        assertTrue(voting.hasRole(voting.ADMIN_ROLE(), owner));
        assertTrue(voting.hasRole(voting.ADMIN_ROLE(), admin));
    }

    function testFounderRoleAssigned() public {
        assertTrue(voting.hasRole(voting.FOUNDER_ROLE(), founder));
    }

    function testAddCandidateAsAdmin() public {
        vm.startPrank(admin);
        voting.addCandidate("Alice");
        vm.stopPrank();

        SimpleVotingSystem.Candidate memory candidate = voting.getCandidate(1);
        assertEq(candidate.id, 1);
        assertEq(candidate.name, "Alice");
        assertEq(candidate.voteCount, 0);
        assertEq(candidate.fundsReceived, 0);
    }

    function testFailAddCandidateAsNonAdmin() public {
        vm.startPrank(voter1);
        vm.expectRevert("Only an admin can perform this action");
        voting.addCandidate("Bob");
        vm.stopPrank();
    }

    function testFailAddCandidateInWrongWorkflowStatus() public {
        vm.startPrank(admin);
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES);
        vm.expectRevert("Function cannot be called at this time");
        voting.addCandidate("Alice");
        vm.stopPrank();
    }

    function testVoteForCandidate() public {
        vm.startPrank(admin);
        voting.addCandidate("Alice");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours);
        vm.stopPrank();

        vm.startPrank(voter1);
        voting.vote(1);
        vm.stopPrank();

        SimpleVotingSystem.Candidate memory candidate = voting.getCandidate(1);
        assertEq(candidate.voteCount, 1);
    }

    function testFailVoteBeforeOneHour() public {
        vm.startPrank(admin);
        voting.addCandidate("Alice");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        vm.stopPrank();

        vm.startPrank(voter1);
        vm.expectRevert("Voting is not allowed yet. Please wait for 1 hour.");
        voting.vote(1);
        vm.stopPrank();
    }

    function testFailVoteInWrongWorkflowStatus() public {
        vm.startPrank(admin);
        voting.addCandidate("Alice");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES);
        vm.stopPrank();

        vm.startPrank(voter1);
        vm.expectRevert("Function cannot be called at this time");
        voting.vote(1);
        vm.stopPrank();
    }

    function testFailVoteTwice() public {
        vm.startPrank(admin);
        voting.addCandidate("Alice");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours); 
        vm.stopPrank();

        vm.startPrank(voter1);
        voting.vote(1);
        vm.expectRevert("You have already voted");
        voting.vote(1);
        vm.stopPrank();
    }

    function testDonateToCandidateAsFounder() public {
        vm.startPrank(admin);
        voting.addCandidate("Alice");
        vm.stopPrank();

        vm.deal(founder, 10 ether);
        vm.startPrank(founder);
        voting.donateToCandidate{value: 1 ether}(1);
        vm.stopPrank();

        SimpleVotingSystem.Candidate memory candidate = voting.getCandidate(1);
        assertEq(candidate.fundsReceived, 1 ether);
    }

    function testFailDonateToCandidateAsNonFounder() public {
        vm.startPrank(admin);
        voting.addCandidate("Alice");
        vm.stopPrank();

        vm.deal(voter1, 10 ether);
        vm.startPrank(voter1);
        vm.expectRevert("Only a founder can perform this action");
        voting.donateToCandidate{value: 1 ether}(1);
        vm.stopPrank();
    }

    function testGetTotalVotes() public {
        vm.startPrank(admin);
        voting.addCandidate("Alice");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours); 
        vm.stopPrank();

        vm.startPrank(voter1);
        voting.vote(1);
        vm.stopPrank();

        uint totalVotes = voting.getTotalVotes(1);
        assertEq(totalVotes, 1);
    }

    function testGetTotalFunds() public {
        vm.startPrank(admin);
        voting.addCandidate("Alice");
        vm.stopPrank();

        vm.deal(founder, 10 ether);
        vm.startPrank(founder);
        voting.donateToCandidate{value: 1 ether}(1);
        vm.stopPrank();

        uint totalFunds = voting.getTotalFunds(1);
        assertEq(totalFunds, 1 ether);
    }

    function testGetCandidatesCount() public {
        vm.startPrank(admin);
        voting.addCandidate("Alice");
        vm.stopPrank();

        uint candidatesCount = voting.getCandidatesCount();
        assertEq(candidatesCount, 1);
    }

    function testDesignateWinner() public {
        vm.startPrank(admin);
        voting.addCandidate("Alice");
        voting.addCandidate("Bob");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours); 
        vm.stopPrank();

        vm.startPrank(voter1);
        voting.vote(1);
        voting.vote(1); 
        vm.stopPrank();

        vm.startPrank(voter2);
        voting.vote(2);
        vm.stopPrank();

        vm.startPrank(admin);
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.COMPLETED);
        SimpleVotingSystem.Candidate memory winner = voting.designateWinner();
        vm.stopPrank();

        assertEq(winner.name, "Alice");
        assertEq(winner.voteCount, 2);
    }

    function testFailDesignateWinnerInWrongWorkflowStatus() public {
        vm.startPrank(admin);
        voting.addCandidate("Alice");
        voting.addCandidate("Bob");
        vm.stopPrank();

        vm.startPrank(voter1);
        voting.vote(1);
        voting.vote(1); 
        vm.stopPrank();

        vm.startPrank(voter2);
        voting.vote(2);
        vm.stopPrank();

        vm.startPrank(admin);
        vm.expectRevert("Function cannot be called at this time");
        voting.designateWinner();
        vm.stopPrank();
    }
}
