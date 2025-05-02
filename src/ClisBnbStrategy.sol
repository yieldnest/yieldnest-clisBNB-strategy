// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {IERC20, Math, SafeERC20} from "lib/yieldnest-vault/src/Common.sol";
import {BaseStrategy} from "lib/yieldnest-vault/src/strategy/BaseStrategy.sol";
import {Interaction} from "src/interfaces/Interaction.sol";
import {ISlisBnbProvider} from "src/interfaces/ISlisBnbProvider.sol";

error UnSupportedAsset(address asset);
error InsufficientSlisBnbReceived();

/**
 * @title ClisBnbStrategy
 * @notice This contract takes slisBnb as the base asset and delegates to Lista to get clisBnb in Yieldnest's institutional wallet.
 * @dev This strategy acts like a vault where users can deposit and withdraw slisBnb.
 */
contract ClisBnbStrategy is BaseStrategy {

    /// @notice Role for deposit manager permissions
    bytes32 public constant DEPOSIT_MANAGER_ROLE = keccak256("DEPOSIT_MANAGER_ROLE");

    /// @notice Role for lista dependency manager permissions
    bytes32 public constant LISTA_DEPENDENCY_MANAGER_ROLE = keccak256("LISTA_DEPENDENCY_MANAGER_ROLE");

    /// @notice Role for keeper permissions
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    /// @notice Storage structure for strategy-specific parameters
    struct StrategyStorage {
        // interaction contract used to get locked slisBnb by this strategy
        address interaction;
        // whether to sync deposit
        bool syncDeposit;
        // slisBnb Provider contract to provide slisBnb and get clisBnb
        address slisBnbProvider;
        // Yieldnest's institutional wallet address which holds clisBnb
        address yieldNestMpcWallet;
        // address of slisBnb
        address slisBnb;
    }

    
    /**
     * @notice Initializes the vault with initial parameters
     * @param admin The address that will be granted the DEFAULT_ADMIN_ROLE
     * @param name The name of the strategy 
     * @param symbol The symbol of the strategy 
     * @param decimals_ The number of decimals for the strategy
     * @param countNativeAsset_ Whether the strategy should count native assets in total assets
     * @param alwaysComputeTotalAssets_ Whether total assets should be computed on every call
     */
    function initialize(
        address admin,
        string memory name,
        string memory symbol,
        uint8 decimals_,
        bool countNativeAsset_,
        bool alwaysComputeTotalAssets_
    ) external virtual initializer {
        _initialize(admin, name, symbol, decimals_, countNativeAsset_, alwaysComputeTotalAssets_);
    }

    /**
     * @notice Internal function to initialize the vault.
     * @param admin The address of the admin.
     * @param name The name of the vault.
     * @param symbol The symbol of the vault.
     * @param decimals_ The number of decimals for the vault token.
     * @param countNativeAsset_ Whether the vault should count the native asset.
     * @param alwaysComputeTotalAssets_ Whether the vault should always compute total assets.
     */
    function _initialize(
        address admin,
        string memory name,
        string memory symbol,
        uint8 decimals_,
        bool countNativeAsset_,
        bool alwaysComputeTotalAssets_
    ) internal virtual {
        __ERC20_init(name, symbol);
        __AccessControl_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        VaultStorage storage vaultStorage = _getVaultStorage();
        vaultStorage.paused = true;
        vaultStorage.decimals = decimals_;
        vaultStorage.countNativeAsset = countNativeAsset_;
        vaultStorage.alwaysComputeTotalAssets = alwaysComputeTotalAssets_;

    }

    /**
     * @notice Returns the current sync deposit flag.
     * @dev If true, the strategy will instantly provide slisBnb deposited to Lista
     * @return syncDeposit The sync deposit flag.
     */
    function getSyncDeposit() public view returns (bool syncDeposit) {
        return _getStrategyStorage().syncDeposit;
    }

    /**
     * @notice Returns the interaction contract address.
     * @dev This contract is used to get locked slisBnb by this strategy
     * @return interaction The interaction contract address.
     */
    function getInteraction() public view returns (address interaction) {
        return _getStrategyStorage().interaction;
    }

    /**
     * @notice Returns the slisBnb provider contract address.
     * @dev This contract is used to deposit slisBnb from this strategy and get clisBnb
     * @return slisBnbProvider The slisBnb provider contract address.
     */
    function getSlisBnbProvider() public view returns (address slisBnbProvider) {
        return _getStrategyStorage().slisBnbProvider;
    }

    /**
     * @notice Returns the Yieldnest's institutional wallet address.
     * @dev This address will hold clisBnb delegated from this strategy
     * @return yieldNestMpcWallet The Yieldnest's institutional wallet address.
     */
    function getYieldNestMpcWallet() public view returns (address yieldNestMpcWallet) {
        return _getStrategyStorage().yieldNestMpcWallet;
    }

    /**
     * @notice Returns the slisBnb token address.
     * @return slisBnb The slisBnb address.
     */
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
    ) internal virtual override {
        
        // deposit is allowed only for the base asset(i.e. slisBnb for this strategy)
        if (asset_ != asset()) {
            revert UnSupportedAsset(asset_);
        }

        // call the base strategy deposit function for accounting
        super._deposit(asset_, caller, receiver, assets, shares, baseAssets);

        StrategyStorage storage strategyStorage = _getStrategyStorage();
        // if sync deposit is enabled, deposit the slisBnb received from caller to Lista
        if (strategyStorage.syncDeposit) {
            // increase allowance for the slisBnb provider contract
            SafeERC20.safeIncreaseAllowance(IERC20(asset_), address(strategyStorage.slisBnbProvider), assets);
            // provide the slisBnb to the slisBnb provider contract and yieldnest's institutional wallet set to recipient of clisBnb received
            ISlisBnbProvider(strategyStorage.slisBnbProvider).provide(assets, strategyStorage.yieldNestMpcWallet);
        }
    }

    
    /**
     * @notice Stakes slisBnb tokens into the provider contract
     * @dev Only callable by accounts with KEEPER_ROLE. This will be used if there is additional slisBnb 
     * delegated to this strategy when sync deposit is disabled and for rewards sent to this strategy
     * @param amount The amount of slisBnb tokens to stake
     */
    function stakeSlisBnb(uint256 amount) external onlyRole(KEEPER_ROLE) {
        address slisBnb = getSlisBnb();
        StrategyStorage storage strategyStorage = _getStrategyStorage();
        // increase allowance for the slisBnb provider contract
        SafeERC20.safeIncreaseAllowance(IERC20(slisBnb), address(strategyStorage.slisBnbProvider), amount);
        // provide the slisBnb to the slisBnb provider contract and yieldnest's institutional wallet set to recipient of clisBnb received
        ISlisBnbProvider(strategyStorage.slisBnbProvider).provide(amount, strategyStorage.yieldNestMpcWallet);
    }

    /**
     * @notice Internal function to handle withdrawals for base asset(i.e. slisBnb for this strategy).
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
    ) internal virtual override {
        // check if the asset is withdrawable
        if (!_getBaseStrategyStorage().isAssetWithdrawable[asset_]) {
            revert AssetNotWithdrawable();
        }
        // withdraw is allowed only for the base asset(i.e. slisBnb for this strategy)
        if (asset_ != asset()) {
            revert UnSupportedAsset(asset_);
        }

        // call the base strategy withdraw function for accounting
        _subTotalAssets(assets);

        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        // NOTE: burn shares before withdrawing the assets
        _burn(owner, shares);

        uint256 vaultBalance = IERC20(asset_).balanceOf(address(this));

        StrategyStorage storage strategyStorage = _getStrategyStorage();
        // if the vault balance is less than the assets to withdraw, unstake the slisBnb
        if (vaultBalance < assets) {
            uint256 amountToUnstake = assets - vaultBalance;
            // unstake the slisBnb
            ISlisBnbProvider(strategyStorage.slisBnbProvider).release(address(this), amountToUnstake);
            // check if the amount of slisBnb received is less than the amount to unstake
            uint256 slisBnbAmountReceived = IERC20(strategyStorage.slisBnb).balanceOf(address(this)) - vaultBalance;
            // if the amount of slisBnb received is less than the amount to unstake, revert
            // this can be possible if withdrawal is changed from instant to delayed by Lista for slisBnb
            if (slisBnbAmountReceived < amountToUnstake) {
                revert InsufficientSlisBnbReceived();
            }
        }

        // transfer the assets to the receiver
        SafeERC20.safeTransfer(IERC20(asset_), receiver, assets);

        emit WithdrawAsset(caller, receiver, owner, asset_, assets, shares);
    }

    /**
     * @notice Internal function to get the available amount of assets.
     * @dev This function is used for slisBnb asset
     * @param asset_ The address of the asset.
     * @return availableAssets The available amount of assets.
     */
    function _availableAssets(address asset_) internal view virtual override returns (uint256 availableAssets) {
        StrategyStorage storage strategyStorage = _getStrategyStorage();
        availableAssets = IERC20(asset_).balanceOf(address(this));
        if (asset_ == strategyStorage.slisBnb) {
            // add the locked slisBnb to the available assets as it can be 1:1 claimable by this strategy from Lista
            availableAssets += Interaction(strategyStorage.interaction).locked(asset_, address(this));
        }
        return availableAssets;
    }

    /**
     * @notice Computes the total assets in the vault.
     * @dev Since this strategy only supports slisBnb, this function will return the total balance of slisBnb managed by the vault.
     * @return totalBaseBalance The total assets in the vault in slisBnb.
     */
    function computeTotalAssets() public view virtual override returns (uint256 totalBaseBalance) {
        // get the slisBnb address
        address slisBnb = getSlisBnb();
        // get the locked slisBnb by this strategy from Lista
        totalBaseBalance = Interaction(getInteraction()).locked(slisBnb, address(this));
        // add the balance of slisBnb in the vault
        totalBaseBalance += IERC20(slisBnb).balanceOf(address(this));
    }

    /**
     * @notice Sets the interaction contract address.
     * @param interaction The address of the interaction contract.
     */
    function setInteraction(address interaction) external onlyRole(LISTA_DEPENDENCY_MANAGER_ROLE) {
        _getStrategyStorage().interaction = interaction;
    }

    /**
     * @notice Sets the slisBnb provider contract address.
     * @param slisBnbProvider The address of the slisBnb provider contract.
     */
    function setSlisBnbProvider(address slisBnbProvider) external onlyRole(LISTA_DEPENDENCY_MANAGER_ROLE) {
        _getStrategyStorage().slisBnbProvider = slisBnbProvider;
    }

    /**
     * @notice Sets the Yieldnest's institutional wallet address.
     * @param yieldNestMpcWallet The address of the Yieldnest's institutional wallet.
     */
    function setYieldNestMpcWallet(address yieldNestMpcWallet) external onlyRole(LISTA_DEPENDENCY_MANAGER_ROLE) {
        _getStrategyStorage().yieldNestMpcWallet = yieldNestMpcWallet;
    }

    /**
     * @notice Sets the slisBnb address.
     * @param slisBnb The address of the slisBnb.
     */
    function setSlisBnb(address slisBnb) external onlyRole(LISTA_DEPENDENCY_MANAGER_ROLE) {
        _getStrategyStorage().slisBnb = slisBnb;
    }

    /**
     * @notice Sets the sync deposit flag.
     * @param syncDeposit The sync deposit flag.
     */
    function setSyncDeposit(bool syncDeposit) external onlyRole(DEPOSIT_MANAGER_ROLE) {
        _getStrategyStorage().syncDeposit = syncDeposit;
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

    /**
     * @notice Returns the fee on raw amount.
     * @return 0 as this strategy does not charge any fee on raw amount.
     */
    function _feeOnRaw(uint256) public pure override returns (uint256) {
        return 0; 
    }

    /**
     * @notice Returns the fee on total amount.
     * @return 0 as this strategy does not charge any fee on total amount.
     */
    function _feeOnTotal(uint256) public pure override returns (uint256) {   
        return 0; 
    }
    
}