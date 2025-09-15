// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "lib/yieldnest-flex-strategy/script/DeployFlexStrategy.s.sol";
import {L1Contracts} from "@yieldnest-vault-script/Contracts.sol";
import {MainnetContracts as MC} from "lib/yieldnest-flex-strategy/lib/yieldnest-vault/script/Contracts.sol";
import {IContracts} from "@yieldnest-vault-script/Contracts.sol";
import {IActors} from "@yieldnest-vault-script/Actors.sol";
import {console} from "forge-std/console.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyUtils} from "lib/yieldnest-flex-strategy/lib/yieldnest-vault/script/ProxyUtils.sol";
import {MainnetStrategyActors} from "@script/Actors.sol";

contract DeployStrategy is DeployFlexStrategy {

    function _setup() public virtual override {
        MainnetStrategyActors _actors = new MainnetStrategyActors();
        if (block.chainid == 1) {
            minDelay = 1 days;
            actors = IActors(_actors);
            contracts = IContracts(new L1Contracts());
        }
        address[] memory _allocators = new address[](1);
        _allocators[0] = MC.YNETHX;

        setDeploymentParameters(
            BaseScript.DeploymentParameters({
                name: "YieldNest WETH Flex Strategy - ynETHx - ARB1",
                symbol_: "ynFlex-WETH-ynETHx-ARB1",
                accountTokenName: "YieldNest Flex Strategy - ynETHx - ARB1 Accounting Token",
                accountTokenSymbol: "ynFlexWETH-ynETHx-ARB1-Tok",
                decimals: 18, // 6 decimals for WETH
                paused: true,
                targetApy: 0.06 ether, // max 6% rewards per year
                lowerBound: 0.0001 ether, // Ability to mark 0.01% of TVL as losses
                minRewardableAssets: 1e18, // min 1 ETH
                accountingProcessor: _actors.PROCESSOR(),
                baseAsset: IVault(MC.YNETHX).asset(),
                allocators: _allocators,
                safe: _actors.SAFE(),
                alwaysComputeTotalAssets: true,
                useRewardsSweeper: true
            })
        );
    }
}
