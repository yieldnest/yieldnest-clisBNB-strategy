// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {MainnetContracts as MC} from "script/Contracts.sol";
import {ISlisBnbProvider} from "src/interfaces/ISlisBnbProvider.sol";

error UnSupportedAsset(address asset);

/**
 * @title ClisBnbStrategyRateProvider
 * @notice This contract provides the rate for the assets used in ClisBnbStrategy. The base asset is slisBnb.
 */
contract ClisBnbStrategyRateProvider {
    function getRate(address asset) external pure returns (uint256) {
        // slisBnb is the base asset
        if (asset == MC.SLIS_BNB) {
            return 1e18;
        }
        revert UnSupportedAsset(asset);
    }
}