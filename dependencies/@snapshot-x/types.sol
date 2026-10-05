// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

enum FinalizationStatus {
    Pending,
    Executed,
    Cancelled
}

struct Proposal {
    address author;
    uint32 startBlockNumber;
    address executionStrategy;
    uint32 minEndBlockNumber;
    uint32 maxEndBlockNumber;
    FinalizationStatus finalizationStatus;
    bytes32 executionPayloadHash;
    uint256 activeVotingStrategies;
}
