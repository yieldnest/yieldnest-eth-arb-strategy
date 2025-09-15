// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.28;

import {IActors} from "@yieldnest-vault-script/Actors.sol";

contract MainnetStrategyActors is IActors {
    address public constant YnSecurityCouncil = 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975;
    address public constant YnProcessor = 0x56866A6D5655C9E534320DA95fbBB82Fb3bF3D7D; // ynethx processor
    address public constant YnDev = 0xa08F39d30dc865CC11a49b6e5cBd27630D6141C3;
    address public constant YnBootstrapper = 0x832e0D8e7A7Bdfe181f30df614383FAA4B5C2924;
    address public constant YnEOABoostrapper = 0xB35eea5E7a22C541F76eB50dD9d3f77576aF15BF;

    address public constant TIMELOCK = address(0);

    address public constant ADMIN = YnSecurityCouncil;
    address public constant PROCESSOR = YnProcessor;
    address public constant EXECUTOR_1 = YnSecurityCouncil;
    address public constant PROPOSER_1 = YnSecurityCouncil;

    address public constant PROVIDER_MANAGER = YnSecurityCouncil;
    address public constant BUFFER_MANAGER = YnSecurityCouncil;
    address public constant ASSET_MANAGER = YnSecurityCouncil;
    address public constant PROCESSOR_MANAGER = YnSecurityCouncil;
    address public constant PAUSER = YnDev;
    address public constant UNPAUSER = YnSecurityCouncil;
    address public constant FEE_MANAGER = YnSecurityCouncil;

    address public constant ALLOCATOR_MANAGER = YnSecurityCouncil;

    address public constant UPDATER = YnDev;
    address public constant BOOTSTRAPPER = YnBootstrapper;
    address public constant UNAUTHORIZED = address(0);

    address public constant SAFE = 0x8eE2dd06404C96A62a47cc6D8A54B1a2f7A27013;

    address public constant EOA_BOOTSTRAPPER = YnEOABoostrapper;
}
