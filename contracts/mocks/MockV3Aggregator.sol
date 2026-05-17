// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";

contract MockV3Aggregator is AggregatorV3Interface {
    uint8 public immutable override decimals;
    string public override description;
    uint256 public override version;

    uint80 public latestRound;
    int256 internal answer;
    uint256 internal startedAt;
    uint256 internal updatedAt;

    constructor(uint8 decimals_, int256 initialAnswer) {
        decimals = decimals_;
        description = "Mock Chainlink Aggregator";
        version = 1;
        updateAnswer(initialAnswer);
    }

    function updateAnswer(int256 newAnswer) public {
        latestRound += 1;
        answer = newAnswer;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
    }

    function updateAnswerWithTimestamp(int256 newAnswer, uint256 timestamp) external {
        latestRound += 1;
        answer = newAnswer;
        startedAt = timestamp;
        updatedAt = timestamp;
    }

    function getRoundData(uint80 roundId)
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        require(roundId == latestRound, "MockV3Aggregator: no data");
        return (latestRound, answer, startedAt, updatedAt, latestRound);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (latestRound, answer, startedAt, updatedAt, latestRound);
    }
}
