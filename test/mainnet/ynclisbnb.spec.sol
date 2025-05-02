// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {MainnetActors} from "script/Actors.sol";
import {MainnetContracts as MC} from "script/Contracts.sol";
import {ClisBnbStrategy, UnSupportedAsset} from "src/ClisBnbStrategy.sol";
import {Interaction} from "src/interfaces/Interaction.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {TransparentUpgradeableProxy} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ClisBnbStrategyRateProvider} from "src/module/ClisBnbStrategyRateProvider.sol";
import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

contract YnClisBnbStrategyTest is Test, MainnetActors {

    ClisBnbStrategy public clisBnbStrategy;
    ClisBnbStrategyRateProvider public clisBnbStrategyRateProvider;
    IERC20 public baseAsset; // base asset of clisBnbStrategy will be slisBnb
    IERC20 public wbnb;
    IERC20 public slisBnb;
    IERC20 public clisBnb;
    Interaction public interaction;

    function setUp() public virtual {

        ClisBnbStrategy clisBnbStrategyImplementation = new ClisBnbStrategy();
        clisBnbStrategy = ClisBnbStrategy(payable(address(new TransparentUpgradeableProxy(address(clisBnbStrategyImplementation), ADMIN, abi.encodeWithSelector(ClisBnbStrategy.initialize.selector, ADMIN, "YieldNest ClisBnB strategy", "ynClisBnb", 18, false, true)))));
        clisBnbStrategyRateProvider = new ClisBnbStrategyRateProvider();

        interaction = Interaction(MC.INTERACTION);
        baseAsset = IERC20(MC.SLIS_BNB);
        wbnb = IERC20(MC.WBNB);
        slisBnb = IERC20(MC.SLIS_BNB);
        clisBnb = IERC20(MC.CLIS_BNB);
       
        vm.startPrank(ADMIN);
        clisBnbStrategy.grantRole(clisBnbStrategy.PROCESSOR_ROLE(), PROCESSOR);
        clisBnbStrategy.grantRole(clisBnbStrategy.PROVIDER_MANAGER_ROLE(), PROVIDER_MANAGER);
        clisBnbStrategy.grantRole(clisBnbStrategy.ASSET_MANAGER_ROLE(), ASSET_MANAGER);
        clisBnbStrategy.grantRole(clisBnbStrategy.PROCESSOR_MANAGER_ROLE(), PROCESSOR_MANAGER);
        clisBnbStrategy.grantRole(clisBnbStrategy.PAUSER_ROLE(), PAUSER);
        clisBnbStrategy.grantRole(clisBnbStrategy.UNPAUSER_ROLE(), UNPAUSER);

        clisBnbStrategy.grantRole(clisBnbStrategy.DEPOSIT_MANAGER_ROLE(), ADMIN);
        clisBnbStrategy.grantRole(clisBnbStrategy.LISTA_DEPENDENCY_MANAGER_ROLE(), ADMIN);
        clisBnbStrategy.grantRole(clisBnbStrategy.KEEPER_ROLE(), KEEPER);

        clisBnbStrategy.setProvider(address(clisBnbStrategyRateProvider));
        clisBnbStrategy.setSyncDeposit(true);
        clisBnbStrategy.setInteraction(address(interaction));
        clisBnbStrategy.setSlisBnbProvider(MC.SLIS_BNB_PROVIDER);
        clisBnbStrategy.setYieldNestMpcWallet(MC.YIELDNEST_MPC_WALLET);
        clisBnbStrategy.setSlisBnb(MC.SLIS_BNB);

        clisBnbStrategy.addAsset(MC.SLIS_BNB, true);
        // Set SLIS_BNB as withdrawable
        clisBnbStrategy.setAssetWithdrawable(MC.SLIS_BNB, true);

        clisBnbStrategy.unpause();

        vm.stopPrank();

        clisBnbStrategy.processAccounting();
    }

    function test_Vault_ERC20_view_functions() public view {
        // Test the name function
        assertEq(
            clisBnbStrategy.name(),
            "YieldNest ClisBnB strategy",
            "Vault name should be 'YieldNest ClisBnB strategy'"
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

        assertEq(clisBnbStrategy.provider(), address(clisBnbStrategyRateProvider), "Vault provider should be ClisBnbStrategyRateProvider");
        assertEq(clisBnbStrategy.getInteraction(), address(interaction), "Vault interaction should be Interaction");
        assertEq(clisBnbStrategy.getSlisBnbProvider(), MC.SLIS_BNB_PROVIDER, "Vault slisBnbProvider should be SLIS_BNB_PROVIDER");
        assertEq(clisBnbStrategy.getYieldNestMpcWallet(), MC.YIELDNEST_MPC_WALLET, "Vault yieldNestMpcWallet should be YIELDNEST_MPC_WALLET");
        assertEq(clisBnbStrategy.getSlisBnb(), MC.SLIS_BNB, "Vault slisBnb should be SLIS_BNB");
        assertEq(clisBnbStrategy.getSyncDeposit(), true, "Vault syncDeposit should be true");

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
        address depositor = makeAddr("depositor");
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
        assertEq(baseAsset.balanceOf(depositor), depositorAssetBefore + depositAmount, "Asset balance of depositor incorrect after deal");

        uint256 clisBnbBalanceOfYieldnestMpcWalletBefore = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);
        vm.startPrank(depositor);
        // Approve vault to spend Asset
        baseAsset.approve(address(clisBnbStrategy), depositAmount);
        // Deposit Asset to get shares
        uint256 shares = clisBnbStrategy.deposit(depositAmount, depositor);
        vm.stopPrank();

        // Check balances after deposit
        assertEq(baseAsset.balanceOf(depositor), depositorAssetBefore, "Asset balance of depositor incorrect");
        assertEq(clisBnbStrategy.balanceOf(depositor), depositorSharesBefore + shares, "Share balance of depositor incorrect");

        // Check vault state after deposit
        assertEq(
            clisBnbStrategy.totalAssets(), initialTotalAssets + depositAmount, "Total assets of vault should increase by deposit amount after deposit"
        );
        assertEq(clisBnbStrategy.totalSupply(), initialTotalSupply + shares, "Total supply of vault should increase by shares after deposit");

        // Check that vault Asset balance increased by deposit amount
        assertEq(_getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy)), vaultStakedSlisBnbBefore + depositAmount, "Vault's staked slisBnb balance should increase by deposit amount after deposit");
    
        assertApproxEqRel(clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET), clisBnbBalanceOfYieldnestMpcWalletBefore + depositAmount, 5e16, "ClisBnb balance of YieldnestMpcWallet should increase by 95% of deposit amount after deposit");
    }

    function test_Vault_Multiple_Deposit_SlisBnb_SyncDeposit_Enabled(uint256 depositAmount1, uint256 depositAmount2) public {

        test_Vault_Deposit_SlisBnb_SyncDeposit_Enabled(depositAmount1);
        test_Vault_Deposit_SlisBnb_SyncDeposit_Enabled(depositAmount2);
    }

    function test_Vault_Deposit_SlisBnb_SyncDeposit_Disabled(uint256 depositAmount) public {

        vm.startPrank(ADMIN);
        clisBnbStrategy.setSyncDeposit(false);
        vm.stopPrank();

        address depositor = makeAddr("depositor");
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

        assertEq(baseAsset.balanceOf(depositor), depositorAssetBefore + depositAmount, "Asset balance of depositor incorrect after deal");
        uint256 clisBnbBalanceOfYieldnestMpcWalletBefore = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);
        vm.startPrank(depositor);
        // Approve vault to spend Asset
        baseAsset.approve(address(clisBnbStrategy), depositAmount);
        // Deposit Asset to get shares
        uint256 shares = clisBnbStrategy.deposit(depositAmount, depositor);

        vm.stopPrank();

        // Check balances after deposit
        assertEq(baseAsset.balanceOf(depositor), depositorAssetBefore, "Asset balance of depositor incorrect");
        assertEq(clisBnbStrategy.balanceOf(depositor), depositorSharesBefore + shares, "Share balance of depositor incorrect");

        // Check vault state after deposit
        assertEq(
            clisBnbStrategy.totalAssets(), initialTotalAssets + depositAmount, "Total assets of vault should increase by deposit amount after deposit"
        );
        assertEq(clisBnbStrategy.totalSupply(), initialTotalSupply + shares, "Total supply of vault should increase by shares after deposit");

        // Check that vault Asset balance increased by deposit amount
        assertEq(_getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy)), vaultStakedSlisBnbBefore, "Vault's staked slisBnb balance should increase by deposit amount after deposit");
        assertEq(slisBnb.balanceOf(address(clisBnbStrategy)), slisBnbBalanceOfVaultBefore + depositAmount, "Vault's slisBnb balance should increase by deposit amount after deposit");
        assertEq(clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET), clisBnbBalanceOfYieldnestMpcWalletBefore, "ClisBnb balance of YieldnestMpcWallet should not change by deposit when syncDeposit is disabled");
    }

    function test_Vault_Deposit_NonBaseAsset_Reverts() public {
        address depositor = makeAddr("depositor");
        uint256 depositAmount = 1 ether;
        
        deal(address(wbnb), depositor, depositAmount);

        vm.startPrank(depositor);
        wbnb.approve(address(clisBnbStrategy), depositAmount);
        vm.expectRevert(abi.encodeWithSelector(UnSupportedAsset.selector, address(wbnb)));
        clisBnbStrategy.depositAsset(address(wbnb), depositAmount, depositor);
        vm.stopPrank();
    }

    function test_Vault_Redeem(uint256 depositAmount) public {
        address depositor = makeAddr("depositor");
        depositAmount = bound(depositAmount, 1000 wei, 1000000 ether);

        // Give depositor some baseAsset
        deal(address(baseAsset), depositor, depositAmount);

        assertEq(baseAsset.balanceOf(depositor), depositAmount, "Asset balance of depositor incorrect after deal");

        vm.startPrank(depositor);
        // Approve vault to spend Asset
        baseAsset.approve(address(clisBnbStrategy), depositAmount);
        // Deposit Asset to get shares
        uint256 shares = clisBnbStrategy.deposit(depositAmount, depositor);

        uint256 slisBnbWithdrawable = clisBnbStrategy.previewRedeem(shares);
        assertApproxEqAbs(slisBnbWithdrawable, depositAmount, 1, "SlisBnb withdrawable should be equal to deposit amount");

        uint256 slisBnbBalanceOfVaultBefore = slisBnb.balanceOf(address(clisBnbStrategy));
        uint256 slisBnbBalanceOfDepositorBefore = slisBnb.balanceOf(depositor);
        uint256 stakedSlisBnbBalanceOfVaultBefore = _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy));

        uint256 redeemAmount = clisBnbStrategy.redeem(shares, depositor, depositor);

        assertEq(slisBnb.balanceOf(address(clisBnbStrategy)), slisBnbBalanceOfVaultBefore, "SlisBnb balance of vault should not change by redeem");
        assertEq(slisBnb.balanceOf(depositor), slisBnbBalanceOfDepositorBefore + redeemAmount, "SlisBnb balance of depositor should increase by redeem amount");
        assertEq(clisBnbStrategy.balanceOf(depositor), 0, "Share balance of depositor should be 0");
        assertEq(_getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy)), stakedSlisBnbBalanceOfVaultBefore - redeemAmount, "Staked slisBnb balance of vault should decrease by redeem amount");
    }

    function test_Vault_Reward_Stream(uint256 depositAmount, uint256 rewardAmount) public {
        test_Vault_Deposit_SlisBnb_SyncDeposit_Enabled(depositAmount);
        rewardAmount = bound(rewardAmount, 0.1 ether, 1000000 ether);
        
        deal(address(slisBnb), DEPOSIT_MANAGER, rewardAmount);

        uint256 clisBnbStrategyRateBefore = clisBnbStrategy.previewRedeem(1 ether);
        uint256 totalAssetsBefore = clisBnbStrategy.totalAssets();
        uint256 totalSupplyBefore = clisBnbStrategy.totalSupply();
        uint256 slisBnbLockedInVaultBefore = _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy));
        uint256 clisBnbBalanceOfYieldnestMpcWalletBefore = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);

        vm.startPrank(DEPOSIT_MANAGER);
        slisBnb.transfer(address(clisBnbStrategy), rewardAmount);
        vm.stopPrank();

        uint256 clisBnbStrategyRateAfter = clisBnbStrategy.previewRedeem(1 ether);
        uint256 totalAssetsAfter = clisBnbStrategy.totalAssets();
        uint256 totalSupplyAfter = clisBnbStrategy.totalSupply();
        uint256 slisBnbLockedInVaultAfter = _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy));
        assertGt(clisBnbStrategyRateAfter, clisBnbStrategyRateBefore, "ClisBnb strategy rate should increase due to reward stream");
        assertEq(totalAssetsAfter, totalAssetsBefore + rewardAmount, "Total assets of vault should increase by reward amount");
        assertEq(totalSupplyAfter, totalSupplyBefore, "Total supply of vault should not change");
        assertEq(slisBnbLockedInVaultAfter, slisBnbLockedInVaultBefore, "SlisBnb locked in vault should not change");
        assertEq(clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET), clisBnbBalanceOfYieldnestMpcWalletBefore, "ClisBnb balance of YieldnestMpcWallet should not change");
    }

    function test_Vault_Reward_Stream_Allocation(uint256 depositAmount, uint256 rewardAmount) public {
        rewardAmount = bound(rewardAmount, 0.1 ether, 1000000 ether);
        
        test_Vault_Reward_Stream(depositAmount, rewardAmount);

        uint256 totalAssets = clisBnbStrategy.totalAssets();
        uint256 totalSupply = clisBnbStrategy.totalSupply();
        uint256 clisBnbStrategyRate = clisBnbStrategy.previewRedeem(1 ether);
        uint256 slisBnbLockedInVaultBefore = _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy));
        uint256 clisBnbBalanceOfYieldnestMpcWalletBefore = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);

        vm.startPrank(KEEPER);
        clisBnbStrategy.stakeSlisBnb(rewardAmount);
        vm.stopPrank();

        uint256 clisBnbStrategyRateAfter = clisBnbStrategy.previewRedeem(1 ether);
        uint256 totalAssetsAfter = clisBnbStrategy.totalAssets();
        uint256 totalSupplyAfter = clisBnbStrategy.totalSupply();
        uint256 slisBnbLockedInVaultAfter = _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy));
        assertEq(clisBnbStrategyRateAfter, clisBnbStrategyRate, "ClisBnb strategy rate should not change");
        assertEq(totalAssetsAfter, totalAssets, "Total assets of vault should not change");
        assertEq(totalSupplyAfter, totalSupply, "Total supply of vault should not change");
        assertEq(slisBnbLockedInVaultAfter, slisBnbLockedInVaultBefore + rewardAmount, "SlisBnb locked in vault should increase by reward amount");
        assertApproxEqRel(clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET), clisBnbBalanceOfYieldnestMpcWalletBefore + rewardAmount, 5e16, "ClisBnb balance of YieldnestMpcWallet should increase by 95% of reward amount");
    }

    function test_SetInteraction() public {
        address newInteraction = makeAddr("newInteraction");
        vm.startPrank(ADMIN);
        clisBnbStrategy.setInteraction(newInteraction);
        vm.stopPrank();
        assertEq(clisBnbStrategy.getInteraction(), newInteraction, "Interaction should be set to newInteraction");

        address user = makeAddr("user");
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, clisBnbStrategy.LISTA_DEPENDENCY_MANAGER_ROLE()));
        clisBnbStrategy.setInteraction(newInteraction);
        vm.stopPrank();
    }

    function test_SetSlisBnbProvider() public {
        address newSlisBnbProvider = makeAddr("newSlisBnbProvider");
        vm.startPrank(ADMIN);
        clisBnbStrategy.setSlisBnbProvider(newSlisBnbProvider);
        vm.stopPrank();
        assertEq(clisBnbStrategy.getSlisBnbProvider(), newSlisBnbProvider, "SlisBnb provider should be set to newSlisBnbProvider");
    
        address user = makeAddr("user");
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, clisBnbStrategy.LISTA_DEPENDENCY_MANAGER_ROLE()));
        clisBnbStrategy.setSlisBnbProvider(newSlisBnbProvider);
        vm.stopPrank();
    }

    function test_SetYieldNestMpcWallet() public {
        address newYieldNestMpcWallet = makeAddr("newYieldNestMpcWallet");
        vm.startPrank(ADMIN);
        clisBnbStrategy.setYieldNestMpcWallet(newYieldNestMpcWallet);
        vm.stopPrank();
        assertEq(clisBnbStrategy.getYieldNestMpcWallet(), newYieldNestMpcWallet, "YieldNestMpcWallet should be set to newYieldNestMpcWallet");
    
        address user = makeAddr("user");
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, clisBnbStrategy.LISTA_DEPENDENCY_MANAGER_ROLE()));
        clisBnbStrategy.setYieldNestMpcWallet(newYieldNestMpcWallet);
        vm.stopPrank();
    }
    
    function test_SetSlisBnb() public {
        address newSlisBnb = makeAddr("newSlisBnb");
        vm.startPrank(ADMIN);
        clisBnbStrategy.setSlisBnb(newSlisBnb);
        vm.stopPrank();
        assertEq(clisBnbStrategy.getSlisBnb(), newSlisBnb, "SlisBnb should be set to newSlisBnb");
    
        address user = makeAddr("user");
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, clisBnbStrategy.LISTA_DEPENDENCY_MANAGER_ROLE()));
        clisBnbStrategy.setSlisBnb(newSlisBnb);
        vm.stopPrank();
    }
    
    function test_SetSyncDeposit() public {
        bool newSyncDeposit = false;
        vm.startPrank(ADMIN);
        clisBnbStrategy.setSyncDeposit(newSyncDeposit);
        vm.stopPrank();
        assertEq(clisBnbStrategy.getSyncDeposit(), newSyncDeposit, "SyncDeposit should be set to newSyncDeposit");

        address user = makeAddr("user");
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, clisBnbStrategy.DEPOSIT_MANAGER_ROLE()));
        clisBnbStrategy.setSyncDeposit(newSyncDeposit);
        vm.stopPrank();
    }

     function _getStakedSlisBnbBalanceByVault(address _asset, address _vault) internal view virtual returns (uint256) {
        return interaction.locked(_asset, _vault);
    }

}