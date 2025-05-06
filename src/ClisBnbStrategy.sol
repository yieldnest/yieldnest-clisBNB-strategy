// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {IERC20, Math, SafeERC20} from "lib/yieldnest-vault/src/Common.sol";
import {BaseStrategy} from "lib/yieldnest-vault/src/strategy/BaseStrategy.sol";
import {Interaction} from "src/interfaces/Interaction.sol";
import {ISlisBnbProvider} from "src/interfaces/ISlisBnbProvider.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

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
        // lista interaction contract used to get locked slisBnb by this strategy
        Interaction listaInteraction;
        // whether to sync deposit
        bool syncDeposit;
        // slisBnb Provider contract to provide slisBnb and get clisBnb
        ISlisBnbProvider slisBnbProvider;
        // Yieldnest's institutional wallet address which holds clisBnb
        address yieldNestMpcWallet;
        // address of slisBnb
        IERC20 slisBnb;
    }

    error UnsupportedAsset(address asset);
    error InsufficientSlisBnbReceived();

    /**
     * @notice Initializes the vault with initial parameters
     * @param admin The address that will be granted the DEFAULT_ADMIN_ROLE
     * @param name The name of the strategy
     * @param symbol The symbol of the strategy
     * @param decimals_ The number of decimals for the strategy
     * @param countNativeAsset_ Whether the strategy should count native assets in total assets
     * @param alwaysComputeTotalAssets_ Whether total assets should be computed on every call
     * @param slisBnb_ The address of the slisBnb token
     * @param yieldNestMpcWallet_ The address of the Yieldnest's institutional wallet
     * @param listaInteraction_ The address of the lista interaction contract
     * @param slisBnbProvider_ The address of the slisBnb provider contract
     */
    function initialize(
        address admin,
        string memory name,
        string memory symbol,
        uint8 decimals_,
        bool countNativeAsset_,
        bool alwaysComputeTotalAssets_,
        address slisBnb_,
        address yieldNestMpcWallet_,
        address listaInteraction_,
        address slisBnbProvider_
    ) external virtual initializer {
        _initialize(
            admin,
            name,
            symbol,
            decimals_,
            countNativeAsset_,
            alwaysComputeTotalAssets_,
            slisBnb_,
            yieldNestMpcWallet_,
            listaInteraction_,
            slisBnbProvider_
        );
    }

    /**
     * @notice Internal function to initialize the vault.
     * @param admin The address of the admin.
     * @param name The name of the vault.
     * @param symbol The symbol of the vault.
     * @param decimals_ The number of decimals for the vault token.
     * @param countNativeAsset_ Whether the vault should count the native asset.
     * @param alwaysComputeTotalAssets_ Whether the vault should always compute total assets.
     * @param slisBnb_ The address of the slisBnb token
     * @param yieldNestMpcWallet_ The address of the Yieldnest's institutional wallet
     * @param listaInteraction_ The address of the lista interaction contract
     * @param slisBnbProvider_ The address of the slisBnb provider contract
     */
    function _initialize(
        address admin,
        string memory name,
        string memory symbol,
        uint8 decimals_,
        bool countNativeAsset_,
        bool alwaysComputeTotalAssets_,
        address slisBnb_,
        address yieldNestMpcWallet_,
        address listaInteraction_,
        address slisBnbProvider_
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
        _addAsset(slisBnb_, ERC20(slisBnb_).decimals(), true);
        _setAssetWithdrawable(slisBnb_, true);
        _strategyStorage().slisBnb = IERC20(slisBnb_);
        _strategyStorage().yieldNestMpcWallet = yieldNestMpcWallet_;
        _strategyStorage().listaInteraction = Interaction(listaInteraction_);
        _strategyStorage().slisBnbProvider = ISlisBnbProvider(slisBnbProvider_);
    }

    /**
     * @notice Returns the current sync deposit flag.
     * @dev If true, the strategy will instantly provide slisBnb deposited to Lista
     * @return syncDeposit The sync deposit flag.
     */
    function syncDeposit() public view returns (bool) {
        return _strategyStorage().syncDeposit;
    }

    /**
     * @notice Returns the lista interaction contract address.
     * @dev This contract is used to get locked slisBnb by this strategy
     * @return interaction The interaction contract address.
     */
    function listaInteraction() public view returns (Interaction) {
        return _strategyStorage().listaInteraction;
    }

    /**
     * @notice Returns the slisBnb provider contract address.
     * @dev This contract is used to deposit slisBnb from this strategy and get clisBnb
     * @return slisBnbProvider The slisBnb provider contract address.
     */
    function slisBnbProvider() public view returns (ISlisBnbProvider) {
        return _strategyStorage().slisBnbProvider;
    }

    /**
     * @notice Returns the Yieldnest's institutional wallet address.
     * @dev This address will hold clisBnb delegated from this strategy
     * @return yieldNestMpcWallet The Yieldnest's institutional wallet address.
     */
    function yieldNestMpcWallet() public view returns (address) {
        return _strategyStorage().yieldNestMpcWallet;
    }

    /**
     * @notice Returns the slisBnb token address.
     * @return slisBnb The slisBnb address.
     */
    function slisBnb() public view returns (IERC20) {
        return _strategyStorage().slisBnb;
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
        // call the base strategy deposit function for accounting
        super._deposit(asset_, caller, receiver, assets, shares, baseAssets);

        // if sync deposit is enabled and the asset is slisBnb, deposit the slisBnb received from caller to Lista
        if (IERC20(asset_) == slisBnb() && syncDeposit()) {
            ISlisBnbProvider _slisBnbProvider = slisBnbProvider();
            // increase allowance for the slisBnb provider contract
            SafeERC20.safeIncreaseAllowance(IERC20(asset_), address(_slisBnbProvider), assets);
            // provide the slisBnb to the slisBnb provider contract and yieldnest's institutional wallet set to recipient of clisBnb received
            _slisBnbProvider.provide(assets, yieldNestMpcWallet());
        }
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

        // call the base strategy withdraw function for accounting
        _subTotalAssets(_convertAssetToBase(asset_, assets));

        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        // NOTE: burn shares before withdrawing the assets
        _burn(owner, shares);

        uint256 vaultBalance = IERC20(asset_).balanceOf(address(this));

        // if the vault balance is less than the assets to withdraw, unstake the slisBnb
        if (vaultBalance < assets) {
            // withdraw is allowed only for the base asset(i.e. slisBnb for this strategy)
            if (IERC20(asset_) != slisBnb()) {
                revert UnsupportedAsset(asset_);
            }
            uint256 amountToUnstake = assets - vaultBalance;
            // unstake the slisBnb
            slisBnbProvider().release(address(this), amountToUnstake);
            // check if the amount of slisBnb received is less than the amount to unstake
            uint256 slisBnbAmountReceived = slisBnb().balanceOf(address(this)) - vaultBalance;
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
        IERC20 _slisBnb = slisBnb();
        if (asset_ == address(_slisBnb)) {
            availableAssets = _slisBnb.balanceOf(address(this));
            // add the locked slisBnb to the available assets as it can be 1:1 claimable by this strategy from Lista
            availableAssets += listaInteraction().locked(asset_, address(this));
        } else {
            availableAssets = super._availableAssets(asset_);
        }
    }

    /**
     * @notice Computes the total assets in the vault.
     * @dev Since this strategy only supports slisBnb, this function will return the total balance of slisBnb managed by the vault.
     * @return totalBaseBalance The total assets in the vault in slisBnb.
     */
    function computeTotalAssets() public view virtual override returns (uint256 totalBaseBalance) {
        totalBaseBalance = super.computeTotalAssets();
        // get the slisBnb address
        IERC20 _slisBnb = slisBnb();
        // get the locked slisBnb by this strategy from Lista
        // @dev the amount of slisBnb present in vault is already included in totalBaseBalance during call to super.computeTotalAssets()
        totalBaseBalance += listaInteraction().locked(address(_slisBnb), address(this));
    }

    /**
     * @notice Sets the Yieldnest's institutional wallet address.
     * @param _yieldNestMpcWallet The address of the Yieldnest's institutional wallet.
     */
    function setYieldNestMpcWallet(address _yieldNestMpcWallet) external onlyRole(LISTA_DEPENDENCY_MANAGER_ROLE) {
        _strategyStorage().yieldNestMpcWallet = _yieldNestMpcWallet;
    }

    /**
     * @notice Sets the sync deposit flag.
     * @param _syncDeposit The sync deposit flag.
     */
    function setSyncDeposit(bool _syncDeposit) external onlyRole(DEPOSIT_MANAGER_ROLE) {
        _strategyStorage().syncDeposit = _syncDeposit;
    }

    /**
     * @notice Retrieves the strategy storage structure.
     * @return $ The strategy storage structure.
     */
    function _strategyStorage() internal pure virtual returns (StrategyStorage storage $) {
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
