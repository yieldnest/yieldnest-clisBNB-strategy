// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {ClisBnbStrategyRateProvider} from "src/module/ClisBnbStrategyRateProvider.sol";
import {ClisBnbStrategy} from "src/ClisBnbStrategy.sol";
import {BaseScript} from "script/BaseScript.sol";
import {IProvider} from "lib/yieldnest-vault/src/interface/IProvider.sol";
import {TransparentUpgradeableProxy} from
    "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {BaseRoles} from "script/roles/BaseRoles.sol";
import {BaseRules} from "lib/yieldnest-vault/script/rules/BaseRules.sol";
import {SafeRules} from "lib/yieldnest-vault/script/rules/SafeRules.sol";
import {ProvideRules} from "script/rules/ProvideRules.sol";

// FOUNDRY_PROFILE=mainnet forge script DeployClisBnbStrategy
contract DeployClisBnbStrategy is BaseScript {
    error InvalidRules();
    error InvalidRateProvider();

    function symbol() public pure override returns (string memory) {
        return "ynClisBnb";
    }

    function deployRateProvider() internal {
        if (block.chainid == 56) {
            rateProvider = IProvider(address(new ClisBnbStrategyRateProvider()));
        }
    }

    function _verifySetup() public view override {
        super._verifySetup();

        if (block.chainid == 56) {
            if (address(rateProvider) == address(0)) {
                revert InvalidRateProvider();
            }
        }
    }

    function run() public {
        vm.startBroadcast();

        _setup();
        _deployTimelockController();
        deployRateProvider();

        _verifySetup();

        deploy();

        _saveDeployment();

        vm.stopBroadcast();
    }

    function deploy() internal {
        clisBnbStrategyImplementation = new ClisBnbStrategy();

        address admin = msg.sender;

        string memory name = "ynClisBnb Strategy";
        string memory symbol_ = "ynClisBnb";
        uint8 decimals = 18;

        bool countNativeAsset = false;
        bool alwaysComputeTotalAssets = true;

        TransparentUpgradeableProxy proxy =
            new TransparentUpgradeableProxy(address(clisBnbStrategyImplementation), address(timelock), "");

        clisBnbStrategy = ClisBnbStrategy(payable(address(proxy)));

        clisBnbStrategy.initialize(
            admin,
            name,
            symbol_,
            decimals,
            countNativeAsset,
            alwaysComputeTotalAssets,
            contracts.SLIS_BNB(),
            contracts.YIELDNEST_MPC_WALLET(),
            contracts.INTERACTION(),
            contracts.SLIS_BNB_PROVIDER()
        );

        configureStrategy();
    }

    function configureStrategy() internal {
        BaseRoles.configureDefaultRolesStrategy(clisBnbStrategy, address(timelock), actors);
        BaseRoles.configureTemporaryRolesStrategy(clisBnbStrategy, deployer);

        // set provider
        clisBnbStrategy.setProvider(address(rateProvider));
        // set sync deposit
        clisBnbStrategy.setSyncDeposit(true);
        // set has allocator
        clisBnbStrategy.setHasAllocator(true);
        // grant allocator role
        clisBnbStrategy.grantRole(clisBnbStrategy.ALLOCATOR_ROLE(), contracts.YNBNBX());

        uint256 rulesLength = 2;
        uint256 i = 0;

        SafeRules.RuleParams[] memory rules = new SafeRules.RuleParams[](rulesLength);

        rules[i++] = BaseRules.getApprovalRule(contracts.SLIS_BNB(), contracts.SLIS_BNB_PROVIDER());
        rules[i++] = ProvideRules.getProvideRule(contracts.SLIS_BNB_PROVIDER(), contracts.YIELDNEST_MPC_WALLET());

        if (i != rulesLength) {
            revert InvalidRules();
        }

        SafeRules.setProcessorRules(clisBnbStrategy, rules, false);

        clisBnbStrategy.unpause();

        clisBnbStrategy.processAccounting();

        BaseRoles.renounceTemporaryRolesStrategy(clisBnbStrategy, deployer);
    }
}
