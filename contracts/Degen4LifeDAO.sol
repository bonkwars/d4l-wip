// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";

import "@openzeppelin/contracts/governance/utils/Votes.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "./interfaces/IDegen4LifeController.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract Degen4LifeDAO is GovernorCountingSimple,  GovernorSettings, AccessControl {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    IDegen4LifeController public controller;
    
    struct DAOSettings {
        uint32 votingDelay;
        uint32 votingPeriod;
        uint32 proposalThreshold;
    }

   

    DAOSettings public settings;
    
    
    constructor(
        address _controller,
        string memory _name,
        DAOSettings memory _settings
    ) Governor(_name) GovernorSettings(
        _settings.votingDelay,
        _settings.votingPeriod,
        _settings.proposalThreshold
    ) {
        controller = IDegen4LifeController(_controller);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNANCE_ROLE, msg.sender);
    }

    function proposeParameterChange(
        address target,
        bytes32 parameter,
        uint256 newValue
    ) external onlyRole(GOVERNANCE_ROLE) returns (uint256) {
        address[] memory targets = new address[](1);
        targets[0] = target;
        
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "updateParameter(bytes32,uint256)", 
            parameter, 
            newValue
        );
        
        return propose(targets, new uint256[](0), calldatas, "Parameter change");
    }

    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function supportsInterface(bytes4 interfaceId) public view override(Governor, AccessControl) returns (bool) {
        return Governor.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }

    function quorum(uint256 blockNumber) public pure override returns (uint256) {
        return 0;
    }

    function COUNTING_MODE() public pure override(GovernorCountingSimple, IGovernor) returns (string memory) {
        return "support=bravo&quorum=forwards,abstain";
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }



    function _getVotes(
        address account,
        uint256 timepoint,
        bytes memory params
    ) internal view override returns (uint256) {
        // Retrieve voting power from the controller
        return IVotes(address(controller)).getVotes(account);
    }

    function _quorumReached(uint256 proposalId) internal view override(GovernorCountingSimple, Governor) returns (bool) {
        // Use the ProposalVotes struct directly from GovernorCountingSimple
       (  uint256 againstVotes,
        uint256 forVotes,
        uint256 abstainVotes) = proposalVotes(proposalId);
        uint256 totalVotes = forVotes + againstVotes + abstainVotes;
        return totalVotes >= quorum(block.number);
    }

  

    function _voteSucceeded(uint256 proposalId) internal view override(GovernorCountingSimple, Governor) returns (bool) {
        // Check if the proposal has enough support
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = super.proposalVotes(proposalId);
        return forVotes > againstVotes;
    }

    function hasVoted(uint256 proposalId, address account) public view override(GovernorCountingSimple, IGovernor) returns (bool) {
        return super.hasVoted(proposalId, account);
    }
} 