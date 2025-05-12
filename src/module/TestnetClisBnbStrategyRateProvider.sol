// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {TestnetContracts as TC} from "script/Contracts.sol";
import {ISlisBnbProvider} from "src/interfaces/ISlisBnbProvider.sol";

/**
 * @title TestnetClisBnbStrategyRateProvider
 * @notice This contract provides the rate for the assets used in ClisBnbStrategy in bsc testnet. The base asset is slisBnb.
 */
contract TestnetClisBnbStrategyRateProvider {
    error UnsupportedAsset(address asset);

    function getRate(address asset) external pure returns (uint256) {
        // slisBnb is the base asset
        if (asset == TC.SLIS_BNB) {
            return 1e18;
        }
        revert UnsupportedAsset(asset);
    }
}
