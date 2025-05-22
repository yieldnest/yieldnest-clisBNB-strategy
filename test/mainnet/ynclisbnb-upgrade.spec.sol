// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {MainnetActors} from "script/Actors.sol";
import {MainnetContracts as MC} from "script/Contracts.sol";
import {ClisBnbStrategy} from "src/ClisBnbStrategy.sol";
import {Interaction} from "src/interfaces/Interaction.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {TransparentUpgradeableProxy} from
    "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ClisBnbStrategyRateProvider} from "src/module/ClisBnbStrategyRateProvider.sol";
import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {ISlisBnbProvider} from "src/interfaces/ISlisBnbProvider.sol";
import {IVault} from "lib/yieldnest-vault/src/interface/IVault.sol";
import {IValidator} from "lib/yieldnest-vault/src/interface/IValidator.sol";
import {MockYnClisBnbStrategyRateProvider} from "test/mainnet/mocks/MockYnClisBnbStrategyRateProvider.sol";
import {ISlisBnbStakeManager} from "test/mainnet/mocks/MockYnBnbxProvider.sol";
import {BaseRoles} from "script/roles/BaseRoles.sol";
import {BaseRules} from "lib/yieldnest-vault/script/rules/BaseRules.sol";
import {SafeRules} from "lib/yieldnest-vault/script/rules/SafeRules.sol";
import {ProvideRules} from "script/rules/ProvideRules.sol";
import {console} from "lib/forge-std/src/console.sol";
import {IBaseStrategy} from "lib/yieldnest-vault/src/interface/IBaseStrategy.sol";
import {ProxyUtils} from "lib/yieldnest-vault/script/ProxyUtils.sol";
import {ProxyAdmin} from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {UpgradeUtils} from "test/utils/UpgradeUtils.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract YnClisBnbStrategyUpgradeTest is Test, MainnetActors {
    ClisBnbStrategy public clisBnbStrategy;
    ClisBnbStrategyRateProvider public clisBnbStrategyRateProvider;
    address public timelock;
    MainnetActors public actors;

    error InvalidRules();

    function setUp() public virtual {
        clisBnbStrategy = ClisBnbStrategy(payable(MC.YNCLISBNB));
        clisBnbStrategyRateProvider = ClisBnbStrategyRateProvider(address(clisBnbStrategy.provider()));
        timelock = ProxyAdmin(ProxyUtils.getProxyAdmin(address(clisBnbStrategy))).owner();
    }

    function test_upgrade_clisBnbStrategy() public {
        {
            ClisBnbStrategy clisBnbStrategyImplementation = new ClisBnbStrategy();
            UpgradeUtils.timelockUpgrade(
                TimelockController(payable(TIMELOCK)),
                ADMIN,
                address(clisBnbStrategy),
                address(clisBnbStrategyImplementation)
            );
        }
    }
}
