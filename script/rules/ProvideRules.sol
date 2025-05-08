// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {IVault, IValidator} from "lib/yieldnest-vault/src/interface/IVault.sol";
import {SafeRules} from "lib/yieldnest-vault/script/rules/SafeRules.sol";
import {ISlisBnbProvider} from "src/interfaces/ISlisBnbProvider.sol";

library ProvideRules {
    function getProvideRule(address contractAddress, address delegatee)
        internal
        pure
        returns (SafeRules.RuleParams memory)
    {
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

        return SafeRules.RuleParams({contractAddress: contractAddress, funcSig: funcSig, rule: rule});
    }
}
