// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

import "../interfaces/IRankings.sol";
import "solmate/src/auth/Owned.sol";
import "solmate/src/utils/SafeTransferLib.sol";
import "solmate/src/utils/FixedPointMathLib.sol";
import "../constants/constants.sol";

abstract contract AbstractRankings is IRankings, Owned {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    // Constants for rankings and leagues
    uint8 constant MAX_LEAGUES = 5;
    uint16 constant PROMOTION_THRESHOLD_BPS = 1000; // Top 10%
    uint16 constant DEMOTION_THRESHOLD_BPS = 8000; // Bottom 80%
    uint32 constant SEASON_DURATION = 30 days;

    // Packed storage for ranking data
    mapping(address => RankInfo) private _rankings;
    mapping(uint8 => LeagueInfo) private _leagues;
    mapping(uint32 => SeasonStats) private _seasons;
    
    // Efficient mappings for user data
    mapping(uint32 => mapping(address => bool)) private _seasonParticipants;
    mapping(uint32 => mapping(uint8 => address[])) private _leagueRankings;
    mapping(uint32 => mapping(address => uint96)) private _seasonRewards;
    
    // Season tracking
    uint32 public currentSeason;
    uint32 public seasonStartTime;
    
    constructor() Owned(msg.sender) {
        _initializeLeagues();
        _startNewSeason();
    }

    /// @notice Updates user's ranking
    function updateRank(
        address user,
        uint96 score
    ) external override returns (uint32 newRank) {
        require(score > 0, "Invalid score");
        
        RankInfo storage info = _rankings[user];
        uint32 oldRank = info.rank;
        
        // Update user's score and rank
        info.score = score;
        info.lastUpdate = uint32(block.timestamp);
        
        // Calculate new rank
        newRank = _calculateNewRank(user, score);
        info.rank = newRank;
        
        if (newRank < info.bestRank || info.bestRank == 0) {
            info.bestRank = newRank;
        }
        
        // Update league rankings
        _updateLeagueRankings(user, score, info.league);
        
        emit RankUpdated(user, newRank, oldRank, score);
        return newRank;
    }

    /// @notice Processes league changes
    function processLeagueChange(
        address user
    ) external override returns (uint8 newLeague) {
        RankInfo storage info = _rankings[user];
        uint8 oldLeague = info.league;
        
        // Check promotion/demotion criteria
        newLeague = _calculateLeagueChange(info);
        if (newLeague != oldLeague) {
            info.league = newLeague;
            emit LeaguePromoted(user, newLeague, oldLeague, info.score);
        }
        
        return newLeague;
    }

    /// @notice Claims season rewards
    function claimSeasonRewards(
        uint32 season
    ) external override returns (uint96 amount) {
        require(season < currentSeason, "Season not ended");
        require(_seasonParticipants[season][msg.sender], "Not participated");
        
        amount = _seasonRewards[season][msg.sender];
        require(amount > 0, "No rewards");
        
        _seasonRewards[season][msg.sender] = 0;
        _processRewardTransfer(msg.sender, amount);
        
        emit RewardDistributed(
            msg.sender,
            amount,
            _rankings[msg.sender].league,
            _rankings[msg.sender].rank
        );
        
        return amount;
    }

    // View functions
    function getRankInfo(
        address user
    ) external view override returns (RankInfo memory) {
        return _rankings[user];
    }

    function getLeagueInfo(
        uint8 league
    ) external view override returns (LeagueInfo memory) {
        return _leagues[league];
    }

    function getSeasonStats(
        uint32 season
    ) external view override returns (SeasonStats memory) {
        return _seasons[season];
    }

    function isEligibleForLeague(
        address user,
        uint8 league
    ) external view override returns (bool) {
        RankInfo storage info = _rankings[user];
        LeagueInfo storage leagueInfo = _leagues[league];
        
        return info.score >= leagueInfo.minScore;
    }

    function getLeagueTopRanked(
        uint8 league,
        uint8 count
    ) external view override returns (
        address[] memory users,
        uint96[] memory scores
    ) {
        address[] storage leagueUsers = _leagueRankings[currentSeason][league];
        uint256 resultCount = count > leagueUsers.length ? leagueUsers.length : count;
        
        users = new address[](resultCount);
        scores = new uint96[](resultCount);
        
        for (uint256 i = 0; i < resultCount; i++) {
            users[i] = leagueUsers[i];
            scores[i] = _rankings[leagueUsers[i]].score;
        }
        
        return (users, scores);
    }

    function getUserPercentile(
        address user
    ) external view override returns (uint16 percentile, uint32 total) {
        RankInfo storage info = _rankings[user];
        LeagueInfo storage league = _leagues[info.league];
        
        total = league.participants;
        if (total == 0) return (0, 0);
        
        percentile = uint16((uint256(info.rank) * 10000) / total);
        return (percentile, total);
    }

    function getEstimatedRewards(
        address user,
        uint32 season
    ) external view override returns (uint96 estimated, uint96 minimum) {
        if (!_seasonParticipants[season][user]) return (0, 0);
        
        RankInfo storage info = _rankings[user];
        LeagueInfo storage league = _leagues[info.league];
        
        minimum = uint96((league.prizePool * league.rewards) / 10000);
        estimated = uint96(_calculateEstimatedRewards(info, league));
        
        return (estimated, minimum);
    }

    function getLeagueRequirements(
        uint8 league
    ) external view override returns (
        uint96 minScore,
        uint32 minRank,
        uint32 duration
    ) {
        LeagueInfo storage leagueInfo = _leagues[league];
        return (
            leagueInfo.minScore,
            uint32((leagueInfo.participants * PROMOTION_THRESHOLD_BPS) / 10000),
            SEASON_DURATION
        );
    }

    // Internal functions
    function _initializeLeagues() internal virtual {
        // Implementation specific
    }

    function _startNewSeason() internal virtual {
        currentSeason++;
        seasonStartTime = uint32(block.timestamp);
        
        // Initialize season stats
        _seasons[currentSeason] = SeasonStats({
            totalVolume: 0,
            totalRewards: 0,
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + SEASON_DURATION),
            participants: 0,
            topPercent: 0,
            currentLeague: 1,
            finalized: false
        });
    }

    function _calculateNewRank(
        address user,
        uint96 score
    ) internal view virtual returns (uint32) {
        // Implementation specific
        return 0;
    }

    function _updateLeagueRankings(
        address user,
        uint96 score,
        uint8 league
    ) internal virtual {
        // Implementation specific
    }

    function _calculateLeagueChange(
        RankInfo storage info
    ) internal view virtual returns (uint8) {
        // Implementation specific
        return info.league;
    }

    function _calculateEstimatedRewards(
        RankInfo storage info,
        LeagueInfo storage league
    ) internal view virtual returns (uint256) {
        return (uint256(league.prizePool) * league.rewards * 
            (10000 - info.percentile)) / (10000 * 10000);
    }

    function _processRewardTransfer(
        address user,
        uint96 amount
    ) internal virtual {
        // Implementation specific
    }
} 