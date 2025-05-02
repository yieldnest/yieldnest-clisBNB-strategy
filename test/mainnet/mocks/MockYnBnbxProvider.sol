// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {IProvider} from "lib/yieldnest-vault/src/interface/IProvider.sol";
import {IERC4626} from "lib/yieldnest-vault/src/Common.sol";
import {MainnetContracts as MC} from "script/Contracts.sol";
import {IVault} from "lib/yieldnest-vault/src/interface/IVault.sol";

interface IBaseStrategy {
    function STRATEGY_VERSION() external view returns (string memory);
}

interface IBNBXStakeManagerV2 {
    function convertBnbXToBnb(uint256 amount) external view returns (uint256);
}

interface ISlisBnbStakeManager {
    function convertSnBnbToBnb(uint256 amount) external view returns (uint256);
}

interface IAsBnbMinter {
    function convertToTokens(uint256 amount) external view returns (uint256);
}

/**
 * @title MockYnBnbxProvider
 * @notice This contract is a mock implementation of the IProvider interface.
 * @dev This contract is used adds the rate of ClisBnbStrategy in the current provider implementation of YnBNBx
 */
contract MockYnBnbxProvider is IProvider {
    error UnsupportedAsset(address asset);

    function isBNBStrategyVault(address asset) public view returns (bool) {
        try IBaseStrategy(asset).STRATEGY_VERSION() returns (string memory version) {
            address vaultAsset = IVault(asset).asset();
            return keccak256(bytes(version)) == keccak256(bytes("0.1.0")) && vaultAsset == MC.WBNB;
        } catch {
            return false;
        }
    }

    function isClisBnbStrategyVault(address asset) public view returns (bool) {
        try IBaseStrategy(asset).STRATEGY_VERSION() returns (string memory version) {
            address vaultAsset = IVault(asset).asset();
            return keccak256(bytes(version)) == keccak256(bytes("0.1.0")) && vaultAsset == MC.SLIS_BNB;
        } catch {
            return false;
        }
    }

    function getRate(address asset) public view override returns (uint256) {
        if (asset == MC.YNWBNBK || asset == MC.YNBNBK || asset == MC.YNCLISBNBK || asset == MC.YNASBNBK) {
            return IERC4626(asset).convertToAssets(1e18);
        }

        if (asset == MC.WBNB) {
            return 1e18;
        }

        if (asset == MC.BNBX) {
            return IBNBXStakeManagerV2(MC.BNBX_STAKE_MANAGER).convertBnbXToBnb(1e18);
        }

        if (asset == MC.SLIS_BNB) {
            return ISlisBnbStakeManager(MC.SLIS_BNB_STAKE_MANAGER).convertSnBnbToBnb(1e18);
        }

        if (asset == MC.ASBNB) {
            return ISlisBnbStakeManager(MC.SLIS_BNB_STAKE_MANAGER).convertSnBnbToBnb(
                IAsBnbMinter(MC.AS_BNB_MINTER).convertToTokens(1e18)
            );
        }

        if (isBNBStrategyVault(asset)) {
            return IERC4626(asset).convertToAssets(1e18);
        }

        if (isClisBnbStrategyVault(asset)) {
            // base asset to clisBnbStrategy is SlisBnb
            return
                ISlisBnbStakeManager(MC.SLIS_BNB_STAKE_MANAGER).convertSnBnbToBnb(IERC4626(asset).convertToAssets(1e18));
        }

        revert UnsupportedAsset(asset);
    }
}
