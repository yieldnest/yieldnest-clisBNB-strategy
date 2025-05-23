// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {IVault} from "lib/yieldnest-vault/src/interface/IVault.sol";
import {BaseScript} from "script/BaseScript.sol";
import {RulesVerification} from "./RulesVerification.sol";
import {ISlisBnbProvider} from "src/interfaces/ISlisBnbProvider.sol";
import {IValidator} from "lib/yieldnest-vault/src/interface/IValidator.sol";
import {SafeRules} from "lib/yieldnest-vault/script/rules/SafeRules.sol";
import {Test} from "forge-std/Test.sol";
import {RolesVerification} from "./RolesVerification.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MainnetActors} from "script/Actors.sol";

// FOUNDRY_PROFILE=mainnet forge script VerifyClisBnbStrategy
contract VerifyClisBnbStrategy is BaseScript, Test {
    function symbol() public pure override returns (string memory) {
        return "ynClisBnb";
    }

    function run() public {
        _loadDeployment();
        _setup();

        verify();
    }

    function verify() internal view {
        assertNotEq(address(clisBnbStrategy), address(0), "vault is not set");
        assertNotEq(address(clisBnbStrategyImplementation), address(0), "vault implementation is not set");
        assertNotEq(address(clisBnbStrategyProxyAdmin), address(0), "vault proxy admin is not set");

        assertEq(clisBnbStrategy.name(), "YieldNest ClisBnb Strategy", "name is invalid");
        assertEq(clisBnbStrategy.symbol(), "ynClisBnb", "symbol is invalid");
        assertEq(clisBnbStrategy.decimals(), 18, "decimals is invalid");

        assertNotEq(address(rateProvider), address(0), "provider is invalid");
        assertEq(clisBnbStrategy.provider(), address(rateProvider), "provider is invalid");

        assertEq(
            address(clisBnbStrategy.listaInteraction()),
            address(contracts.INTERACTION()),
            "lista interaction is invalid"
        );
        assertEq(
            address(clisBnbStrategy.yieldNestMpcWallet()),
            address(contracts.YIELDNEST_MPC_WALLET()),
            "yield nest mpc wallet is invalid"
        );
        assertEq(address(clisBnbStrategy.slisBnb()), address(contracts.SLIS_BNB()), "slis bnb is invalid");
        assertEq(
            address(clisBnbStrategy.slisBnbProvider()),
            address(contracts.SLIS_BNB_PROVIDER()),
            "slis bnb provider is invalid"
        );
        assertTrue(clisBnbStrategy.getHasAllocator(), "has allocator is invalid");
        assertEq(clisBnbStrategy.syncDeposit(), true, "sync deposit is invalid");
        assertEq(clisBnbStrategy.countNativeAsset(), false, "count native asset is invalid");
        assertEq(clisBnbStrategy.alwaysComputeTotalAssets(), true, "always compute total assets is invalid");

        address[] memory assets = clisBnbStrategy.getAssets();
        assertEq(assets.length, 1, "assets length is invalid");
        assertEq(assets[0], contracts.SLIS_BNB(), "assets[0] is invalid");
        IVault.AssetParams memory asset = clisBnbStrategy.getAsset(contracts.SLIS_BNB());
        assertEq(asset.decimals, 18, "asset[0].decimals is invalid");
        assertEq(asset.active, true, "asset[0].active is invalid");
        assertEq(asset.index, 0, "asset[0].index is invalid");

        address[] memory allowList = new address[](1);
        allowList[0] = contracts.SLIS_BNB_PROVIDER();
        _verifyApprovalRule(clisBnbStrategy, contracts.SLIS_BNB(), allowList);
        _verifyProvideRule(clisBnbStrategy, contracts.SLIS_BNB_PROVIDER(), contracts.YIELDNEST_MPC_WALLET());

        assertFalse(clisBnbStrategy.paused(), "paused is invalid");

        RolesVerification.verifyDefaultRoles(clisBnbStrategy, timelock, actors);
        RolesVerification.verifyTemporaryRoles(clisBnbStrategy, deployer);
        RolesVerification.verifyRole(
            timelock,
            MainnetActors(address(actors)).YnSecurityCouncil(),
            timelock.PROPOSER_ROLE(),
            true,
            "proposer role for timelock is YnSecurityCouncil"
        );
        RolesVerification.verifyRole(
            timelock,
            MainnetActors(address(actors)).YnSecurityCouncil(),
            timelock.EXECUTOR_ROLE(),
            true,
            "executor role for timelock is YnSecurityCouncil"
        );
        RolesVerification.verifyRole(
            clisBnbStrategy,
            MainnetActors(address(actors)).YnBootstrapper(),
            clisBnbStrategy.ALLOCATOR_ROLE(),
            true,
            "bootstrapper has allocator role"
        );

        assertGe(timelock.getMinDelay(), minDelay, "min delay is invalid");
        assertEq(Ownable(clisBnbStrategyProxyAdmin).owner(), address(timelock), "proxy admin owner is invalid");
    }

    function _verifyApprovalRule(IVault clisBnbStrategy, address contractAddress, address[] memory allowList)
        internal
        view
    {
        bytes4 funcSig = bytes4(keccak256("approve(address,uint256)"));

        IVault.ParamRule[] memory paramRules = new IVault.ParamRule[](2);

        paramRules[0] = IVault.ParamRule({paramType: IVault.ParamType.ADDRESS, isArray: false, allowList: allowList});
        paramRules[1] =
            IVault.ParamRule({paramType: IVault.ParamType.UINT256, isArray: false, allowList: new address[](0)});

        IVault.FunctionRule memory rule =
            IVault.FunctionRule({isActive: true, paramRules: paramRules, validator: IValidator(address(0))});

        _verifyProcessorRule(clisBnbStrategy, contractAddress, funcSig, rule);
    }

    function _verifyProvideRule(IVault clisBnbStrategy, address contractAddress, address delegatee) internal view {
        // provide(uint256 amount, address delegatee)
        bytes4 funcSig = ISlisBnbProvider.provide.selector;

        IVault.ParamRule[] memory paramRules = new IVault.ParamRule[](2);

        paramRules[0] =
            IVault.ParamRule({paramType: IVault.ParamType.UINT256, isArray: false, allowList: new address[](0)});

        address[] memory allowList = new address[](1);
        allowList[0] = delegatee;
        paramRules[1] = IVault.ParamRule({paramType: IVault.ParamType.ADDRESS, isArray: false, allowList: allowList});

        IVault.FunctionRule memory rule =
            IVault.FunctionRule({isActive: true, paramRules: paramRules, validator: IValidator(address(0))});

        _verifyProcessorRule(clisBnbStrategy, contractAddress, funcSig, rule);
    }

    function _verifyProcessorRule(
        IVault clisBnbStrategy,
        address contractAddress,
        bytes4 funcSig,
        IVault.FunctionRule memory rule
    ) internal view {
        RulesVerification.verifyProcessorRule(clisBnbStrategy, contractAddress, funcSig, rule);
    }
}
