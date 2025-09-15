// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {BaseIntegrationTest} from "./BaseIntegrationTest.sol";
import {BaseScript} from "lib/yieldnest-flex-strategy/script/BaseScript.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IAccountingModule} from "lib/yieldnest-flex-strategy/src/AccountingModule.sol";
import {FlexStrategy} from "lib/yieldnest-flex-strategy/src/FlexStrategy.sol";
import {MainnetStrategyActors} from "@script/Actors.sol";

contract VaultMainnetUpgradeTest is BaseIntegrationTest {
    function setUp() public override {
        super.setUp();
    }

    function test_weth_ynethx_arb1_views() public view {
        // Get WETH token and strategy
        IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH on mainnet

        // Test asset and share conversions
        uint256 testAmount = 1000 * 1e18; // 1000 WETH
        {
            uint256 previewDeposit = strategy.previewDeposit(testAmount);
            uint256 previewMint = strategy.previewMint(previewDeposit);
            uint256 previewWithdraw = strategy.previewWithdraw(testAmount);
            uint256 previewRedeem = strategy.previewRedeem(previewDeposit);

            assertGt(previewDeposit, 0, "Preview deposit should return shares");
            assertApproxEqAbs(previewMint, testAmount, 1e6, "Preview mint should be approximately equal to test amount");
            assertGt(previewWithdraw, 0, "Preview withdraw should return shares needed");
            assertApproxEqAbs(
                previewRedeem, testAmount, 1e6, "Preview redeem should be approximately equal to test amount"
            );
        }

        // Test that the strategy is paused
        assertFalse(FlexStrategy(payable(address(strategy))).paused(), "Strategy should not be paused");

        {
            // Test max functions
            uint256 maxDeposit = strategy.maxDeposit(address(this));
            uint256 maxMint = strategy.maxMint(address(this));
            uint256 maxWithdraw = strategy.maxWithdraw(address(this));
            uint256 maxRedeem = strategy.maxRedeem(address(this));

            // These should be reasonable values (not 0 or type(uint256).max unless expected)
            assertGt(maxDeposit, 0, "Max deposit should be greater than 0");
            assertGt(maxMint, 0, "Max mint should be greater than 0");
            // maxWithdraw and maxRedeem might be 0 if user has no shares, which is expected
            assertEq(maxWithdraw, 0, "Max withdraw should be 0 for user with no shares");
            assertEq(maxRedeem, 0, "Max redeem should be 0 for user with no shares");

            // Test asset and share relationship
            assertEq(strategy.asset(), address(weth), "Asset should be WETH");
        }

        {
            // Test convertToShares and convertToAssets consistency
            uint256 convertToShares = strategy.convertToShares(testAmount);
            uint256 convertToAssets = strategy.convertToAssets(convertToShares);

            assertGt(convertToShares, 0, "Convert to shares should return positive value");
            assertApproxEqAbs(
                convertToAssets, testAmount, 1, "Convert to assets should be approximately equal to original amount"
            );

            assertGe(convertToAssets, 1e18, "Convert to assets should return a value greater than 1e18");
        }

        // Get AccountingModule from strategy
        IAccountingModule accountingModule = strategy.accountingModule();

        {
            // Test AccountingModule view functions
            assertEq(accountingModule.strategy(), address(strategy), "AccountingModule strategy should match");
            assertEq(accountingModule.baseAsset(), address(weth), "AccountingModule base asset should be WETH");
            assertEq(
                accountingModule.safe(),
                MainnetStrategyActors(address(deployment.actors())).SAFE(),
                "AccountingModule safe should match deployment safe"
            );

            // Test APY and timing parameters
            uint256 targetApy = accountingModule.targetApy();

            assertEq(targetApy, 0.15 ether, "Target APY should be 15%");
        }

        // Test snapshots if any exist
        uint256 snapshotsLength = accountingModule.snapshotsLength();
        if (snapshotsLength > 0) {
            IAccountingModule.StrategySnapshot memory latestSnapshot = accountingModule.snapshots(snapshotsLength - 1);
            assertGe(latestSnapshot.pricePerShare, 1e18, "Latest snapshot price per share should be greater than 0");
            assertGt(latestSnapshot.timestamp, 0, "Latest snapshot timestamp should be greater than 0");
        }

        // Test constants
        assertEq(accountingModule.YEAR(), 365.25 days, "YEAR constant should be 365.25 days");
        assertEq(accountingModule.DIVISOR(), 1e18, "DIVISOR constant should be 1e18");

        // Test lower bound
        uint256 lowerBound = accountingModule.lowerBound();
        assertEq(lowerBound, 0.0001 ether, "Lower bound should be 0.01%");
    }
}
