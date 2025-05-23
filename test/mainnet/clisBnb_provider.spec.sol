// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {MainnetContracts as MC} from "script/Contracts.sol";
import {ClisBnbStrategyRateProvider} from "src/module/ClisBnbStrategyRateProvider.sol";
import {MainnetContracts as MC} from "script/Contracts.sol";
import {ClisBnbStrategy} from "src/ClisBnbStrategy.sol";

contract ClisBnbProviderTest is Test {
    ClisBnbStrategyRateProvider public provider;

    function setUp() public {
        provider = ClisBnbStrategyRateProvider(ClisBnbStrategy(payable(MC.YNCLISBNB)).provider());
    }

    function test_Provider_GetRateWBNB_Revert() public {
        vm.expectRevert(abi.encodeWithSelector(ClisBnbStrategyRateProvider.UnsupportedAsset.selector, MC.WBNB));
        provider.getRate(MC.WBNB);
    }

    function test_Provider_GetRateSlisBnb() public view {
        uint256 rate = provider.getRate(MC.SLIS_BNB);
        assertEq(rate, 1e18, "Rate for SlisBnb should be 1e18 since it's the base asset of ClisBnbStrategy");
    }

    function test_Provider_UnsupportedAsset() public {
        address unsupportedAsset = address(0x123);
        vm.expectRevert(abi.encodeWithSelector(ClisBnbStrategyRateProvider.UnsupportedAsset.selector, unsupportedAsset));
        provider.getRate(unsupportedAsset);
    }
}
