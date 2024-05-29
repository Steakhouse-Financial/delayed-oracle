// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {MinimalERC4626} from "./interfaces/MinimalERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title DelayedOracle wraps an underlying IERC4626 and return the price in a delayed way
/// @notice The contract must be updated manually (price update) by calling the permissionless update function.
/// @dev Only implements what is needed from ERC4626 to be used in Morpho Oracle Factory V2
contract DelayedERC4626Oracle is MinimalERC4626 {
    IERC4626 public immutable underlying;
    uint256 public immutable delay;

    uint256 public prevPrice;
    uint256 public nextPrice;
    uint256 public nextPriceBlock;

    uint256 private immutable underlyingFactor;

    constructor(IERC4626 underlying_, uint256 delay_) {
        underlying = underlying_;
        delay = delay_;
        underlyingFactor = 10 ** underlying.decimals();
        nextPrice = underlying.convertToAssets(underlyingFactor);
    }

    function update() public {
        require(
            block.number >= nextPriceBlock,
            "Can only update after the delay is passed"
        );
        prevPrice = nextPrice;
        nextPrice = underlying.convertToAssets(underlyingFactor);
        nextPriceBlock = block.number + delay;
    }

    /// @notice
    /// @return price The previous price if delay is not passed yet, next price otherwise
    function price() public view returns (uint256) {
        return (block.number >= nextPriceBlock) ? nextPrice : prevPrice;
    }

    /////////////////////////////////////////
    // MinimalERC4626 implementation
    /////////////////////////////////////////
    function convertToAssets(uint256 shares) external view returns (uint256) {
        return (price() * shares) / underlyingFactor;
    }
}
