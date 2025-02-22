// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Degen4Life
pragma solidity ^0.8.20;

import "../interfaces/ITournaments.sol";
import "solmate/src/auth/Owned.sol";
import "solmate/src/utils/SafeTransferLib.sol";
import "solmate/src/utils/FixedPointMathLib.sol";
import "../constants.sol";

abstract contract AbstractTournaments is ITournaments, Owned {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    // Constants for tournaments
    uint32 constant MIN_TOURNAMENT_DURATION = 1 hours;
    uint32 constant MAX_TOURNAMENT_DURATION = 30 days;
    uint16 constant MIN_PLAYERS = 2;
    uint16 constant MAX_PLAYERS = 1000;
    uint96 constant MIN_PRIZE_POOL = 100e18; // 100 tokens minimum

    // Packed storage for tournament data
    mapping(uint256 => TournamentConfig) private _tournamentConfigs;
    mapping(uint256 => TournamentState) private _tournamentStates;
    mapping(uint256 => mapping(address => PlayerStats)) private _playerStats;
    
    // Efficient mappings for tournament data
    mapping(uint256 => mapping(uint32 => address)) private _matchWinners;
    mapping(uint256 => mapping(address => uint32[])) private _playerMatches;
    mapping(uint256 => mapping(address => uint96[])) private _matchScores;
    mapping(uint256 => address[]) private _tournamentPlayers;
    
    // Tournament tracking
    uint256 private _tournamentCounter;
    mapping(uint256 => uint32[]) private _matchSchedule;
    mapping(uint256 => mapping(uint32 => address[2])) private _matchPairings;

    constructor() Owned(msg.sender) {}

    /// @notice Creates a new tournament
    function createTournament(
        TournamentConfig calldata config
    ) external override returns (uint256 tournamentId) {
        require(config.endTime > config.startTime + MIN_TOURNAMENT_DURATION, "Duration too short");
        require(config.endTime <= config.startTime + MAX_TOURNAMENT_DURATION, "Duration too long");
        require(config.maxPlayers >= MIN_PLAYERS && config.maxPlayers <= MAX_PLAYERS, "Invalid player count");
        require(config.prizePool >= MIN_PRIZE_POOL, "Prize pool too small");

        tournamentId = ++_tournamentCounter;
        _tournamentConfigs[tournamentId] = config;
        
        _initializeTournament(tournamentId);
        
        emit TournamentCreated(
            tournamentId,
            config.entryFee,
            config.prizePool,
            config.startTime,
            config.endTime
        );
        
        return tournamentId;
    }

    /// @notice Registers player for tournament
    function registerPlayer(
        uint256 tournamentId,
        bytes calldata proof
    ) external payable override {
        TournamentConfig storage config = _tournamentConfigs[tournamentId];
        TournamentState storage state = _tournamentStates[tournamentId];
        
        require(block.timestamp < config.startTime, "Registration closed");
        require(state.playerCount < config.maxPlayers, "Tournament full");
        require(msg.value == config.entryFee, "Invalid entry fee");
        require(_verifyQualification(tournamentId, msg.sender, proof), "Not qualified");
        
        // Initialize player stats
        _playerStats[tournamentId][msg.sender] = PlayerStats({
            score: 0,
            earnings: 0,
            rank: 0,
            matchesPlayed: 0,
            wins: 0,
            status: 1,
            qualified: true
        });
        
        // Update tournament state
        state.playerCount++;
        _tournamentPlayers[tournamentId].push(msg.sender);
        
        emit PlayerRegistered(
            tournamentId,
            msg.sender,
            config.entryFee,
            uint32(block.timestamp)
        );
    }

    /// @notice Records match result
    function recordMatchResult(
        uint256 tournamentId,
        uint32 matchId,
        uint96 score
    ) external override {
        TournamentState storage state = _tournamentStates[tournamentId];
        require(state.stage == 1, "Tournament not active");
        require(_isValidMatch(tournamentId, matchId, msg.sender), "Invalid match");
        
        // Update match result
        _matchWinners[tournamentId][matchId] = msg.sender;
        _playerMatches[tournamentId][msg.sender].push(matchId);
        _matchScores[tournamentId][msg.sender].push(score);
        
        // Update player stats
        PlayerStats storage stats = _playerStats[tournamentId][msg.sender];
        stats.score += score;
        stats.matchesPlayed++;
        stats.wins++;
        
        emit MatchCompleted(tournamentId, matchId, msg.sender, score);
        
        // Check if tournament round is complete
        if (_isRoundComplete(tournamentId)) {
            _advanceRound(tournamentId);
        }
    }

    /// @notice Claims tournament rewards
    function claimTournamentRewards(
        uint256 tournamentId
    ) external override returns (uint96 amount) {
        TournamentState storage state = _tournamentStates[tournamentId];
        require(state.finalized, "Tournament not finalized");
        
        PlayerStats storage stats = _playerStats[tournamentId][msg.sender];
        require(stats.qualified && stats.earnings > 0, "No rewards to claim");
        
        amount = stats.earnings;
        stats.earnings = 0;
        
        _processRewardTransfer(msg.sender, amount);
        
        emit RewardDistributed(
            tournamentId,
            msg.sender,
            amount,
            stats.rank
        );
        
        return amount;
    }

    // View functions
    function getTournamentConfig(
        uint256 tournamentId
    ) external view override returns (TournamentConfig memory) {
        return _tournamentConfigs[tournamentId];
    }

    function getPlayerStats(
        uint256 tournamentId,
        address player
    ) external view override returns (PlayerStats memory) {
        return _playerStats[tournamentId][player];
    }

    function getTournamentState(
        uint256 tournamentId
    ) external view override returns (TournamentState memory) {
        return _tournamentStates[tournamentId];
    }

    function isQualified(
        uint256 tournamentId,
        address player
    ) external view override returns (bool) {
        return _playerStats[tournamentId][player].qualified;
    }

    function getLeaderboard(
        uint256 tournamentId,
        uint8 count
    ) external view override returns (
        address[] memory players,
        uint96[] memory scores
    ) {
        uint256 totalPlayers = _tournamentPlayers[tournamentId].length;
        uint256 resultCount = count > totalPlayers ? totalPlayers : count;
        
        players = new address[](resultCount);
        scores = new uint96[](resultCount);
        
        for (uint256 i = 0; i < resultCount; i++) {
            address player = _tournamentPlayers[tournamentId][i];
            players[i] = player;
            scores[i] = _playerStats[tournamentId][player].score;
        }
        
        return (players, scores);
    }

    function getPlayerMatches(
        uint256 tournamentId,
        address player
    ) external view override returns (
        uint32[] memory matchIds,
        uint96[] memory scores
    ) {
        matchIds = _playerMatches[tournamentId][player];
        scores = _matchScores[tournamentId][player];
        return (matchIds, scores);
    }

    function getSchedule(
        uint256 tournamentId
    ) external view override returns (
        uint32[] memory startTimes,
        address[] memory opponents
    ) {
        uint32[] storage schedule = _matchSchedule[tournamentId];
        startTimes = new uint32[](schedule.length);
        opponents = new address[](schedule.length);
        
        for (uint256 i = 0; i < schedule.length; i++) {
            startTimes[i] = schedule[i];
            address[2] storage pairing = _matchPairings[tournamentId][schedule[i]];
            opponents[i] = pairing[1]; // Opponent is second player in pairing
        }
        
        return (startTimes, opponents);
    }

    function getEstimatedRewards(
        uint256 tournamentId,
        address player
    ) external view override returns (uint96 estimated, uint96 minimum) {
        TournamentConfig storage config = _tournamentConfigs[tournamentId];
        PlayerStats storage stats = _playerStats[tournamentId][player];
        
        if (!stats.qualified) return (0, 0);
        
        // Minimum is entry fee return
        minimum = config.entryFee;
        
        // Estimate based on current rank and prize pool
        if (stats.rank > 0) {
            estimated = _calculateReward(
                config.prizePool,
                stats.rank,
                _tournamentStates[tournamentId].playerCount
            );
        }
        
        return (estimated, minimum);
    }

    // Internal functions
    function _initializeTournament(uint256 tournamentId) internal virtual {
        _tournamentStates[tournamentId] = TournamentState({
            currentPrize: 0,
            totalVolume: 0,
            playerCount: 0,
            roundNumber: 0,
            matchCount: 0,
            stage: 0,
            finalized: false
        });
    }

    function _verifyQualification(
        uint256 tournamentId,
        address player,
        bytes calldata proof
    ) internal view virtual returns (bool) {
        // Implementation specific
        return false;
    }

    function _isValidMatch(
        uint256 tournamentId,
        uint32 matchId,
        address player
    ) internal view virtual returns (bool) {
        // Implementation specific
        return false;
    }

    function _isRoundComplete(
        uint256 tournamentId
    ) internal view virtual returns (bool) {
        // Implementation specific
        return false;
    }

    function _advanceRound(uint256 tournamentId) internal virtual {
        // Implementation specific
    }

    function _calculateReward(
        uint96 prizePool,
        uint32 rank,
        uint32 totalPlayers
    ) internal pure virtual returns (uint96) {
        // Implementation specific
        return 0;
    }

    function _processRewardTransfer(
        address player,
        uint96 amount
    ) internal virtual {
        // Implementation specific
    }
} 