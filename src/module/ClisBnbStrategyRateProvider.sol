// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {MainnetContracts as MC} from "script/Contracts.sol";
import {ISlisBnbProvider} from "../interfaces/ISlisBnbProvider.sol";

error UnSupportedAsset(address asset);

contract ClisBnbStrategyRateProvider {

    function getRate(address asset) external view returns (uint256) {
        
        if (asset == MC.SLIS_BNB) { 
            return 1e18;
        }

        revert UnSupportedAsset(asset);
    }
}