// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {ClisBnbStrategyRateProvider} from "src/module/ClisBnbStrategyRateProvider.sol";
import {MainnetContracts as MC} from "script/Contracts.sol";
import {ISlisBnbStakeManager} from "test/mainnet/mocks/MockYnBnbxProvider.sol";
import {IProvider} from "lib/yieldnest-vault/src/interface/IProvider.sol";

contract MockYnClisBnbStrategyRateProvider is IProvider {
    error UnsupportedAsset(address asset);

    function getRate(address asset) external view returns (uint256) {
        // slisBnb is the base asset
        if (asset == MC.SLIS_BNB) {
            return 1e18;
        }

        if (asset == MC.WBNB) {
            // convert BNB to slisBnb
            return ISlisBnbStakeManager(MC.SLIS_BNB_STAKE_MANAGER).convertBnbToSnBnb(1e18);
        }
        revert UnsupportedAsset(asset);
    }
}
