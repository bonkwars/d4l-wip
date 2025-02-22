// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface ITournaments {
    struct TournamentConfig {
        uint96 entryFee;       // 12 bytes - Tournament entry fee
        uint96 prizePool;      // 12 bytes - Total prize pool
        uint32 startTime;      // 4 bytes  - Tournament start time
        uint32 endTime;        // 4 bytes  - Tournament end time
        uint16 maxPlayers;     // 2 bytes  - Maximum players allowed
        uint8 minLeague;      // 1 byte   - Minimum league required
        bool isPrivate;       // 1 byte   - Whether tournament is private
    }

    struct PlayerStats {
        uint96 score;          // 12 bytes - Player's tournament score
        uint96 earnings;       // 12 bytes - Total tournament earnings
        uint32 rank;           // 4 bytes  - Current tournament rank
        uint32 matchesPlayed;  // 4 bytes  - Number of matches played
        uint16 wins;           // 2 bytes  - Number of wins
        uint8 status;         // 1 byte   - Player status
        bool qualified;       // 1 byte   - Qualification status
    }

    struct TournamentState {
        uint96 currentPrize;   // 12 bytes - Current prize pool
        uint96 totalVolume;    // 12 bytes - Total trading volume
        uint32 playerCount;    // 4 bytes  - Number of players
        uint32 roundNumber;    // 4 bytes  - Current round number
        uint16 matchCount;     // 2 bytes  - Number of matches
        uint8 stage;          // 1 byte   - Tournament stage
        bool finalized;       // 1 byte   - Whether tournament is finalized
    }

    event TournamentCreated(
        uint256 indexed tournamentId,
        uint96 entryFee,
        uint96 prizePool,
        uint32 startTime,
        uint32 endTime
    );

    event PlayerRegistered(
        uint256 indexed tournamentId,
        address indexed player,
        uint96 entryFee,
        uint32 timestamp
    );

    event MatchCompleted(
        uint256 indexed tournamentId,
        uint32 indexed matchId,
        address indexed winner,
        uint96 score
    );

    event RewardDistributed(
        uint256 indexed tournamentId,
        address indexed player,
        uint96 amount,
        uint32 rank
    );

    /// @notice Creates a new tournament
    /// @param config Tournament configuration
    /// @return tournamentId ID of created tournament
    function createTournament(TournamentConfig calldata config) external returns (uint256 tournamentId);

    /// @notice Registers player for tournament
    /// @param tournamentId Tournament ID
    /// @param proof Qualification proof
    function registerPlayer(uint256 tournamentId, bytes calldata proof) external payable;

    /// @notice Records match result
    /// @param tournamentId Tournament ID
    /// @param matchId Match ID
    /// @param score Match score
    function recordMatchResult(uint256 tournamentId, uint32 matchId, uint96 score) external;

    /// @notice Claims tournament rewards
    /// @param tournamentId Tournament ID
    /// @return amount Amount of rewards claimed
    function claimTournamentRewards(uint256 tournamentId) external returns (uint96 amount);

    /// @notice Gets tournament configuration
    /// @param tournamentId Tournament ID
    function getTournamentConfig(uint256 tournamentId) external view returns (TournamentConfig memory);

    /// @notice Gets player's tournament stats
    /// @param tournamentId Tournament ID
    /// @param player Player address
    function getPlayerStats(uint256 tournamentId, address player) external view returns (PlayerStats memory);

    /// @notice Gets tournament state
    /// @param tournamentId Tournament ID
    function getTournamentState(uint256 tournamentId) external view returns (TournamentState memory);

    /// @notice Checks if player is qualified
    /// @param tournamentId Tournament ID
    /// @param player Player address
    function isQualified(uint256 tournamentId, address player) external view returns (bool);

    /// @notice Gets tournament leaderboard
    /// @param tournamentId Tournament ID
    /// @param count Number of entries
    /// @return players Array of player addresses
    /// @return scores Array of player scores
    function getLeaderboard(uint256 tournamentId, uint8 count) external view returns (
        address[] memory players,
        uint96[] memory scores
    );

    /// @notice Gets player's matches
    /// @param tournamentId Tournament ID
    /// @param player Player address
    /// @return matchIds Array of match IDs
    /// @return scores Array of match scores
    function getPlayerMatches(uint256 tournamentId, address player) external view returns (
        uint32[] memory matchIds,
        uint96[] memory scores
    );

    /// @notice Gets tournament schedule
    /// @param tournamentId Tournament ID
    /// @return startTimes Array of match start times
    /// @return opponents Array of opponent addresses
    function getSchedule(uint256 tournamentId) external view returns (
        uint32[] memory startTimes,
        address[] memory opponents
    );

    /// @notice Gets estimated rewards
    /// @param tournamentId Tournament ID
    /// @param player Player address
    /// @return estimated Estimated rewards
    /// @return minimum Minimum guaranteed rewards
    function getEstimatedRewards(uint256 tournamentId, address player) external view returns (
        uint96 estimated,
        uint96 minimum
    );
} 