// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IMorpho, MarketParams, Id, Position} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IIrm} from "../lib/morpho-blue/src/interfaces/IIrm.sol";
import {MorphoChainlinkOracleV2} from "../lib/morpho-blue-oracles/src/morpho-chainlink/MorphoChainlinkOracleV2.sol";
import {MorphoChainlinkOracleV2Factory} from "../lib/morpho-blue-oracles/src/morpho-chainlink/MorphoChainlinkOracleV2Factory.sol";
import {AggregatorV3Interface} from "../lib/morpho-blue-oracles/src/morpho-chainlink/interfaces/AggregatorV3Interface.sol";
import {IERC4626 as MorphoIERC4626} from "../lib/morpho-blue-oracles/src/morpho-chainlink/interfaces/IERC4626.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";

import {DelayedERC4626Oracle} from "../src/DelayedERC4626Oracle.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC4626} from "./mock/MockERC4626.sol";

contract DelayedERC4626OracleMorphoIntegrationTest is Test {
    using MarketParamsLib for MarketParams;

    DelayedERC4626Oracle oracle;

    MockERC20 erc20;
    IERC4626 erc4626;

    uint256 DELAY = 5;

    // For Morpho integration tests
    IMorpho morpho;
    MorphoChainlinkOracleV2Factory factory;
    MorphoChainlinkOracleV2 marketOracle;
    IIrm irm;
    MarketParams marketParams;
    uint256 lltv;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        erc20 = new MockERC20();
        erc4626 = new MockERC4626(erc20);
        oracle = new DelayedERC4626Oracle(erc4626, DELAY);

        // Morpho setup
        morpho = IMorpho(address(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb));
        irm = IIrm(address(0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC));
        factory = new MorphoChainlinkOracleV2Factory();

        marketOracle = factory.createMorphoChainlinkOracleV2(
            MorphoIERC4626(address(0)),
            1,
            AggregatorV3Interface(address(0)),
            AggregatorV3Interface(address(0)),
            18,
            MorphoIERC4626(address(oracle)),
            1 ether,
            AggregatorV3Interface(address(0)),
            AggregatorV3Interface(address(0)),
            18,
            bytes32(0)
        );

        // low lltv chosen so we can double the ERC4626 price
        lltv = 385000000000000000;
        marketParams = MarketParams(
            address(erc4626),
            address(erc20),
            address(marketOracle),
            address(irm),
            lltv
        );

        morpho.createMarket(marketParams);

        // Create 10 erc20 and 1 erc4626
        erc20.mint(address(this), 12 ether);
        erc20.approve(address(erc4626), type(uint256).max);
        erc4626.deposit(2 ether, address(this));

        // We approve Morpho for both erc20 and erc4626
        erc20.approve(address(morpho), type(uint256).max);
        erc4626.approve(address(morpho), type(uint256).max);
    }

    /// @notice Shows that liquidations work fine with the interest accruing
    function testLiquidationFromInterests() public {
        morpho.supply(marketParams, 1 ether, 0, address(this), "");

        morpho.supplyCollateral(marketParams, 1 ether, address(this), "");

        morpho.borrow(
            marketParams,
            0.385 ether,
            0,
            address(this),
            address(this)
        );

        Position memory p = morpho.position(marketParams.id(), address(this));
        assertGt(p.borrowShares, 0, "Some borrow position");

        // Position is healthy at this stage
        vm.expectRevert();
        morpho.liquidate(marketParams, address(this), 0, p.borrowShares, "");

        // Move forward 1 second in time so we can liquidate
        vm.warp(vm.getBlockTimestamp() + 1);

        morpho.liquidate(marketParams, address(this), 0, p.borrowShares, "");

        p = morpho.position(marketParams.id(), address(this));
        assertEq(p.borrowShares, 0, "No more borrow position");
    }

    /// @notice Shows that liquidations work fine with the erc4626 increasing in price
    function testLiquidationFromGift() public {
        morpho.supply(marketParams, 1 ether, 0, address(this), "");

        morpho.supplyCollateral(marketParams, 1 ether, address(this), "");

        morpho.borrow(
            marketParams,
            0.30 ether, // We let room for some interest to accrue
            0,
            address(this),
            address(this)
        );

        Position memory p = morpho.position(marketParams.id(), address(this));
        assertGt(p.borrowShares, 0, "Some borrow position");

        // Position is healthy at this stage
        vm.expectRevert();
        morpho.liquidate(marketParams, address(this), 0, p.borrowShares, "");

        // Will double the unit price of erc4626
        erc20.transfer(address(erc4626), 2 ether + 1); // +1 due to the 1 virtual share of ERC4626 impl

        oracle.update();
        assertEq(oracle.price(), 1 ether, "Price unchanged for now");

        // SHouldn't allow liquidation yet
        vm.expectRevert();
        morpho.liquidate(marketParams, address(this), 0, p.borrowShares, "");

        // Make sure that 29 block later it's still not good.
        vm.warp(vm.getBlockTimestamp() + DELAY - 1);

        assertEq(oracle.price(), 1 ether, "Price unchanged for now");

        // SHouldn't allow liquidation yet
        vm.expectRevert();
        morpho.liquidate(marketParams, address(this), 0, p.borrowShares, "");

        // But after DELAY + 1 block it can be liquidated as price increased
        vm.warp(vm.getBlockTimestamp() + 1);

        assertEq(oracle.price(), 2 ether, "Price updated");

        // Shouldn't allow liquidation yet
        morpho.liquidate(marketParams, address(this), 0, p.borrowShares, "");

        p = morpho.position(marketParams.id(), address(this));
        assertEq(p.borrowShares, 0, "No more borrow position");
    }
}
