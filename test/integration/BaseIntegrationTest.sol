// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DeployStrategy} from "@script/DeployStrategy.s.sol";
import {FlexStrategy} from "lib/yieldnest-flex-strategy/src/FlexStrategy.sol";
import {IAccountingModule} from "lib/yieldnest-flex-strategy/src/AccountingModule.sol";
import {IAccountingToken} from "lib/yieldnest-flex-strategy/src/AccountingToken.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {BaseScript} from "lib/yieldnest-flex-strategy/script/BaseScript.sol";

contract BaseIntegrationTest is Test {
    DeployStrategy public deployment;
    address public DEPLOYER = address(0xd34db33f);

    FlexStrategy public strategy;
    IAccountingModule public accountingModule;
    IAccountingToken public accountingToken;

    function setUp() public virtual {
        deployment = new DeployStrategy();
        deployment.setEnv(BaseScript.Env.TEST);
        deployment.run();

        strategy = FlexStrategy(payable(address(deployment.strategy())));
        accountingModule = strategy.accountingModule();
        accountingToken = accountingModule.accountingToken();

        // Give safe permissions
        vm.startPrank(accountingModule.safe());
        IERC20(strategy.asset()).approve(address(accountingModule), type(uint256).max);
        vm.stopPrank();
    }
}
