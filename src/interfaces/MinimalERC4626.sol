// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface MinimalERC4626 {
    function convertToAssets(uint256) external view returns (uint256);
}
