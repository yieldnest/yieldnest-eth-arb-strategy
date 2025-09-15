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

contract BaseFunctionalityTest is BaseIntegrationTest {
    address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH token address
    uint256 public constant DEPOSIT_AMOUNT = 1000 * 10 ** 18; // 1000 WETH with 18 decimals

    address public constant DEPOSITOR = address(0x1234567890123456789012345678901234567890);

    function setUp() public override {
        super.setUp();
        // Prank as admin to grant ALLOCATOR role to DEPOSITOR
        vm.startPrank(accountingModule.safe());
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

    function test_deposit_and_inject_rewards_with_rewards_sweeper() public {
        // Get WETH token and strategy
        IERC20 weth = IERC20(WETH_ADDRESS);
        DeployFlexStrategy deployFlexStrategy = new DeployFlexStrategy();
        RewardsSweeper rewardsSweeper = deployFlexStrategy.rewardsSweeper();

        // 1000 WETH (18 decimals) and 10 WETH reward
        uint256 depositAmount = 1_000 * 1e18;
        uint256 rewardAmount = 10 * 1e18;

        // Deal WETH to depositor and rewards sweeper
        deal(WETH_ADDRESS, DEPOSITOR, depositAmount);
        deal(WETH_ADDRESS, address(rewardsSweeper), rewardAmount);

        // Switch to depositor for the deposit
        vm.startPrank(DEPOSITOR);

        // Approve strategy to spend WETH
        weth.approve(address(strategy), depositAmount);

        // Get balances before deposit
        uint256 totalAssetsBefore = strategy.totalAssets();
        uint256 totalSupplyBefore = strategy.totalSupply();

        // Perform deposit
        uint256 shares = strategy.deposit(depositAmount, DEPOSITOR);

        vm.stopPrank();

        // Process accounting to update state
        strategy.processAccounting();

        // Get state after deposit
        uint256 totalAssetsAfterDeposit = strategy.totalAssets();
        uint256 totalSupplyAfterDeposit = strategy.totalSupply();

        // Verify deposit was successful
        assertGt(shares, 0, "Should receive shares for deposit");
        assertEq(
            totalAssetsAfterDeposit, totalAssetsBefore + depositAmount, "Total assets should increase by deposit amount"
        );
        assertEq(totalSupplyAfterDeposit, totalSupplyBefore + shares, "Total supply should increase by shares minted");

        // Advance time by 1 month (30 days)
        vm.warp(block.timestamp + 30 days);

        // Inject rewards using rewards sweeper
        vm.startPrank(accountingModule.safe());
        rewardsSweeper.sweepRewards(rewardAmount);
        vm.stopPrank();

        // Process accounting to capture the rewards
        strategy.processAccounting();

        // Get state after rewards injection
        uint256 totalAssetsAfterRewards = strategy.totalAssets();
        uint256 totalSupplyAfterRewards = strategy.totalSupply();

        // Verify rewards injection was successful
        assertEq(
            totalAssetsAfterRewards,
            totalAssetsAfterDeposit + rewardAmount,
            "Total assets should increase by reward amount after injection"
        );
        assertEq(
            totalSupplyAfterRewards,
            totalSupplyAfterDeposit,
            "Total supply should remain the same after rewards injection (no new shares minted)"
        );

        // Verify the depositor can redeem more assets than they deposited due to rewards
        uint256 redeemableAssets = strategy.previewRedeem(shares);
        assertGt(
            redeemableAssets,
            depositAmount,
            "Depositor should be able to redeem more than they deposited due to rewards"
        );

        // Verify that the rewards sweeper has no WETH balance after sweeping
        assertEq(
            weth.balanceOf(address(rewardsSweeper)), 0, "Rewards sweeper should have zero WETH balance after sweeping"
        );

        // Test that sweeping rewards again should revert (no rewards to sweep)
        vm.startPrank(accountingModule.safe());
        vm.expectRevert(RewardsSweeper.CannotSweepRewards.selector);
        rewardsSweeper.sweepRewards(rewardAmount);
        vm.stopPrank();

        // Deal 100 WETH to rewards sweeper for next test
        deal(WETH_ADDRESS, address(rewardsSweeper), 100 * 1e18);

        // Advance time by only 1 hour (should be within cooldown period)
        vm.warp(block.timestamp + 1 hours);

        // Try to inject rewards again - should revert due to cooldown period
        vm.startPrank(accountingModule.safe());
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccountingModule.AccountingLimitsExceeded.selector, 8757251505745759985, 150000000000000000
            )
        );
        rewardsSweeper.sweepRewards(rewardAmount);
        vm.stopPrank();

        // Call sweepRewardsUpToAPRMax
        vm.startPrank(accountingModule.safe());
        uint256 sweptAmount = rewardsSweeper.sweepRewardsUpToAPRMax();
        vm.stopPrank();

        // Verify that some amount was swept (should be > 0 if there are rewards to sweep within APR limits)
        assertGe(sweptAmount, 0, "Swept amount should be non-negative");

        // Verify total assets increased by the swept amount
        uint256 totalAssetsAfterSweep = strategy.totalAssets();
        assertEq(
            totalAssetsAfterSweep, totalAssetsAfterRewards + sweptAmount, "Total assets should increase by swept amount"
        );
    }
}
