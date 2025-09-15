// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {BaseIntegrationTest} from "./BaseIntegrationTest.sol";
import {RewardsSweeper} from "lib/yieldnest-flex-strategy/src/utils/RewardsSweeper.sol";
import {TransparentUpgradeableProxy} from
    "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UpgradeUtils} from "lib/yieldnest-flex-strategy/script/UpgradeUtils.sol";
import {AccountingModule} from "lib/yieldnest-flex-strategy/src/AccountingModule.sol";
import {AccountingToken} from "lib/yieldnest-flex-strategy/src/AccountingToken.sol";
import {FlexStrategy} from "lib/yieldnest-flex-strategy/src/FlexStrategy.sol";
import {ProxyUtils} from "lib/yieldnest-vault/script/ProxyUtils.sol";

contract UpgradesTest is BaseIntegrationTest {
    function setUp() public override {
        super.setUp();
    }

    function testDeploymentParameters() public {
        // Check if the deployment parameters are set correctly
        assertEq(strategy.symbol(), "ynFlex-WETH-ynETHx-ARB1");
        assertEq(strategy.asset(), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH address
    }

    function testAccountingModuleUpgrade() public {
        // Deploy a new implementation of AccountingModule
        AccountingModule newAccountingModuleImplementation = new AccountingModule();

        UpgradeUtils.timelockUpgrade(
            deployment.timelock(),
            deployment.actors().ADMIN(),
            address(deployment.accountingModule()),
            address(newAccountingModuleImplementation)
        );

        // Get implementation address from proxy
        address currentImplementation = ProxyUtils.getImplementation(address(deployment.accountingModule()));
        assertEq(currentImplementation, address(newAccountingModuleImplementation));
    }

    function testAccountingTokenUpgrade() public {
        // Deploy a new implementation of AccountingToken
        AccountingToken newAccountingTokenImplementation = new AccountingToken(address(0));

        UpgradeUtils.timelockUpgrade(
            deployment.timelock(),
            deployment.actors().ADMIN(),
            address(deployment.accountingToken()),
            address(newAccountingTokenImplementation)
        );

        // Get implementation address from proxy
        address currentImplementation = ProxyUtils.getImplementation(address(deployment.accountingToken()));
        assertEq(currentImplementation, address(newAccountingTokenImplementation));
    }

    function testFlexStrategyUpgrade() public {
        // Deploy a new implementation of FlexStrategy
        FlexStrategy newFlexStrategyImplementation = new FlexStrategy();

        UpgradeUtils.timelockUpgrade(
            deployment.timelock(),
            deployment.actors().ADMIN(),
            address(deployment.strategy()),
            address(newFlexStrategyImplementation)
        );

        // Get implementation address from proxy
        address currentImplementation = ProxyUtils.getImplementation(address(deployment.strategy()));
        assertEq(currentImplementation, address(newFlexStrategyImplementation));
    }
}
