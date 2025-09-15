// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {RolesVerification} from "lib/yieldnest-flex-strategy/script/verification/RolesVerification.sol";
import {BaseScript} from "lib/yieldnest-flex-strategy/script/BaseScript.sol";
import {MainnetStrategyActors} from "@script/Actors.sol";
import {console} from "forge-std/console.sol";
import {ProxyUtils} from "lib/yieldnest-flex-strategy/lib/yieldnest-vault/script/ProxyUtils.sol";
import {VerifyFlexStrategy} from "lib/yieldnest-flex-strategy/script/verification/VerifyFlexStrategy.s.sol";
import {IActors} from "@yieldnest-vault-script/Actors.sol";
import {IContracts} from "@yieldnest-vault-script/Contracts.sol";
import {L1Contracts} from "@yieldnest-vault-script/Contracts.sol";
import {IVault} from "@yieldnest-vault/interface/IVault.sol";

// forge script VerifyFlexStrategy --rpc-url <MAINNET_RPC_URL>
contract VerifyStrategy is VerifyFlexStrategy {
    address public YNRWAX = 0x01Ba69727E2860b37bc1a2bd56999c1aFb4C15D8;

    function _setup() public virtual override {
        MainnetStrategyActors _actors = new MainnetStrategyActors();
        if (block.chainid == 1) {
            minDelay = 1 days;

            actors = IActors(_actors);
            contracts = IContracts(new L1Contracts());
        }

        address[] memory _allocators = new address[](1);
        _allocators[0] = YNRWAX;

        setVerificationParameters(
            VerifyFlexStrategy.VerificationParameters({
                name: "YieldNest WETH Flex Strategy - ynETHx - ARB1",
                symbol_: "ynFlex-WETH-ynETHx-ARB1",
                accountTokenName: "YieldNest Flex Strategy - ynETHx - ARB1 Accounting Token",
                accountTokenSymbol: "ynFlexWETH-ynETHx-ARB1-Tok",
                decimals: 18, // 18 decimals for WETH
                paused: true,
                targetApy: 0.06 ether, // max 6% rewards per year
                lowerBound: 0.0001 ether, // Ability to mark 0.01% of TVL as losses
                minRewardableAssets: 1e18, // min 1 ETH
                accountingProcessor: _actors.PROCESSOR(),
                baseAsset: IVault(YNRWAX).asset(),
                allocators: _allocators,
                alwaysComputeTotalAssets: true
            })
        );
    }
}
