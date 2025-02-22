// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface IGovernance {
    struct Proposal {
        uint32 id;              // Proposal ID
        address proposer;       // Address of the proposer
        uint32 startTime;       // Start time of voting
        uint32 endTime;        // End time of voting
        uint32 executionTime;  // Time when proposal was executed
        uint16 quorum;         // Required quorum in basis points (e.g., 5000 = 50%)
        uint16 threshold;      // Required threshold in basis points
        bool executed;         // Whether the proposal has been executed
        bool canceled;         // Whether the proposal has been canceled
        bytes32 descriptionHash; // Hash of proposal description (IPFS)
        bytes[] actions;       // Encoded actions to execute
    }

    struct Vote {
        bool support;          // Whether the vote is in favor
        uint256 weight;        // Voting weight
        uint32 timestamp;      // When the vote was cast
    }

    struct ProposalVotes {
        uint256 forVotes;      // Total votes in favor
        uint256 againstVotes;  // Total votes against
        uint32 voterCount;     // Number of voters
    }

    event ProposalCreated(
        uint32 indexed id,
        address indexed proposer,
        uint32 startTime,
        uint32 endTime,
        string description
    );

    event ProposalExecuted(uint32 indexed id);
    event ProposalCanceled(uint32 indexed id);
    event VoteCast(
        address indexed voter,
        uint32 indexed proposalId,
        bool support,
        uint256 weight
    );

    /// @notice Creates a new proposal
    /// @param description Proposal description (IPFS hash)
    /// @param actions Encoded actions to execute
    /// @param startTime Start time of voting period
    /// @param endTime End time of voting period
    /// @return id The ID of the created proposal
    function createProposal(
        string calldata description,
        bytes[] calldata actions,
        uint32 startTime,
        uint32 endTime
    ) external returns (uint32 id);

    /// @notice Casts a vote on a proposal
    /// @param proposalId The proposal ID
    /// @param support Whether to support the proposal
    function castVote(uint32 proposalId, bool support) external;

    /// @notice Casts a vote with signature
    /// @param proposalId The proposal ID
    /// @param support Whether to support the proposal
    /// @param signature The signature of the vote
    function castVoteWithSig(
        uint32 proposalId,
        bool support,
        bytes calldata signature
    ) external;

    /// @notice Executes a successful proposal
    /// @param proposalId The proposal ID
    function executeProposal(uint32 proposalId) external;

    /// @notice Cancels a proposal
    /// @param proposalId The proposal ID
    function cancelProposal(uint32 proposalId) external;

    /// @notice Gets a proposal by ID
    /// @param proposalId The proposal ID
    function getProposal(uint32 proposalId) external view returns (Proposal memory);

    /// @notice Gets the voting weight of an account at a specific time
    /// @param account The account address
    /// @param timestamp The timestamp to check
    function getVotingWeight(address account, uint256 timestamp) external view returns (uint256);

    /// @notice Gets the votes for a proposal
    /// @param proposalId The proposal ID
    function getProposalVotes(uint32 proposalId) external view returns (ProposalVotes memory);

    /// @notice Gets a specific vote on a proposal
    /// @param proposalId The proposal ID
    /// @param voter The voter address
    function getVote(uint32 proposalId, address voter) external view returns (Vote memory);

    /// @notice Checks if a proposal is active
    /// @param proposalId The proposal ID
    function isProposalActive(uint32 proposalId) external view returns (bool);

    /// @notice Checks if a proposal has succeeded
    /// @param proposalId The proposal ID
    function hasProposalSucceeded(uint32 proposalId) external view returns (bool);

    /// @notice Gets the voting delay (time between creation and start)
    function votingDelay() external view returns (uint32);

    /// @notice Gets the voting period duration
    function votingPeriod() external view returns (uint32);

    /// @notice Gets the proposal threshold (min voting weight to create proposal)
    function proposalThreshold() external view returns (uint256);

    /// @notice Gets the quorum requirement (min participation)
    function quorumNumerator() external view returns (uint16);
} 