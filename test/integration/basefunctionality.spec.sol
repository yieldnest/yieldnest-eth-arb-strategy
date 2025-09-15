// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {BaseIntegrationTest} from "./BaseIntegrationTest.sol";
import {TransparentUpgradeableProxy} from
    "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UpgradeUtils} from "lib/yieldnest-flex-strategy/script/UpgradeUtils.sol";
import {AccountingModule, IAccountingModule} from "lib/yieldnest-flex-strategy/src/AccountingModule.sol";
import {AccountingToken} from "lib/yieldnest-flex-strategy/src/AccountingToken.sol";
import {FlexStrategy} from "lib/yieldnest-flex-strategy/src/FlexStrategy.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DeployFlexStrategy, RewardsSweeper} from "lib/yieldnest-flex-strategy/script/DeployFlexStrategy.s.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MainnetStrategyActors} from "@script/Actors.sol";

contract BaseFunctionalityTest is BaseIntegrationTest, MainnetStrategyActors {
    address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH token address
    uint256 public constant DEPOSIT_AMOUNT = 1000 * 10 ** 18; // 1000 WETH with 18 decimals

    address public constant DEPOSITOR = address(0x1234567890123456789012345678901234567890);

    function setUp() public override {
        super.setUp();
        // Prank as admin to grant ALLOCATOR role to DEPOSITOR
        vm.startPrank(ADMIN);
        strategy.grantRole(strategy.ALLOCATOR_ROLE(), DEPOSITOR);
        vm.stopPrank();
    }

    function test_deposit_weth_ynethx_arb1() public {
        // Get WETH token and strategy
        IERC20 weth = IERC20(WETH_ADDRESS); // WETH on mainnet

        // 1000 WETH (18 decimals)
        uint256 depositAmount = 1_000 * 1e18;

        // Deal WETH to depositor
        deal(WETH_ADDRESS, DEPOSITOR, depositAmount);

        // Switch to depositor for the deposit
        vm.startPrank(DEPOSITOR);

        // Approve strategy to spend WETH
        weth.approve(address(strategy), depositAmount);

        // Get balances before deposit
        uint256 wethBalanceBefore = weth.balanceOf(DEPOSITOR);
        uint256 sharesBefore = strategy.balanceOf(DEPOSITOR);
        uint256 totalAssetsBefore = strategy.totalAssets();
        // Get safe balance before deposit
        uint256 safeWethBalanceBefore = weth.balanceOf(accountingModule.safe());

        // Perform deposit
        uint256 shares = strategy.deposit(depositAmount, DEPOSITOR);

        // Verify deposit was successful
        assertEq(
            weth.balanceOf(DEPOSITOR),
            wethBalanceBefore - depositAmount,
            "WETH balance should decrease by deposit amount"
        );
        assertEq(strategy.balanceOf(DEPOSITOR), sharesBefore + shares, "Shares balance should increase");
        assertGt(shares, 0, "Should receive shares for deposit");
        assertGe(
            strategy.totalAssets(),
            totalAssetsBefore + depositAmount,
            "Total assets should increase by at least deposit amount"
        );

        // Assert balance of WETH in safe is now increased
        uint256 safeWethBalanceAfter = weth.balanceOf(accountingModule.safe());
        assertGe(
            safeWethBalanceAfter,
            safeWethBalanceBefore + depositAmount,
            "Safe WETH balance should increase by at least deposit amount"
        );

        vm.stopPrank();

        // Test moving money from SAFE to a random receiver
        address randomReceiver = address(0x123456789);
        uint256 safeBalanceBeforeTransfer = weth.balanceOf(accountingModule.safe());
        uint256 totalAssetsBeforeTransfer = strategy.totalAssets();

        // Move money from SAFE to random receiver
        vm.startPrank(accountingModule.safe());
        weth.transfer(randomReceiver, safeBalanceBeforeTransfer);
        vm.stopPrank();

        // Verify the transfer was successful
        assertEq(weth.balanceOf(accountingModule.safe()), 0, "SAFE should have zero WETH balance after transfer");
        assertEq(
            weth.balanceOf(randomReceiver),
            safeBalanceBeforeTransfer,
            "Random receiver should have received all WETH from SAFE"
        );

        strategy.processAccounting();

        // Assert totalAssets is still the same
        uint256 totalAssetsAfterTransfer = strategy.totalAssets();
        assertEq(
            totalAssetsAfterTransfer,
            totalAssetsBeforeTransfer,
            "Total assets should remain the same after transfer from SAFE"
        );
    }

    function test_deposit_and_withdraw_roundtrip() public {
        IERC20 asset = IERC20(strategy.asset());

        // 1000 of the asset (assuming 18 decimals for WETH)
        uint256 depositAmount = 1_000 * 10 ** IERC20Metadata(address(asset)).decimals();

        // Deal asset to depositor
        deal(address(asset), DEPOSITOR, depositAmount);

        // Switch to depositor for the deposit
        vm.startPrank(DEPOSITOR);

        // Approve strategy to spend asset
        asset.approve(address(strategy), depositAmount);

        // Get totalAssets before deposit
        uint256 totalAssetsBefore = strategy.totalAssets();

        // Perform deposit
        strategy.deposit(depositAmount, DEPOSITOR);

        // Perform withdrawal of the same amount
        strategy.withdraw(depositAmount, DEPOSITOR, DEPOSITOR);

        vm.stopPrank();

        strategy.processAccounting();

        // Get totalAssets after withdrawal
        uint256 totalAssetsAfter = strategy.totalAssets();

        // Assert that totalAssets before and after are the same
        assertEq(
            totalAssetsAfter,
            totalAssetsBefore,
            "Total assets should be the same before and after deposit/withdrawal roundtrip"
        );

        // Assert that the depositor's share balance is now zero
        uint256 depositorSharesAfter = strategy.balanceOf(DEPOSITOR);
        assertEq(depositorSharesAfter, 0, "Depositor should have zero shares after withdrawal");

        // Assert that the depositor's asset balance is back to the original amount
        uint256 depositorAssetAfter = asset.balanceOf(DEPOSITOR);
        assertEq(
            depositorAssetAfter, depositAmount, "Depositor should have received back exactly the same asset amount"
        );

        // Assert that total supply decreased by exactly the shares that were burned
        uint256 totalSupplyAfter = strategy.totalSupply();
        assertEq(totalSupplyAfter, 0, "Total supply should be zero after complete withdrawal");
    }
}
