// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {DelayedERC4626Oracle} from "../src/DelayedERC4626Oracle.sol";

import {MockERC20} from "./mock/MockERC20.sol";
import {MockERC4626} from "./mock/MockERC4626.sol";

library ERC4626Utils {
    function price(IERC4626 er4626) internal view returns (uint256) {
        uint256 factor = 10 ** er4626.decimals();
        return er4626.convertToAssets(factor);
    }
}

contract DelayedERC4626OracleTest is Test {
    using ERC4626Utils for IERC4626;

    DelayedERC4626Oracle public oracle;

    MockERC20 public erc20;
    IERC4626 public erc4626;

    uint256 DELAY = 5;

    function setUp() public {
        erc20 = new MockERC20();
        erc4626 = new MockERC4626(erc20);
        oracle = new DelayedERC4626Oracle(erc4626, DELAY);
    }

    function testDelay() public {
        assertEq(erc4626.price(), 1 ether, "Initially price should be 1 ether");

        assertEq(
            erc4626.price(),
            oracle.price(),
            "Initially price should be 1 for both"
        );

        erc20.mint(address(this), 2 ether);
        erc20.approve(address(erc4626), 2 ether);
        erc4626.deposit(2 ether, address(this));

        assertEq(erc4626.price(), 1 ether, "Price remain 1 ether");
        assertEq(
            erc4626.price(),
            oracle.price(),
            "Creation of ERC4626 shares doesn't change the price"
        );

        // Gift of 2 units to the ERC4626
        erc20.mint(address(erc4626), 2 ether + 1);
        assertEq(erc4626.price(), 2 ether, "Price is now 2 ether");
        assertEq(oracle.price(), 1 ether, "but oracle still reporting 1 ether");

        oracle.update();

        assertEq(
            oracle.price(),
            1 ether,
            "Oracle still reporting 1 ether due to delay"
        );
        assertEq(oracle.nextPrice(), 2 ether, "but next price will be 2 ether");
        assertEq(
            oracle.nextPriceBlock(),
            vm.getBlockNumber() + DELAY,
            "price will change in DELAY blocks"
        );

        vm.roll(vm.getBlockNumber() + DELAY - 1);

        assertEq(
            oracle.price(),
            1 ether,
            "DELAY-1 blocks is not enough to change price"
        );

        vm.roll(vm.getBlockNumber() + 1);

        assertEq(oracle.price(), 2 ether, "Oracle price is now 2 ether");

        // After a long long time
        vm.roll(vm.getBlockNumber() + 10_000_000_000);

        assertEq(oracle.price(), 2 ether, "Oracle price is still 2 ether");

        // Add a small amount to the erc4626 to detect price sensibility
        erc20.mint(address(erc4626), 200);

        assertEq(erc4626.price(), 2 ether + 99, "Price is now 2 ether + dust");

        // Forgot to update
        vm.roll(vm.getBlockNumber() + 1_000);
        assertEq(oracle.price(), 2 ether, "Oracle price is still 2 ether");

        // Finally update
        oracle.update();

        vm.roll(vm.getBlockNumber() + 1);
        assertEq(oracle.price(), 2 ether, "Oracle price is still 2 ether");

        vm.roll(vm.getBlockNumber() + 1);
        assertEq(
            oracle.price(),
            2 ether + 99,
            "Oracle price is now 2 ether + dust"
        );
    }
}
