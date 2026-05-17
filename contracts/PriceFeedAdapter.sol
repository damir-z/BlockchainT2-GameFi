// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";

/// @title PriceFeedAdapter
/// @notice Chainlink price feed adapter with staleness protection.
contract PriceFeedAdapter is AccessControl {
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

    AggregatorV3Interface public immutable feed;
    uint256 public maxStaleness;

    event MaxStalenessUpdated(uint256 oldMaxStaleness, uint256 newMaxStaleness);

    constructor(AggregatorV3Interface feed_, uint256 maxStaleness_, address admin) {
        require(address(feed_) != address(0), "PriceFeedAdapter: zero feed");
        require(maxStaleness_ != 0, "PriceFeedAdapter: zero staleness");
        require(admin != address(0), "PriceFeedAdapter: zero admin");
        feed = feed_;
        maxStaleness = maxStaleness_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONFIG_ROLE, admin);
    }

    function latestPrice() external view returns (int256 price, uint8 decimals_, uint256 updatedAt) {
        (, int256 answer,, uint256 updatedAt_,) = feed.latestRoundData();
        require(answer > 0, "PriceFeedAdapter: invalid price");
        require(updatedAt_ != 0, "PriceFeedAdapter: incomplete round");
        require(block.timestamp - updatedAt_ <= maxStaleness, "PriceFeedAdapter: stale price");
        return (answer, feed.decimals(), updatedAt_);
    }

    function setMaxStaleness(uint256 newMaxStaleness) external onlyRole(CONFIG_ROLE) {
        require(newMaxStaleness != 0, "PriceFeedAdapter: zero staleness");
        uint256 old = maxStaleness;
        maxStaleness = newMaxStaleness;
        emit MaxStalenessUpdated(old, newMaxStaleness);
    }
}
