// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {AggregatorV3Interface} from "../src/interfaces/AggregatorV3Interface.sol";

import {DelayedOracle} from "../src/DelayedOracle.sol";

contract DelayedOracleTest is Test {
    DelayedOracle public oracle;
    AggregatorV3Interface public oracle;

    function setUp() public {}
}
