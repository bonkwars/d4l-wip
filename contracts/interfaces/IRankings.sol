// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

interface IRankings {
    struct RankInfo {
        uint96 score;          // 12 bytes - User's score
        uint32 rank;           // 4 bytes  - Current rank
        uint32 bestRank;       // 4 bytes  - Best rank achieved
        uint32 lastUpdate;     // 4 bytes  - Last rank update
        uint16 percentile;     // 2 bytes  - Current percentile
        uint8 league;         // 1 byte   - Current league
        bool qualified;       // 1 byte   - Tournament qualification
    }

    struct LeagueInfo {
        uint96 minScore;       // 12 bytes - Minimum score required
        uint96 prizePool;      // 12 bytes - Current prize pool
        uint32 participants;   // 4 bytes  - Number of participants
        uint32 season;         // 4 bytes  - Current season
        uint16 rewards;        // 2 bytes  - Reward multiplier
        uint8 level;          // 1 byte   - League level
        bool active;          // 1 byte   - Whether league is active
    }

    struct SeasonStats {
        uint96 totalVolume;    // 12 bytes - Total trading volume
        uint96 totalRewards;   // 12 bytes - Total rewards distributed
        uint32 startTime;      // 4 bytes  - Season start time
        uint32 endTime;        // 4 bytes  - Season end time
        uint32 participants;   // 4 bytes  - Total participants
        uint16 topPercent;     // 2 bytes  - Top performer percentage
        uint8 currentLeague;  // 1 byte   - Current league level
        bool finalized;       // 1 byte   - Whether season is finalized
    }

    event RankUpdated(
        address indexed user,
        uint32 newRank,
        uint32 oldRank,
        uint96 score
    );

    event LeaguePromoted(
        address indexed user,
        uint8 newLeague,
        uint8 oldLeague,
        uint96 score
    );

    event SeasonFinalized(
        uint32 season,
        uint96 totalRewards,
        uint32 participants
    );

    event RewardDistributed(
        address indexed user,
        uint96 amount,
        uint8 league,
        uint32 rank
    );

    /// @notice Updates user's ranking
    /// @param user User address
    /// @param score New score
    /// @return newRank Updated rank
    function updateRank(address user, uint96 score) external returns (uint32 newRank);

    /// @notice Processes league promotions/demotions
    /// @param user User address
    /// @return newLeague New league level
    function processLeagueChange(address user) external returns (uint8 newLeague);

    /// @notice Claims season rewards
    /// @param season Season number
    /// @return amount Amount of rewards claimed
    function claimSeasonRewards(uint32 season) external returns (uint96 amount);

    /// @notice Gets user's ranking info
    /// @param user User address
    function getRankInfo(address user) external view returns (RankInfo memory);

    /// @notice Gets league information
    /// @param league League level
    function getLeagueInfo(uint8 league) external view returns (LeagueInfo memory);

    /// @notice Gets season statistics
    /// @param season Season number
    function getSeasonStats(uint32 season) external view returns (SeasonStats memory);

    /// @notice Gets user's league eligibility
    /// @param user User address
    /// @param league League level
    function isEligibleForLeague(address user, uint8 league) external view returns (bool);

    /// @notice Gets top ranked users in a league
    /// @param league League level
    /// @param count Number of entries
    /// @return users Array of user addresses
    /// @return scores Array of user scores
    function getLeagueTopRanked(uint8 league, uint8 count) external view returns (
        address[] memory users,
        uint96[] memory scores
    );

    /// @notice Gets user's percentile
    /// @param user User address
    /// @return percentile User's percentile
    /// @return total Total participants
    function getUserPercentile(address user) external view returns (
        uint16 percentile,
        uint32 total
    );

    /// @notice Gets season rewards estimate
    /// @param user User address
    /// @param season Season number
    /// @return estimated Estimated rewards
    /// @return minimum Minimum guaranteed rewards
    function getEstimatedRewards(address user, uint32 season) external view returns (
        uint96 estimated,
        uint96 minimum
    );

    /// @notice Gets league requirements
    /// @param league League level
    /// @return minScore Minimum score required
    /// @return minRank Minimum rank required
    /// @return duration Minimum duration required
    function getLeagueRequirements(uint8 league) external view returns (
        uint96 minScore,
        uint32 minRank,
        uint32 duration
    );
} 