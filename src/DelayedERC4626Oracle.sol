// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {MinimalERC4626} from "./interfaces/MinimalERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title DelayedOracle wraps an underlying IERC4626 and return the price in a delayed way
/// @notice The contract must be updated manually (price update) by calling the permissionless update function.
/// @dev Only implements what is needed from ERC4626 to be used in Morpho Oracle Factory V2
contract DelayedERC4626Oracle is MinimalERC4626 {
    event Update(uint256 nextPriceTimestamp, uint256 nextPrice);

    IERC4626 public immutable underlying;
    uint256 public immutable delay;

    uint256 public prevPrice;
    uint256 public nextPrice;
    uint256 public nextPriceTimestamp;

    uint256 private immutable underlyingFactor;

    /// @param underlying_ Underlying ERC4626 on which returning the conversion price with a delay
    /// @param delay_ delay in seconds
    constructor(IERC4626 underlying_, uint256 delay_) {
        underlying = underlying_;
        delay = delay_;
        underlyingFactor = 10 ** underlying.decimals();
        nextPrice = underlying.convertToAssets(underlyingFactor);
    }

    /// @notice Update the next price of the underlying ERC4626
    /// @dev You can't call this function until the previous delay is exhausted
    function update() public {
        require(
            block.timestamp >= nextPriceTimestamp,
            "Can only update after the delay is passed"
        );
        prevPrice = nextPrice;
        nextPrice = underlying.convertToAssets(underlyingFactor);
        nextPriceTimestamp = block.timestamp + delay;

        emit Update(nextPriceTimestamp, nextPrice);
    }

    /// @return price The previous price if delay is not passed yet, next price otherwise
    function price() public view returns (uint256) {
        return (block.timestamp >= nextPriceTimestamp) ? nextPrice : prevPrice;
    }

    /////////////////////////////////////////
    // MinimalERC4626 implementation
    /////////////////////////////////////////

    /// @dev Function that will be used by Morpho
    function convertToAssets(uint256 shares) external view returns (uint256) {
        return (price() * shares) / underlyingFactor;
    }
}
