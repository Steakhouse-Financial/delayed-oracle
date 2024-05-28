// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";

/// @title DelayedOracle wraps an underlying oracle and return the price in a delayed way
/// @notice The contract must be updated manually (pirce update) by calling the permissionless update function.
/// @dev Not all Chainlink interface behavior are implemented, all answers are always round 0.
contract DelayedOracle is AggregatorV3Interface {
    AggregatorV3Interface public immutable oracle;
    uint256 public immutable delay;

    int256 public prevPrice;
    int256 public nextPrice;
    uint256 public nextPriceBlock;

    constructor(AggregatorV3Interface oracle_, uint256 delay_) {
        oracle = oracle_;
        delay = delay_;
    }

    function update() public {
        require(
            block.number >= nextPriceBlock,
            "Can only update after the delay is passed"
        );
        prevPrice = nextPrice;
        (, nextPrice, , , ) = oracle.latestRoundData();
        nextPriceBlock = block.number + delay;
    }

    /// @notice
    /// @return price The previous price if delay is not passed yet, next price otherwise
    function price() public view returns (int256) {
        return (block.number >= nextPriceBlock) ? nextPrice : prevPrice;
    }

    /////////////////////////////////////////
    // AggregatorV3Interface implementation
    /////////////////////////////////////////

    function decimals() external view returns (uint8) {
        return oracle.decimals();
    }

    function description() external view returns (string memory) {
        return oracle.description();
    }

    function version() external view returns (uint256) {
        return oracle.version();
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        require(_roundId == 0, "Oracle doesn't track roundId");
        return (0, price(), 0, 0, 0);
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, price(), 0, 0, 0);
    }
}
