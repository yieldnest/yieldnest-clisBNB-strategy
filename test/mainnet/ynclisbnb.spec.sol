// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {MainnetActors} from "script/Actors.sol";
import {MainnetContracts as MC} from "script/Contracts.sol";
import {ClisBnbStrategy} from "src/ClisBnbStrategy.sol";
import {Interaction} from "src/interfaces/Interaction.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {TransparentUpgradeableProxy} from
    "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ClisBnbStrategyRateProvider} from "src/module/ClisBnbStrategyRateProvider.sol";
import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {ISlisBnbProvider} from "src/interfaces/ISlisBnbProvider.sol";
import {IVault} from "lib/yieldnest-vault/src/interface/IVault.sol";
import {IValidator} from "lib/yieldnest-vault/src/interface/IValidator.sol";
import {MockYnClisBnbStrategyRateProvider} from "test/mainnet/mocks/MockYnClisBnbStrategyRateProvider.sol";
import {ISlisBnbStakeManager} from "test/mainnet/mocks/MockYnBnbxProvider.sol";
import {BaseRoles} from "script/roles/BaseRoles.sol";
import {BaseRules} from "lib/yieldnest-vault/script/rules/BaseRules.sol";
import {SafeRules} from "lib/yieldnest-vault/script/rules/SafeRules.sol";
import {ProvideRules} from "script/rules/ProvideRules.sol";
import {console} from "lib/forge-std/src/console.sol";
import {IBaseStrategy} from "lib/yieldnest-vault/src/interface/IBaseStrategy.sol";

contract YnClisBnbStrategyTest is Test, MainnetActors {
    ClisBnbStrategy public clisBnbStrategy;
    ClisBnbStrategyRateProvider public clisBnbStrategyRateProvider;
    IERC20 public baseAsset; // base asset of clisBnbStrategy will be slisBnb
    IERC20 public wbnb;
    IERC20 public slisBnb;
    IERC20 public clisBnb;
    Interaction public interaction;
    address public depositor = makeAddr("depositor");
    address public timelock = makeAddr("timelock");
    MainnetActors public actors;

    error InvalidRules();

    function setUp() public virtual {
        actors = new MainnetActors();
        ClisBnbStrategy clisBnbStrategyImplementation = new ClisBnbStrategy();
        clisBnbStrategy = ClisBnbStrategy(
            payable(address(new TransparentUpgradeableProxy(address(clisBnbStrategyImplementation), timelock, "")))
        );
        address deployer = makeAddr("deployer");
        ClisBnbStrategy.Init memory init = ClisBnbStrategy.Init({
            admin: deployer,
            name: "YieldNest ClisBnB strategy",
            symbol: "ynClisBnb",
            decimals: 18,
            paused: true,
            countNativeAsset: false,
            alwaysComputeTotalAssets: true,
            defaultAssetIndex: 0,
            slisBnb: MC.SLIS_BNB,
            yieldNestMpcWallet: MC.YIELDNEST_MPC_WALLET,
            listaInteraction: MC.INTERACTION,
            slisBnbProvider: MC.SLIS_BNB_PROVIDER
        });
        clisBnbStrategy.initialize(init);
        clisBnbStrategyRateProvider = new ClisBnbStrategyRateProvider();

        interaction = Interaction(MC.INTERACTION);
        baseAsset = IERC20(MC.SLIS_BNB);
        wbnb = IERC20(MC.WBNB);
        slisBnb = IERC20(MC.SLIS_BNB);
        clisBnb = IERC20(MC.CLIS_BNB);

        vm.startPrank(deployer);
        BaseRoles.configureDefaultRoles(clisBnbStrategy, timelock, actors);
        BaseRoles.configureTemporaryRolesStrategy(clisBnbStrategy, deployer);

        clisBnbStrategy.setProvider(address(clisBnbStrategyRateProvider));
        clisBnbStrategy.setSyncDeposit(true);
        clisBnbStrategy.setHasAllocator(true);
        clisBnbStrategy.grantRole(clisBnbStrategy.ALLOCATOR_ROLE(), MC.YNBNBX);
        clisBnbStrategy.grantRole(clisBnbStrategy.ALLOCATOR_ROLE(), depositor);

        uint256 rulesLength = 2;
        uint256 i = 0;

        SafeRules.RuleParams[] memory rules = new SafeRules.RuleParams[](rulesLength);

        rules[i++] = BaseRules.getApprovalRule(MC.SLIS_BNB, MC.SLIS_BNB_PROVIDER);
        rules[i++] = ProvideRules.getProvideRule(MC.SLIS_BNB_PROVIDER, MC.YIELDNEST_MPC_WALLET);

        if (i != rulesLength) {
            revert InvalidRules();
        }

        SafeRules.setProcessorRules(clisBnbStrategy, rules, false);

        clisBnbStrategy.unpause();

        clisBnbStrategy.processAccounting();

        BaseRoles.renounceTemporaryRolesStrategy(clisBnbStrategy, deployer);
        vm.stopPrank();
    }

    function test_Vault_ERC20_view_functions() public view {
        // Test the name function
        assertEq(
            clisBnbStrategy.name(), "YieldNest ClisBnB strategy", "Vault name should be 'YieldNest ClisBnB strategy'"
        );

        // Test the symbol function
        assertEq(clisBnbStrategy.symbol(), "ynClisBnb", "Vault symbol should be 'ynClisBnb'");

        // Test the decimals function
        assertEq(clisBnbStrategy.decimals(), 18, "Vault decimals should be 18");

        // Test the totalSupply function
        assertEq(clisBnbStrategy.totalSupply(), 0, "Vault totalSupply should be 0 after initialization");
        assertEq(clisBnbStrategy.totalAssets(), 0, "Vault totalAssets should be 0 after initialization");
    }

    function test_Vault_ERC4626_view_functions() public view {
        // Test the paused function
        assertFalse(clisBnbStrategy.paused(), "Vault should not be paused");

        // Test the asset function
        assertEq(address(clisBnbStrategy.asset()), MC.SLIS_BNB, "Vault asset should be SLIS_BNB");

        assertEq(
            clisBnbStrategy.provider(),
            address(clisBnbStrategyRateProvider),
            "Vault provider should be ClisBnbStrategyRateProvider"
        );
        assertEq(
            address(clisBnbStrategy.listaInteraction()), address(interaction), "Vault interaction should be Interaction"
        );
        assertEq(
            address(clisBnbStrategy.slisBnbProvider()),
            MC.SLIS_BNB_PROVIDER,
            "Vault slisBnbProvider should be SLIS_BNB_PROVIDER"
        );
        assertEq(
            clisBnbStrategy.yieldNestMpcWallet(),
            MC.YIELDNEST_MPC_WALLET,
            "Vault yieldNestMpcWallet should be YIELDNEST_MPC_WALLET"
        );
        assertEq(address(clisBnbStrategy.slisBnb()), MC.SLIS_BNB, "Vault slisBnb should be SLIS_BNB");
        assertEq(clisBnbStrategy.syncDeposit(), true, "Vault syncDeposit should be true");

        // Test the totalAssets function
        uint256 totalAssets = clisBnbStrategy.totalAssets();
        uint256 totalSupply = clisBnbStrategy.totalSupply();
        assertEq(totalAssets, 0, "TotalAssets should be 0");
        assertEq(totalSupply, 0, "TotalSupply should be 0");

        // Test the convertToShares function
        uint256 amount = 1 ether;
        uint256 shares = clisBnbStrategy.convertToShares(amount);
        assertEq(shares, amount, "Shares should be equal to amount deposited");

        // Test the convertToAssets function
        uint256 convertedAssets = clisBnbStrategy.convertToAssets(shares);
        assertEq(convertedAssets, amount, "Converted assets should be equal to amount deposited");

        // Test the maxDeposit function
        uint256 maxDeposit = clisBnbStrategy.maxDeposit(address(this));
        assertGt(maxDeposit, 0, "Max deposit should be greater than 0");

        // Test the maxMint function
        uint256 maxMint = clisBnbStrategy.maxMint(address(this));
        assertGt(maxMint, 0, "Max mint should be greater than 0");

        // Test the maxWithdraw function
        uint256 maxWithdraw = clisBnbStrategy.maxWithdraw(address(this));
        assertEq(maxWithdraw, 0, "Max withdraw should be zero");

        // Test the maxRedeem function
        uint256 maxRedeem = clisBnbStrategy.maxRedeem(address(this));
        assertEq(maxRedeem, 0, "Max redeem should be zero");

        address[] memory assets = clisBnbStrategy.getAssets();
        assertEq(assets.length, 1, "There should be one asset in the vault");
        assertEq(assets[0], MC.SLIS_BNB, "First asset should be SLIS_BNB");
    }

    function test_Vault_Deposit_SlisBnb_SyncDeposit_Enabled(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1000 wei, 1000000 ether);
        // Initial balances
        uint256 depositorAssetBefore = baseAsset.balanceOf(depositor);
        uint256 depositorSharesBefore = clisBnbStrategy.balanceOf(depositor);

        // Store initial state
        uint256 initialTotalAssets = clisBnbStrategy.totalAssets();
        uint256 initialTotalSupply = clisBnbStrategy.totalSupply();
        // Store initial vault Asset balance
        uint256 vaultStakedSlisBnbBefore = _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy));

        // Give depositor some baseAsset
        deal(address(baseAsset), depositor, depositorAssetBefore + depositAmount);
        assertEq(
            baseAsset.balanceOf(depositor),
            depositorAssetBefore + depositAmount,
            "Asset balance of depositor incorrect after deal"
        );

        uint256 clisBnbBalanceOfYieldnestMpcWalletBefore = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);
        vm.startPrank(depositor);
        // Approve vault to spend Asset
        baseAsset.approve(address(clisBnbStrategy), depositAmount);
        // Deposit Asset to get shares
        uint256 shares = clisBnbStrategy.deposit(depositAmount, depositor);
        vm.stopPrank();

        // Check balances after deposit
        assertEq(baseAsset.balanceOf(depositor), depositorAssetBefore, "Asset balance of depositor incorrect");
        assertEq(
            clisBnbStrategy.balanceOf(depositor), depositorSharesBefore + shares, "Share balance of depositor incorrect"
        );

        // Check vault state after deposit
        assertEq(
            clisBnbStrategy.totalAssets(),
            initialTotalAssets + depositAmount,
            "Total assets of vault should increase by deposit amount after deposit"
        );
        assertEq(
            clisBnbStrategy.totalSupply(),
            initialTotalSupply + shares,
            "Total supply of vault should increase by shares after deposit"
        );

        // Check that vault Asset balance increased by deposit amount
        assertEq(
            _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy)),
            vaultStakedSlisBnbBefore + depositAmount,
            "Vault's staked slisBnb balance should increase by deposit amount after deposit"
        );

        assertApproxEqRel(
            clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET),
            clisBnbBalanceOfYieldnestMpcWalletBefore + depositAmount,
            5e16,
            "ClisBnb balance of YieldnestMpcWallet should increase by 95% of deposit amount after deposit"
        );
    }

    function test_Vault_Multiple_Deposit_SlisBnb_SyncDeposit_Enabled(uint256 depositAmount1, uint256 depositAmount2)
        public
    {
        test_Vault_Deposit_SlisBnb_SyncDeposit_Enabled(depositAmount1);
        test_Vault_Deposit_SlisBnb_SyncDeposit_Enabled(depositAmount2);
    }

    function test_Vault_Deposit_SlisBnb_SyncDeposit_Disabled(uint256 depositAmount) public {
        vm.startPrank(ADMIN);
        clisBnbStrategy.setSyncDeposit(false);
        vm.stopPrank();

        depositAmount = bound(depositAmount, 1000 wei, 1000000 ether);
        // Initial balances
        uint256 depositorAssetBefore = baseAsset.balanceOf(depositor);
        uint256 depositorSharesBefore = clisBnbStrategy.balanceOf(depositor);

        // Store initial state
        uint256 initialTotalAssets = clisBnbStrategy.totalAssets();
        uint256 initialTotalSupply = clisBnbStrategy.totalSupply();
        uint256 slisBnbBalanceOfVaultBefore = slisBnb.balanceOf(address(clisBnbStrategy));
        // Store initial vault Asset balance
        uint256 vaultStakedSlisBnbBefore = _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy));

        // Give depositor some baseAsset
        deal(address(baseAsset), depositor, depositorAssetBefore + depositAmount);

        assertEq(
            baseAsset.balanceOf(depositor),
            depositorAssetBefore + depositAmount,
            "Asset balance of depositor incorrect after deal"
        );
        uint256 clisBnbBalanceOfYieldnestMpcWalletBefore = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);
        vm.startPrank(depositor);
        // Approve vault to spend Asset
        baseAsset.approve(address(clisBnbStrategy), depositAmount);
        // Deposit Asset to get shares
        uint256 shares = clisBnbStrategy.deposit(depositAmount, depositor);

        vm.stopPrank();

        // Check balances after deposit
        assertEq(baseAsset.balanceOf(depositor), depositorAssetBefore, "Asset balance of depositor incorrect");
        assertEq(
            clisBnbStrategy.balanceOf(depositor), depositorSharesBefore + shares, "Share balance of depositor incorrect"
        );

        // Check vault state after deposit
        assertEq(
            clisBnbStrategy.totalAssets(),
            initialTotalAssets + depositAmount,
            "Total assets of vault should increase by deposit amount after deposit"
        );
        assertEq(
            clisBnbStrategy.totalSupply(),
            initialTotalSupply + shares,
            "Total supply of vault should increase by shares after deposit"
        );

        // Check that vault Asset balance increased by deposit amount
        assertEq(
            _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy)),
            vaultStakedSlisBnbBefore,
            "Vault's staked slisBnb balance should increase by deposit amount after deposit"
        );
        assertEq(
            slisBnb.balanceOf(address(clisBnbStrategy)),
            slisBnbBalanceOfVaultBefore + depositAmount,
            "Vault's slisBnb balance should increase by deposit amount after deposit"
        );
        assertEq(
            clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET),
            clisBnbBalanceOfYieldnestMpcWalletBefore,
            "ClisBnb balance of YieldnestMpcWallet should not change by deposit when syncDeposit is disabled"
        );
    }

    function test_Vault_Deposit_NonBaseAsset_Reverts() public {
        uint256 depositAmount = 1 ether;

        deal(address(wbnb), depositor, depositAmount);

        vm.startPrank(depositor);
        wbnb.approve(address(clisBnbStrategy), depositAmount);
        vm.expectRevert(abi.encodeWithSelector(ClisBnbStrategy.UnsupportedAsset.selector, address(wbnb)));
        clisBnbStrategy.depositAsset(address(wbnb), depositAmount, depositor);
        vm.stopPrank();
    }

    function test_Vault_Deposit_NonAllocator_Reverts() public {
        address nonAllocator = makeAddr("nonAllocator");
        vm.startPrank(nonAllocator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAllocator, clisBnbStrategy.ALLOCATOR_ROLE()
            )
        );
        clisBnbStrategy.deposit(1 ether, nonAllocator);
        vm.stopPrank();
    }

    function test_Vault_Withdraw_And_Redeem_NonAllocator_Reverts() public {
        address nonAllocator = makeAddr("nonAllocator");
        uint256 depositAmount = 1 ether;

        // First deposit some slisBnb to get shares
        deal(address(baseAsset), depositor, depositAmount);

        vm.startPrank(depositor);
        baseAsset.approve(address(clisBnbStrategy), depositAmount);
        uint256 shares = clisBnbStrategy.deposit(depositAmount, depositor);

        // Transfer shares to non-allocator
        clisBnbStrategy.transfer(nonAllocator, shares);
        vm.stopPrank();

        // Non-allocator tries to withdraw
        vm.startPrank(nonAllocator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAllocator, clisBnbStrategy.ALLOCATOR_ROLE()
            )
        );
        clisBnbStrategy.withdraw(depositAmount / 2, nonAllocator, nonAllocator);
        vm.stopPrank();

        // Non-allocator tries to redeem
        vm.startPrank(nonAllocator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAllocator, clisBnbStrategy.ALLOCATOR_ROLE()
            )
        );
        clisBnbStrategy.redeem(shares / 2, nonAllocator, nonAllocator);
        vm.stopPrank();

        // Test direct withdrawAsset call by non-allocator
        vm.startPrank(nonAllocator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAllocator, clisBnbStrategy.ALLOCATOR_ROLE()
            )
        );
        clisBnbStrategy.withdrawAsset(address(baseAsset), depositAmount / 2, nonAllocator, nonAllocator);
        vm.stopPrank();

        // Test direct redeemAsset call by non-allocator
        vm.startPrank(nonAllocator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAllocator, clisBnbStrategy.ALLOCATOR_ROLE()
            )
        );
        clisBnbStrategy.redeemAsset(address(baseAsset), shares / 2, nonAllocator, nonAllocator);
        vm.stopPrank();
    }

    function test_Vault_Redeem_NonAllocator_Reverts() public {
        address nonAllocator = makeAddr("nonAllocator");
        uint256 depositAmount = 1 ether;

        // First deposit some slisBnb to get shares
        deal(address(baseAsset), depositor, depositAmount);

        vm.startPrank(depositor);
        baseAsset.approve(address(clisBnbStrategy), depositAmount);
        uint256 shares = clisBnbStrategy.deposit(depositAmount, depositor);

        // Transfer shares to non-allocator
        clisBnbStrategy.transfer(nonAllocator, shares);
        vm.stopPrank();

        // Non-allocator tries to redeem
        vm.startPrank(nonAllocator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAllocator, clisBnbStrategy.ALLOCATOR_ROLE()
            )
        );
        clisBnbStrategy.redeem(shares / 2, nonAllocator, nonAllocator);
        vm.stopPrank();
    }

    function test_Vault_Withdraw_AssetNotWithdrawable_Reverts() public {
        uint256 depositAmount = 10000 ether;

        // Give depositor some baseAsset
        deal(address(baseAsset), depositor, depositAmount);

        vm.startPrank(depositor);
        // Approve vault to spend Asset
        baseAsset.approve(address(clisBnbStrategy), depositAmount);
        // Deposit Asset to get shares
        clisBnbStrategy.deposit(depositAmount, depositor);
        vm.stopPrank();

        // Add the asset using ASSET_MANAGER role
        vm.startPrank(timelock);
        clisBnbStrategy.addAsset(MC.WBNB, 18, true, false);
        clisBnbStrategy.setProvider(address(new MockYnClisBnbStrategyRateProvider()));
        vm.stopPrank();

        uint256 wbnbDealt = 100 ether;
        // Deal WBNB to the clisBnbStrategy
        deal(MC.WBNB, address(clisBnbStrategy), wbnbDealt);

        // Verify the WBNB balance of the strategy is correct
        assertEq(
            IERC20(MC.WBNB).balanceOf(address(clisBnbStrategy)),
            wbnbDealt,
            "WBNB balance of strategy should match the dealt amount"
        );

        vm.startPrank(depositor);
        // Try to withdraw the non-withdrawable asset
        vm.expectRevert(abi.encodeWithSelector(IBaseStrategy.AssetNotWithdrawable.selector));
        clisBnbStrategy.withdrawAsset(MC.WBNB, 0, depositor, depositor);

        vm.stopPrank();
    }

    function test_Vault_Withdraw_Paused_Reverts() public {
        uint256 depositAmount = 1 ether;

        // Give depositor some baseAsset
        deal(address(baseAsset), depositor, depositAmount);

        vm.startPrank(depositor);
        // Approve vault to spend Asset
        baseAsset.approve(address(clisBnbStrategy), depositAmount);
        // Deposit Asset to get shares
        clisBnbStrategy.deposit(depositAmount, depositor);
        vm.stopPrank();

        // Pause the vault
        vm.startPrank(PAUSER);
        clisBnbStrategy.pause();
        vm.stopPrank();

        // Try to withdraw when vault is paused
        vm.startPrank(depositor);
        vm.expectRevert(abi.encodeWithSelector(IVault.Paused.selector));
        clisBnbStrategy.withdraw(depositAmount / 2, depositor, depositor);
        vm.stopPrank();

        // Verify maxWithdraw and maxRedeem return 0 when vault is paused
        assertEq(clisBnbStrategy.maxWithdraw(depositor), 0, "maxWithdraw should be 0 when vault is paused");
        assertEq(clisBnbStrategy.maxRedeem(depositor), 0, "maxRedeem should be 0 when vault is paused");

        // Unpause the vault
        vm.startPrank(ADMIN);
        clisBnbStrategy.unpause();
        vm.stopPrank();

        // Verify maxWithdraw and maxRedeem return non-zero values when vault is unpaused
        assertGt(clisBnbStrategy.maxWithdraw(depositor), 0, "maxWithdraw should be > 0 when vault is unpaused");
        assertGt(clisBnbStrategy.maxRedeem(depositor), 0, "maxRedeem should be > 0 when vault is unpaused");
    }

    function test_Vault_Withdraw(uint256 depositAmount, uint256 withdrawAmount) public {
        depositAmount = bound(depositAmount, 1000 wei, 1000000 ether);
        withdrawAmount = bound(withdrawAmount, 1, depositAmount);

        // Give depositor some baseAsset
        deal(address(baseAsset), depositor, depositAmount);

        assertEq(baseAsset.balanceOf(depositor), depositAmount, "Asset balance of depositor incorrect after deal");

        vm.startPrank(depositor);
        // Approve vault to spend Asset
        baseAsset.approve(address(clisBnbStrategy), depositAmount);
        // Deposit Asset to get shares
        uint256 shares = clisBnbStrategy.deposit(depositAmount, depositor);

        uint256 slisBnbWithdrawable = clisBnbStrategy.previewRedeem(shares);
        assertApproxEqAbs(
            slisBnbWithdrawable, depositAmount, 1, "SlisBnb withdrawable should be equal to deposit amount"
        );

        uint256 slisBnbBalanceOfVaultBefore = slisBnb.balanceOf(address(clisBnbStrategy));
        uint256 slisBnbBalanceOfDepositorBefore = slisBnb.balanceOf(depositor);
        uint256 stakedSlisBnbBalanceOfVaultBefore =
            _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy));

        uint256 sharesWithdrawn = clisBnbStrategy.withdraw(withdrawAmount, depositor, depositor);

        assertEq(
            slisBnb.balanceOf(address(clisBnbStrategy)),
            slisBnbBalanceOfVaultBefore,
            "SlisBnb balance of vault should not change by withdraw"
        );
        assertEq(
            slisBnb.balanceOf(depositor),
            slisBnbBalanceOfDepositorBefore + withdrawAmount,
            "SlisBnb balance of depositor should increase by withdraw amount"
        );
        assertEq(
            clisBnbStrategy.balanceOf(depositor), shares - sharesWithdrawn, "Share balance of depositor should be 0"
        );
        assertEq(
            _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy)),
            stakedSlisBnbBalanceOfVaultBefore - withdrawAmount,
            "Staked slisBnb balance of vault should decrease by withdraw amount"
        );
    }

    function test_Vault_Reward_Stream(uint256 depositAmount, uint256 rewardAmount) public {
        test_Vault_Deposit_SlisBnb_SyncDeposit_Enabled(depositAmount);
        rewardAmount = bound(rewardAmount, 0.1 ether, 1000000 ether);

        deal(address(slisBnb), DEPOSIT_MANAGER, rewardAmount);

        uint256 clisBnbStrategyRateBefore = clisBnbStrategy.previewRedeem(1 ether);
        uint256 totalAssetsBefore = clisBnbStrategy.totalAssets();
        uint256 totalSupplyBefore = clisBnbStrategy.totalSupply();
        uint256 slisBnbLockedInVaultBefore =
            _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy));
        uint256 clisBnbBalanceOfYieldnestMpcWalletBefore = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);

        vm.startPrank(DEPOSIT_MANAGER);
        slisBnb.transfer(address(clisBnbStrategy), rewardAmount);
        vm.stopPrank();

        uint256 clisBnbStrategyRateAfter = clisBnbStrategy.previewRedeem(1 ether);
        uint256 totalAssetsAfter = clisBnbStrategy.totalAssets();
        uint256 totalSupplyAfter = clisBnbStrategy.totalSupply();
        uint256 slisBnbLockedInVaultAfter =
            _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy));
        assertGt(
            clisBnbStrategyRateAfter,
            clisBnbStrategyRateBefore,
            "ClisBnb strategy rate should increase due to reward stream"
        );
        assertEq(
            totalAssetsAfter, totalAssetsBefore + rewardAmount, "Total assets of vault should increase by reward amount"
        );
        assertEq(totalSupplyAfter, totalSupplyBefore, "Total supply of vault should not change");
        assertEq(slisBnbLockedInVaultAfter, slisBnbLockedInVaultBefore, "SlisBnb locked in vault should not change");
        assertEq(
            clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET),
            clisBnbBalanceOfYieldnestMpcWalletBefore,
            "ClisBnb balance of YieldnestMpcWallet should not change"
        );
    }

    function test_Vault_Reward_Stream_Allocation(uint256 depositAmount, uint256 rewardAmount) public {
        rewardAmount = bound(rewardAmount, 0.1 ether, 1000000 ether);

        test_Vault_Reward_Stream(depositAmount, rewardAmount);

        uint256 totalAssets = clisBnbStrategy.totalAssets();
        uint256 totalSupply = clisBnbStrategy.totalSupply();
        uint256 clisBnbStrategyRate = clisBnbStrategy.previewRedeem(1 ether);
        uint256 slisBnbLockedInVaultBefore =
            _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy));
        uint256 clisBnbBalanceOfYieldnestMpcWalletBefore = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);

        {
            vm.startPrank(PROCESSOR);
            address[] memory targets = new address[](2);
            uint256[] memory values = new uint256[](2);
            bytes[] memory datas = new bytes[](2);
            targets[0] = address(slisBnb);
            values[0] = 0;
            datas[0] = abi.encodeWithSelector(IERC20.approve.selector, MC.SLIS_BNB_PROVIDER, rewardAmount);
            targets[1] = MC.SLIS_BNB_PROVIDER;
            values[1] = 0;
            datas[1] = abi.encodeWithSelector(ISlisBnbProvider.provide.selector, rewardAmount, MC.YIELDNEST_MPC_WALLET);
            clisBnbStrategy.processor(targets, values, datas);
            vm.stopPrank();
        }

        uint256 clisBnbStrategyRateAfter = clisBnbStrategy.previewRedeem(1 ether);
        uint256 totalAssetsAfter = clisBnbStrategy.totalAssets();
        uint256 totalSupplyAfter = clisBnbStrategy.totalSupply();
        uint256 slisBnbLockedInVaultAfter =
            _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy));
        assertEq(clisBnbStrategyRateAfter, clisBnbStrategyRate, "ClisBnb strategy rate should not change");
        assertEq(totalAssetsAfter, totalAssets, "Total assets of vault should not change");
        assertEq(totalSupplyAfter, totalSupply, "Total supply of vault should not change");
        assertEq(
            slisBnbLockedInVaultAfter,
            slisBnbLockedInVaultBefore + rewardAmount,
            "SlisBnb locked in vault should increase by reward amount"
        );
        assertApproxEqRel(
            clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET),
            clisBnbBalanceOfYieldnestMpcWalletBefore + rewardAmount,
            5e16,
            "ClisBnb balance of YieldnestMpcWallet should increase by 95% of reward amount"
        );
    }

    function test_Withdraw_After_Reward_Stream_Allocation(
        uint256 depositAmount,
        uint256 rewardAmount,
        uint256 redeemAmount
    ) public {
        depositAmount = bound(depositAmount, 1000 wei, 1000000 ether);
        rewardAmount = bound(rewardAmount, 0.1 ether, 1000000 ether);

        test_Vault_Reward_Stream_Allocation(depositAmount, rewardAmount);
        clisBnbStrategy.processAccounting();

        uint256 clisBnbStrategyBalanceOfDepositorBefore = clisBnbStrategy.balanceOf(depositor);

        redeemAmount = bound(redeemAmount, 1000 wei, clisBnbStrategyBalanceOfDepositorBefore);

        uint256 totalAssetsOfClisBnbStrategyBefore = clisBnbStrategy.totalAssets();
        uint256 totalSupplyOfClisBnbStrategyBefore = clisBnbStrategy.totalSupply();
        uint256 slisBnbLockedInVaultBefore =
            _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy));
        uint256 clisBnbBalanceOfYieldnestMpcWalletBefore = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);
        uint256 slisBnbBalanceOfDepositorBefore = slisBnb.balanceOf(depositor);

        vm.startPrank(depositor);
        uint256 assetsWithdrawn = clisBnbStrategy.redeem(redeemAmount, depositor, depositor);
        assertEq(
            clisBnbStrategy.balanceOf(depositor),
            clisBnbStrategyBalanceOfDepositorBefore - redeemAmount,
            "Share balance of depositor should decrease by redeem amount"
        );
        assertEq(
            slisBnb.balanceOf(depositor),
            slisBnbBalanceOfDepositorBefore + assetsWithdrawn,
            "SlisBnb balance of depositor should increase by assets withdrawn"
        );
        assertEq(
            clisBnbStrategy.totalAssets(),
            totalAssetsOfClisBnbStrategyBefore - assetsWithdrawn,
            "Total assets of clisBnbStrategy should decrease by redeem amount"
        );
        assertEq(
            clisBnbStrategy.totalSupply(),
            totalSupplyOfClisBnbStrategyBefore - redeemAmount,
            "Total supply of clisBnbStrategy should decrease by redeem amount"
        );
        assertEq(
            _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy)),
            slisBnbLockedInVaultBefore - assetsWithdrawn,
            "Staked slisBnb balance of vault should decrease by withdraw amount"
        );
        assertLt(
            clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET),
            clisBnbBalanceOfYieldnestMpcWalletBefore,
            "ClisBnb balance of YieldnestMpcWallet should not change"
        );
    }

    function test_SetYieldNestMpcWallet() public {
        address newYieldNestMpcWallet = makeAddr("newYieldNestMpcWallet");
        vm.startPrank(ADMIN);
        clisBnbStrategy.setYieldNestMpcWallet(newYieldNestMpcWallet);
        vm.stopPrank();
        assertEq(
            clisBnbStrategy.yieldNestMpcWallet(),
            newYieldNestMpcWallet,
            "YieldNestMpcWallet should be set to newYieldNestMpcWallet"
        );

        address user = makeAddr("user");
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                user,
                clisBnbStrategy.LISTA_DEPENDENCY_MANAGER_ROLE()
            )
        );
        clisBnbStrategy.setYieldNestMpcWallet(newYieldNestMpcWallet);
        vm.stopPrank();
    }

    function test_SetSyncDeposit() public {
        bool newSyncDeposit = false;
        vm.startPrank(ADMIN);
        clisBnbStrategy.setSyncDeposit(newSyncDeposit);
        vm.stopPrank();
        assertEq(clisBnbStrategy.syncDeposit(), newSyncDeposit, "SyncDeposit should be set to newSyncDeposit");

        address user = makeAddr("user");
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, clisBnbStrategy.DEPOSIT_MANAGER_ROLE()
            )
        );
        clisBnbStrategy.setSyncDeposit(newSyncDeposit);
        vm.stopPrank();
    }

    function test_SetRateProvider() public {
        address newRateProvider = makeAddr("newRateProvider");
        vm.startPrank(timelock);
        clisBnbStrategy.setProvider(newRateProvider);
        vm.stopPrank();
        assertEq(clisBnbStrategy.provider(), newRateProvider, "RateProvider should be set to newRateProvider");
    }

    function test_deposit_With_Wbnb(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 10000 wei, 1000000 ether);
        deal(address(wbnb), depositor, depositAmount);

        _addWBNBAsAssetToClisBnbStrategy();

        uint256 wbnbBalanceBeforeOfDepositor = wbnb.balanceOf(depositor);
        uint256 totalAssetsBeforeOfClisBnbStrategy = clisBnbStrategy.totalAssets();
        uint256 totalSupplyBeforeOfClisBnbStrategy = clisBnbStrategy.totalSupply();
        uint256 wbnbBalanceBeforeOfClisBnbStrategy = wbnb.balanceOf(address(clisBnbStrategy));

        vm.startPrank(depositor);
        wbnb.approve(address(clisBnbStrategy), depositAmount);
        uint256 shares = clisBnbStrategy.depositAsset(address(wbnb), depositAmount, depositor);
        vm.stopPrank();

        uint256 amountOfSlisBnbDeposited =
            ISlisBnbStakeManager(MC.SLIS_BNB_STAKE_MANAGER).convertBnbToSnBnb(depositAmount);

        assertEq(
            wbnb.balanceOf(depositor),
            wbnbBalanceBeforeOfDepositor - depositAmount,
            "Wbnb balance of depositor should decrease by deposit amount"
        );
        assertApproxEqAbs(
            clisBnbStrategy.totalAssets(),
            totalAssetsBeforeOfClisBnbStrategy + amountOfSlisBnbDeposited,
            1e6,
            "Total assets of clisBnbStrategy should increase by deposit amount"
        );
        assertEq(
            clisBnbStrategy.totalSupply(),
            totalSupplyBeforeOfClisBnbStrategy + shares,
            "Total supply of clisBnbStrategy should increase by shares"
        );
        assertEq(
            wbnb.balanceOf(address(clisBnbStrategy)),
            wbnbBalanceBeforeOfClisBnbStrategy + depositAmount,
            "Wbnb balance of clisBnbStrategy should increase by deposit amount"
        );
    }

    function _addWBNBAsAssetToClisBnbStrategy() internal {
        vm.startPrank(timelock);
        clisBnbStrategy.addAsset(address(wbnb), true);
        MockYnClisBnbStrategyRateProvider newProvider = new MockYnClisBnbStrategyRateProvider();
        vm.stopPrank();
        vm.startPrank(timelock);
        clisBnbStrategy.setProvider(address(newProvider));
        vm.stopPrank();
    }

    function _getStakedSlisBnbBalanceByVault(address _asset, address _vault) internal view virtual returns (uint256) {
        return interaction.locked(_asset, _vault);
    }
}
