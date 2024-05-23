// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SimpleVotingSystem is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");

    enum WorkflowStatus { REGISTER_CANDIDATES, FOUND_CANDIDATES, VOTE, COMPLETED }
    WorkflowStatus public workflowStatus;

    uint public voteStartTime;

    struct Candidate {
        uint id;
        string name;
        uint voteCount;
        uint fundsReceived;
    }

    mapping(uint => Candidate) public candidates;
    mapping(address => bool) public voters;
    uint[] private candidateIds;

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Only an admin can perform this action");
        _;
    }

    modifier onlyFounder() {
        require(hasRole(FOUNDER_ROLE, msg.sender), "Only a founder can perform this action");
        _;
    }

    modifier inWorkflowStatus(WorkflowStatus _status) {
        require(workflowStatus == _status, "Function cannot be called at this time");
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        workflowStatus = WorkflowStatus.REGISTER_CANDIDATES;
    }

    function addAdmin(address account) public onlyAdmin {
        grantRole(ADMIN_ROLE, account);
    }

    function addFounder(address account) public onlyAdmin {
        grantRole(FOUNDER_ROLE, account);
    }

    function setWorkflowStatus(WorkflowStatus _status) public onlyAdmin {
        workflowStatus = _status;
        if (_status == WorkflowStatus.VOTE) {
            voteStartTime = block.timestamp;
        }
    }

    function addCandidate(string memory _name) public onlyAdmin inWorkflowStatus(WorkflowStatus.REGISTER_CANDIDATES) {
        require(bytes(_name).length > 0, "Candidate name cannot be empty");
        uint candidateId = candidateIds.length + 1;
        candidates[candidateId] = Candidate(candidateId, _name, 0, 0);
        candidateIds.push(candidateId);
    }

    function vote(uint _candidateId) public inWorkflowStatus(WorkflowStatus.VOTE) {
        require(block.timestamp >= voteStartTime + 1 hours, "Voting is not allowed yet. Please wait for 1 hour.");
        require(!voters[msg.sender], "You have already voted");
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");

        voters[msg.sender] = true;
        candidates[_candidateId].voteCount += 1;
    }

    function donateToCandidate(uint _candidateId) public payable onlyFounder {
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        require(msg.value > 0, "Donation amount must be greater than zero");

        candidates[_candidateId].fundsReceived += msg.value;
    }

    function getTotalVotes(uint _candidateId) public view returns (uint) {
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        return candidates[_candidateId].voteCount;
    }

    function getTotalFunds(uint _candidateId) public view returns (uint) {
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        return candidates[_candidateId].fundsReceived;
    }

    function getCandidatesCount() public view returns (uint) {
        return candidateIds.length;
    }

    function getCandidate(uint _candidateId) public view returns (Candidate memory) {
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        return candidates[_candidateId];
    }

    function designateWinner() public view inWorkflowStatus(WorkflowStatus.COMPLETED) returns (Candidate memory) {
        require(candidateIds.length > 0, "No candidates available");

        Candidate memory winner = candidates[candidateIds[0]];
        for (uint i = 1; i < candidateIds.length; i++) {
            if (candidates[candidateIds[i]].voteCount > winner.voteCount) {
                winner = candidates[candidateIds[i]];
            }
        }
        return winner;
    }
}
