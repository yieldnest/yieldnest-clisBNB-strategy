// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {IERC20, Math, SafeERC20} from "lib/yieldnest-vault/src/Common.sol";
import {BaseStrategy} from "lib/yieldnest-vault/src/strategy/BaseStrategy.sol";
import {Interaction} from "./interfaces/Interaction.sol";
import {ISlisBnbProvider} from "./interfaces/ISlisBnbProvider.sol";

error UnSupportedAsset(address asset);

contract ClisBnbStrategy is BaseStrategy {

    /// @notice Role for deposit manager permissions
    bytes32 public constant DEPOSIT_MANAGER_ROLE = keccak256("DEPOSIT_MANAGER_ROLE");

    /// @notice Role for lista dependency manager permissions
    bytes32 public constant LISTA_DEPENDENCY_MANAGER_ROLE = keccak256("LISTA_DEPENDENCY_MANAGER_ROLE");

    /// @notice Storage structure for strategy-specific parameters
    struct StrategyStorage {
        address interaction;
        bool syncDeposit;
        bool syncWithdraw;
        address slisBnbProvider;
        address yieldNestMpcWallet;
        address slisBnb;
    }

    /**
     * @notice Returns the current sync deposit flag.
     * @return syncDeposit The sync deposit flag.
     */
    function getSyncDeposit() public view returns (bool syncDeposit) {
        return _getStrategyStorage().syncDeposit;
    }

    /**
     * @notice Returns the current sync withdraw flag.
     * @return syncWithdraw The sync withdraw flag.
     */
    function getSyncWithdraw() public view returns (bool syncWithdraw) {
        return _getStrategyStorage().syncWithdraw;
    }

    function getInteraction() public view returns (address interaction) {
        return _getStrategyStorage().interaction;
    }

    function getSlisBnbProvider() public view returns (address slisBnbProvider) {
        return _getStrategyStorage().slisBnbProvider;
    }

    function getYieldNestMpcWallet() public view returns (address yieldNestMpcWallet) {
        return _getStrategyStorage().yieldNestMpcWallet;
    }

    function getSlisBnb() public view returns (address slisBnb) {
        return _getStrategyStorage().slisBnb;
    }

    /**
     * @notice Internal function to handle deposits.
     * @param asset_ The address of the asset.
     * @param caller The address of the caller.
     * @param receiver The address of the receiver.
     * @param assets The amount of assets to deposit.
     * @param shares The amount of shares to mint.
     * @param baseAssets The base asset conversion of shares.
     */
    function _deposit(
        address asset_,
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares,
        uint256 baseAssets
    ) internal virtual override onlyAllocator {
        
        if (asset_ != asset()) {
            revert UnSupportedAsset(asset_);
        }

        super._deposit(asset_, caller, receiver, assets, shares, baseAssets);

        StrategyStorage storage strategyStorage = _getStrategyStorage();
        if (strategyStorage.syncDeposit) {
            SafeERC20.safeIncreaseAllowance(IERC20(asset_), address(strategyStorage.slisBnbProvider), assets);
            ISlisBnbProvider(strategyStorage.slisBnbProvider).provide(assets, strategyStorage.yieldNestMpcWallet);
        }
    }

    /**
     * @notice Internal function to handle withdrawals for specific assets.
     * @param asset_ The address of the asset.
     * @param caller The address of the caller.
     * @param receiver The address of the receiver.
     * @param owner The address of the owner.
     * @param assets The amount of assets to withdraw.
     * @param shares The equivalent amount of shares.
     */
    function _withdrawAsset(
        address asset_,
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override onlyAllocator {
        if (!_getBaseStrategyStorage().isAssetWithdrawable[asset_]) {
            revert AssetNotWithdrawable();
        }
        
        if (asset_ != asset()) {
            revert UnSupportedAsset(asset_);
        }

        _subTotalAssets(_convertAssetToBase(asset_, assets));

        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        // NOTE: burn shares before withdrawing the assets
        _burn(owner, shares);

        uint256 vaultBalance = IERC20(asset_).balanceOf(address(this));

        StrategyStorage storage strategyStorage = _getStrategyStorage();
        if (vaultBalance < assets && strategyStorage.syncWithdraw) {
            uint256 amountToUnstake = assets - vaultBalance;
            ISlisBnbProvider(strategyStorage.slisBnbProvider).release(address(this), amountToUnstake);
        }

        SafeERC20.safeTransfer(IERC20(asset_), receiver, assets);

        emit WithdrawAsset(caller, receiver, owner, asset_, assets, shares);
    }

    /**
     * @notice Internal function to get the available amount of assets.
     * @param asset_ The address of the asset.
     * @return availableAssets The available amount of assets.
     */
    function _availableAssets(address asset_) internal view virtual override returns (uint256 availableAssets) {
        availableAssets = IERC20(asset_).balanceOf(address(this));

        StrategyStorage storage strategyStorage = _getStrategyStorage();

        if (strategyStorage.syncWithdraw) {
            uint256 availableAssetsInSlisBnbProvider =
                Interaction(strategyStorage.interaction).locked(asset_, address(this));
            availableAssets += availableAssetsInSlisBnbProvider;
        }
    }

    /**
     * @notice Computes the total assets in the vault.
     * @return totalBaseBalance The total assets in the vault.
     */
    function computeTotalAssets() public view virtual override returns (uint256 totalBaseBalance) {
       address slisBnb = getSlisBnb();
       totalBaseBalance = Interaction(getInteraction()).locked(slisBnb, address(this));
    }

    function setInteraction(address interaction) external onlyRole(LISTA_DEPENDENCY_MANAGER_ROLE) {
        _getStrategyStorage().interaction = interaction;
    }

    function setSlisBnbProvider(address slisBnbProvider) external onlyRole(LISTA_DEPENDENCY_MANAGER_ROLE) {
        _getStrategyStorage().slisBnbProvider = slisBnbProvider;
    }

    function setYieldNestMpcWallet(address yieldNestMpcWallet) external onlyRole(LISTA_DEPENDENCY_MANAGER_ROLE) {
        _getStrategyStorage().yieldNestMpcWallet = yieldNestMpcWallet;
    }

    /**
     * @notice Retrieves the strategy storage structure.
     * @return $ The strategy storage structure.
     */
    function _getStrategyStorage() internal pure virtual returns (StrategyStorage storage $) {
        assembly {
            // keccak256("yieldnest.storage.clisbnb.strategy")
            $.slot := 0xb87b7aad984f77ca282edf93f55d657fc83437b8030dad945b18a51b7c01dfcc
        }
    }
 
    function _feeOnRaw(uint256) public pure override returns (uint256) {
        return 0; 
    }
    
    function _feeOnTotal(uint256) public pure override returns (uint256) {   
        return 0; 
    }
    
}