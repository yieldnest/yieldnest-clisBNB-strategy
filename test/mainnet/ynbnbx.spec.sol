// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {MainnetContracts as MC} from "script/Contracts.sol";
import {Vault} from "lib/yieldnest-vault/src/Vault.sol";
import {console} from "lib/forge-std/src/console.sol";
import {MainnetActors} from "script/Actors.sol";
import {BaseVault} from "lib/yieldnest-vault/src/BaseVault.sol";
import {IVault} from "lib/yieldnest-vault/src/interface/IVault.sol";
import {IValidator} from "lib/yieldnest-vault/src/interface/IValidator.sol";
import {IStrategy} from "lib/yieldnest-vault/src/interface/IStrategy.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {BaseStrategy} from "lib/yieldnest-vault/src/strategy/BaseStrategy.sol";
import {IProvider} from "lib/yieldnest-vault/src/interface/IProvider.sol";
import {YnClisBnbStrategyTest} from "test/mainnet/ynclisbnb.spec.sol";
import {ClisBnbStrategy} from "src/ClisBnbStrategy.sol";
import {ClisBnbStrategyRateProvider} from "src/module/ClisBnbStrategyRateProvider.sol";
import {Interaction} from "src/interfaces/Interaction.sol";
import {MockYnBnbxProvider} from "test/mainnet/mocks/MockYnBnbxProvider.sol";
import {ISlisBnbProvider} from "src/interfaces/ISlisBnbProvider.sol";

contract YnBNBxTest is Test, MainnetActors, YnClisBnbStrategyTest {
    Vault public ynBNBx;
    BaseStrategy public ynasBNBK;
    IProvider public ynBNBxProvider;

    function setUp() public override {
        super.setUp();
        ynBNBx = Vault(payable(MC.YNBNBX));
        ynasBNBK = BaseStrategy(payable(MC.YNASBNBK));
        ynBNBxProvider = IProvider(ynBNBx.provider());
        {
            // grant role
            vm.startPrank(YnSecurityCouncil);
            ynBNBx.grantRole(ynBNBx.PROCESSOR_MANAGER_ROLE(), PROCESSOR_MANAGER);
            ynBNBx.grantRole(ynBNBx.ASSET_MANAGER_ROLE(), ASSET_MANAGER);
            ynBNBx.grantRole(ynBNBx.PROVIDER_MANAGER_ROLE(), PROVIDER_MANAGER);
            vm.stopPrank();
        }

        {
            IVault.FunctionRule memory rule = IVault.FunctionRule({
                isActive: true,
                paramRules: new IVault.ParamRule[](0),
                validator: IValidator(address(0))
            });

            // add rule for processor
            vm.startPrank(PROCESSOR_MANAGER);
            // only the redeem rule is not added yet
            ynBNBx.setProcessorRule(address(clisBnbStrategy), BaseVault.redeem.selector, rule);
            vm.stopPrank();
        }

        // process accounting on each vault
        ynBNBx.processAccounting();
        ynasBNBK.processAccounting();
        clisBnbStrategy.processAccounting();
    }

    function test_ynBNBx_assets_and_rates() public {
        // Check if slisBNB is an asset of ynBNBx
        address[] memory assets = ynBNBx.getAssets();
        bool slisBnbIsAsset = false;
        bool clisBnbStrategyIsAsset = false;

        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == address(slisBnb)) {
                assertFalse(slisBnbIsAsset, "slisBNB should not be duplicated");
                slisBnbIsAsset = true;
            }
            if (assets[i] == address(clisBnbStrategy)) {
                assertFalse(clisBnbStrategyIsAsset, "clisBNB Strategy should not be duplicated");
                clisBnbStrategyIsAsset = true;
            }
        }

        assertTrue(slisBnbIsAsset, "slisBNB should be an asset of ynBNBx");
        assertTrue(clisBnbStrategyIsAsset, "clisBnbStrategy should be an asset of ynBNBx");

        // Check that the provider returns a rate for both assets
        vm.startPrank(address(ynBNBx));
        uint256 slisBnbRate = ynBNBxProvider.getRate(address(slisBnb));
        uint256 clisBnbStrategyRate = ynBNBxProvider.getRate(address(clisBnbStrategy));
        vm.stopPrank();

        assertGt(slisBnbRate, 0, "Provider should return a rate greater than 0 for slisBNB");
        assertGt(clisBnbStrategyRate, 0, "Provider should return a rate greater than 0 for clisBnbStrategy");

        // Check that clisBnbStrategy rate is greater than or equal to the slisBNB rate
        assertGe(
            clisBnbStrategyRate, slisBnbRate, "clisBnbStrategy rate should be greater than or equal to slisBNB rate"
        );
    }

    function test_ynBNBx_deposit_to_clisBnbStrategy_SyncDeposit_Enabled(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 10000 wei, 1000000 ether);

        deal(address(wbnb), depositor, depositAmount);
        vm.startPrank(depositor);
        IERC20(MC.WBNB).approve(address(ynBNBx), depositAmount);
        uint256 totalAssetsBefore = ynBNBx.totalAssets();
        uint256 shares = ynBNBx.deposit(depositAmount, depositor);
        uint256 totalAssetsAfter = ynBNBx.totalAssets();
        vm.stopPrank();

        assertEq(shares, ynBNBx.balanceOf(depositor));
        assertEq(
            totalAssetsAfter,
            totalAssetsBefore + depositAmount,
            "total assets of ynBNBx should be equal to total assets of ynBNBx before plus deposit amount"
        );

        uint256 totalAssetsBeforeOfClisBnbStrategy = clisBnbStrategy.totalAssets();
        uint256 totalSupplyBeforeOfClisBnbStrategy = clisBnbStrategy.totalSupply();

        // Generate processor tx data to execute all transactions
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory data = new bytes[](2);

        // 1. Withdraw WBNB
        targets[0] = MC.WBNB;
        values[0] = 0;
        data[0] = abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)")), depositAmount);

        // 2. Mint SLISBNB
        targets[1] = MC.SLIS_BNB_STAKE_MANAGER;
        values[1] = depositAmount;
        data[1] = abi.encodeWithSelector(bytes4(keccak256("deposit()")));

        vm.startPrank(YNProcessor);
        uint256 slisBnbBalanceBefore = slisBnb.balanceOf(address(ynBNBx));
        ynBNBx.processor(targets, values, data);
        ynBNBx.processAccounting();
        vm.stopPrank();

        assertApproxEqAbs(
            ynBNBx.totalAssets(),
            totalAssetsAfter,
            1e6,
            "total assets of ynBNBx should be nearly equal to total assets of before processor"
        );
        totalAssetsAfter = ynBNBx.totalAssets();

        uint256 slisBnbReceived = slisBnb.balanceOf(address(ynBNBx)) - slisBnbBalanceBefore;

        // 3. Deposit SLISBNB to clisBnbStrategy
        targets[0] = address(slisBnb);
        values[0] = 0;
        data[0] = abi.encodeWithSelector(
            bytes4(keccak256("approve(address,uint256)")), address(clisBnbStrategy), slisBnbReceived
        );

        targets[1] = address(clisBnbStrategy);
        values[1] = 0;
        data[1] =
            abi.encodeWithSelector(bytes4(keccak256("deposit(uint256,address)")), slisBnbReceived, address(ynBNBx));

        uint256 clisBnbBalanceBefore = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);
        uint256 expectedClisBnbShare = clisBnbStrategy.previewDeposit(slisBnbReceived);
        vm.startPrank(YNProcessor);
        ynBNBx.processor(targets, values, data);
        ynBNBx.processAccounting();
        vm.stopPrank();

        assertEq(
            slisBnb.balanceOf(address(ynBNBx)),
            slisBnbBalanceBefore,
            "slisBnb balance of ynBNBx should be equal to slisBnb balance before"
        );
        assertEq(
            clisBnbStrategy.balanceOf(address(ynBNBx)),
            expectedClisBnbShare,
            "clisBnbStrategy balance of ynBNBx should be equal to expected clisBnb share"
        );
        assertApproxEqRel(
            clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET) - clisBnbBalanceBefore,
            slisBnbReceived,
            0.05e18,
            "clisBnb balance of yieldnest mpc wallet should be approximately equal to 95% of slisBnb received"
        );
        assertEq(
            clisBnbStrategy.totalAssets(),
            slisBnbReceived + totalAssetsBeforeOfClisBnbStrategy,
            "total assets of clisBnbStrategy should be equal to slisBnb received"
        );
        assertEq(
            clisBnbStrategy.totalSupply(),
            expectedClisBnbShare + totalSupplyBeforeOfClisBnbStrategy,
            "total supply of clisBnbStrategy should be equal to expected clisBnb share"
        );
        assertApproxEqAbs(
            ynBNBx.totalAssets(),
            totalAssetsAfter,
            5,
            "total assets of ynBNBx should be equal to total assets of before processor"
        );
    }

    function test_ynBNBx_deposit_to_clisBnbStrategy_SyncDeposit_Disabled(uint256 depositAmount) public {
        vm.startPrank(ADMIN);
        clisBnbStrategy.setSyncDeposit(false);
        vm.stopPrank();

        depositAmount = bound(depositAmount, 10000 wei, 1000000 ether);

        deal(address(wbnb), depositor, depositAmount);
        vm.startPrank(depositor);
        IERC20(MC.WBNB).approve(address(ynBNBx), depositAmount);
        uint256 totalAssetsBefore = ynBNBx.totalAssets();
        uint256 shares = ynBNBx.deposit(depositAmount, depositor);
        uint256 totalAssetsAfter = ynBNBx.totalAssets();
        vm.stopPrank();

        assertEq(shares, ynBNBx.balanceOf(depositor));
        assertEq(
            totalAssetsAfter,
            totalAssetsBefore + depositAmount,
            "total assets of ynBNBx should be equal to total assets of ynBNBx before plus deposit amount"
        );

        uint256 totalSupplyBeforeOfClisBnbStrategy = clisBnbStrategy.totalSupply();
        uint256 totalAssetsBeforeOfClisBnbStrategy = clisBnbStrategy.totalAssets();

        // Generate processor tx data to execute all transactions
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory data = new bytes[](2);

        // 1. Withdraw WBNB
        targets[0] = MC.WBNB;
        values[0] = 0;
        data[0] = abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)")), depositAmount);

        // 2. Mint SLISBNB
        targets[1] = MC.SLIS_BNB_STAKE_MANAGER;
        values[1] = depositAmount;
        data[1] = abi.encodeWithSelector(bytes4(keccak256("deposit()")));

        vm.startPrank(YNProcessor);
        uint256 slisBnbBalanceBefore = slisBnb.balanceOf(address(ynBNBx));
        ynBNBx.processor(targets, values, data);
        ynBNBx.processAccounting();
        vm.stopPrank();

        assertApproxEqAbs(
            ynBNBx.totalAssets(),
            totalAssetsAfter,
            1e6,
            "total assets of ynBNBx should be nearly equal to total assets of before processor"
        );
        totalAssetsAfter = ynBNBx.totalAssets();
        uint256 slisBnbReceived = slisBnb.balanceOf(address(ynBNBx)) - slisBnbBalanceBefore;

        // 3. Deposit SLISBNB to clisBnbStrategy
        targets[0] = address(slisBnb);
        values[0] = 0;
        data[0] = abi.encodeWithSelector(
            bytes4(keccak256("approve(address,uint256)")), address(clisBnbStrategy), slisBnbReceived
        );

        targets[1] = address(clisBnbStrategy);
        values[1] = 0;
        data[1] =
            abi.encodeWithSelector(bytes4(keccak256("deposit(uint256,address)")), slisBnbReceived, address(ynBNBx));

        uint256 clisBnbBalanceBefore = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);
        uint256 expectedClisBnbShare = clisBnbStrategy.previewDeposit(slisBnbReceived);
        uint256 slisBnbBalanceBeforeOfClisBnbStrategy = slisBnb.balanceOf(address(clisBnbStrategy));
        vm.startPrank(YNProcessor);
        ynBNBx.processor(targets, values, data);
        ynBNBx.processAccounting();
        vm.stopPrank();

        assertEq(
            slisBnb.balanceOf(address(ynBNBx)),
            slisBnbBalanceBefore,
            "slisBnb balance of ynBNBx should be equal to slisBnb balance before"
        );
        assertEq(
            clisBnbStrategy.balanceOf(address(ynBNBx)),
            expectedClisBnbShare,
            "clisBnbStrategy balance of ynBNBx should be equal to expected clisBnb share"
        );
        assertEq(
            slisBnb.balanceOf(address(clisBnbStrategy)),
            slisBnbBalanceBeforeOfClisBnbStrategy + slisBnbReceived,
            "clisBnb balance of slisBnb should be equal to slisBnb balance before plus slisBnb received"
        );
        assertEq(
            clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET),
            clisBnbBalanceBefore,
            "clisBnb balance of yieldnest mpc wallet should be equal to clisBnb balance before"
        );
        assertEq(
            clisBnbStrategy.totalAssets(),
            slisBnbReceived + totalAssetsBeforeOfClisBnbStrategy,
            "total assets of clisBnbStrategy should be equal to slisBnb received"
        );
        assertEq(
            clisBnbStrategy.totalSupply(),
            expectedClisBnbShare + totalSupplyBeforeOfClisBnbStrategy,
            "total supply of clisBnbStrategy should be equal to expected clisBnb share"
        );
        assertApproxEqAbs(
            ynBNBx.totalAssets(),
            totalAssetsAfter,
            5,
            "total assets of ynBNBx should be equal to total assets of before processor"
        );
    }

    function test_ynBNBx_due_to_update_YieldNestMpcWallet(uint256 depositAmount) public {
        uint256 clisBnbBalanceOfOldYieldNestMpcWalletBefore = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);
        depositAmount = bound(depositAmount, 10000 wei, 1000000 ether);

        test_ynBNBx_deposit_to_clisBnbStrategy_SyncDeposit_Enabled(depositAmount);

        uint256 clisBnbStrategyBalanceOfYnBNBxBefore = clisBnbStrategy.balanceOf(address(ynBNBx));
        uint256 clisBnbBalanceOfOldYieldNestMpcWalletAfterDeposit = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);
        uint256 totalAssetsBeforeOfYnBNBx = ynBNBx.totalAssets();
        uint256 totalAssetsBeforeOfClisBnbStrategy = clisBnbStrategy.totalAssets();
        uint256 totalSupplyBeforeOfYnBNBx = ynBNBx.totalSupply();
        uint256 totalSupplyBeforeOfClisBnbStrategy = clisBnbStrategy.totalSupply();

        vm.startPrank(LISTA_DEPENDENCY_MANAGER);
        address newYieldNestMpcWallet = makeAddr("newYieldNestMpcWallet");
        clisBnbStrategy.setYieldNestMpcWallet(newYieldNestMpcWallet);
        vm.stopPrank();
        {
            address[] memory targets = new address[](1);
            uint256[] memory values = new uint256[](1);
            bytes[] memory data = new bytes[](1);

            targets[0] = address(clisBnbStrategy);
            values[0] = 0;
            data[0] = abi.encodeWithSelector(
                bytes4(keccak256("redeem(uint256,address,address)")),
                clisBnbStrategyBalanceOfYnBNBxBefore,
                address(ynBNBx),
                address(ynBNBx)
            );

            vm.startPrank(YNProcessor);
            ynBNBx.processor(targets, values, data);
            ynBNBx.processAccounting();
            vm.stopPrank();

            assertEq(clisBnbStrategy.balanceOf(address(ynBNBx)), 0, "clisBnbStrategy balance of ynBNBx should be 0");
            assertEq(
                clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET),
                clisBnbBalanceOfOldYieldNestMpcWalletBefore,
                "clisBnb balance of old yieldnest mpc wallet should be equal to clisBnb balance of old yieldnest mpc wallet before"
            );

            targets = new address[](2);
            values = new uint256[](2);
            data = new bytes[](2);

            targets[0] = address(slisBnb);
            values[0] = 0;
            data[0] = abi.encodeWithSelector(
                bytes4(keccak256("approve(address,uint256)")),
                address(clisBnbStrategy),
                slisBnb.balanceOf(address(ynBNBx))
            );

            targets[1] = address(clisBnbStrategy);
            values[1] = 0;
            data[1] = abi.encodeWithSelector(
                bytes4(keccak256("deposit(uint256,address)")), slisBnb.balanceOf(address(ynBNBx)), address(ynBNBx)
            );

            vm.startPrank(YNProcessor);
            ynBNBx.processor(targets, values, data);
            ynBNBx.processAccounting();
            vm.stopPrank();
        }

        assertApproxEqAbs(
            clisBnb.balanceOf(newYieldNestMpcWallet),
            clisBnbBalanceOfOldYieldNestMpcWalletAfterDeposit - clisBnbBalanceOfOldYieldNestMpcWalletBefore,
            100,
            "clisBnb balance of new yieldnest mpc wallet should be equal to clisBnb balance of old yieldnest mpc wallet received deposit"
        );
        assertApproxEqAbs(
            clisBnbStrategy.balanceOf(address(ynBNBx)),
            clisBnbStrategyBalanceOfYnBNBxBefore,
            5,
            "clisBnbStrategy balance of ynBNBx should be equal to clisBnbStrategy balance of ynBNBx before"
        );
        assertApproxEqAbs(
            ynBNBx.totalAssets(),
            totalAssetsBeforeOfYnBNBx,
            5,
            "total assets of ynBNBx should be equal to total assets of before"
        );
        assertApproxEqAbs(
            clisBnbStrategy.totalAssets(),
            totalAssetsBeforeOfClisBnbStrategy,
            5,
            "total assets of clisBnbStrategy should be equal to total assets of before"
        );
        assertApproxEqAbs(
            ynBNBx.totalSupply(),
            totalSupplyBeforeOfYnBNBx,
            5,
            "total supply of ynBNBx should be equal to total supply of before"
        );
        assertApproxEqAbs(
            clisBnbStrategy.totalSupply(),
            totalSupplyBeforeOfClisBnbStrategy,
            5,
            "total supply of clisBnbStrategy should be equal to total supply of before"
        );
    }

    function test_ynBNBx_withdraw_from_clisBnbStrategy(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 10000 wei, 1000000 ether);

        test_ynBNBx_deposit_to_clisBnbStrategy_SyncDeposit_Enabled(depositAmount);

        uint256 withdrawAmount = _getStakedSlisBnbBalanceByVault(address(slisBnb), address(clisBnbStrategy));
        withdrawAmount = bound(withdrawAmount, 1 wei, withdrawAmount);
        uint256 clisBnbBalanceBefore = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);
        uint256 slisBnbBalanceBeforeOfYnBNBx = slisBnb.balanceOf(address(ynBNBx));
        uint256 expectedClisBnbShare = clisBnbStrategy.previewWithdraw(withdrawAmount);
        uint256 clisBnbStrategyBalanceBeforeOfYnBNBx = clisBnbStrategy.balanceOf(address(ynBNBx));
        uint256 totalAssetsBeforeOfYnBNBx = ynBNBx.totalAssets();
        uint256 totalAssetsBeforeOfClisBnbStrategy = clisBnbStrategy.totalAssets();
        uint256 totalSupplyBeforeOfYnBNBx = ynBNBx.totalSupply();
        uint256 totalSupplyBeforeOfClisBnbStrategy = clisBnbStrategy.totalSupply();

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory data = new bytes[](1);

        targets[0] = address(clisBnbStrategy);
        values[0] = 0;
        data[0] = abi.encodeWithSelector(
            bytes4(keccak256("withdraw(uint256,address,address)")), withdrawAmount, address(ynBNBx), address(ynBNBx)
        );

        vm.startPrank(YNProcessor);
        ynBNBx.processor(targets, values, data);
        ynBNBx.processAccounting();
        vm.stopPrank();

        assertEq(
            slisBnb.balanceOf(address(ynBNBx)),
            slisBnbBalanceBeforeOfYnBNBx + withdrawAmount,
            "slisBnb balance of ynBNBx should be equal to slisBnb balance before plus withdraw amount"
        );
        assertLe(
            clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET),
            clisBnbBalanceBefore,
            "clisBnb balance of yieldnest mpc wallet should be less than or equal to clisBnb balance before"
        );
        assertEq(
            clisBnbStrategy.balanceOf(address(ynBNBx)) + expectedClisBnbShare,
            clisBnbStrategyBalanceBeforeOfYnBNBx,
            "clisBnbStrategy balance of ynBNBx should be equal to total supply before of ynBNBx minus expected clisBnb share"
        );
        assertEq(
            slisBnb.balanceOf(address(ynBNBx)),
            slisBnbBalanceBeforeOfYnBNBx + withdrawAmount,
            "slisBnb balance of ynBNBx should be equal to slisBnb balance before plus withdraw amount"
        );
        assertEq(
            clisBnbStrategy.totalAssets(),
            totalAssetsBeforeOfClisBnbStrategy - withdrawAmount,
            "total assets of clisBnbStrategy should be equal to total assets of before minus withdraw amount"
        );
        assertEq(
            ynBNBx.totalAssets(),
            totalAssetsBeforeOfYnBNBx,
            "total assets of ynBNBx should be equal to total assets of before"
        );
        assertEq(
            ynBNBx.totalSupply(),
            totalSupplyBeforeOfYnBNBx,
            "total supply of ynBNBx should be equal to total supply of before"
        );
        assertEq(
            clisBnbStrategy.totalSupply(),
            totalSupplyBeforeOfClisBnbStrategy - expectedClisBnbShare,
            "total supply of clisBnbStrategy should be equal to total supply of before minus expected clisBnb share"
        );
    }

    function test_reward_stream_to_clisBnbStrategy(uint256 depositAmount, uint256 rewardAmount) public {
        test_ynBNBx_deposit_to_clisBnbStrategy_SyncDeposit_Enabled(depositAmount);
        rewardAmount = bound(rewardAmount, 0.1 ether, 1000000 ether);

        deal(address(slisBnb), DEPOSIT_MANAGER, rewardAmount);

        uint256 clisBnbStrategyRateBefore = clisBnbStrategy.previewRedeem(1 ether);
        uint256 totalAssetsBeforeOfClisBnbStrategy = clisBnbStrategy.totalAssets();
        uint256 totalSupplyBeforeOfClisBnbStrategy = clisBnbStrategy.totalSupply();
        uint256 slisBnbLockedInClisBnbStrategyVaultBefore =
            _getStakedSlisBnbBalanceByVault(address(slisBnb), address(clisBnbStrategy));
        uint256 clisBnbBalanceOfYieldnestMpcWalletBefore = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);
        uint256 ynBNBxRateBefore = ynBNBx.previewRedeem(1 ether);
        uint256 totalAssetsBeforeOfYnBNBx = ynBNBx.totalAssets();
        uint256 totalSupplyBeforeOfYnBNBx = ynBNBx.totalSupply();

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
            totalAssetsAfter,
            totalAssetsBeforeOfClisBnbStrategy + rewardAmount,
            "Total assets of vault should increase by reward amount"
        );
        assertEq(totalSupplyAfter, totalSupplyBeforeOfClisBnbStrategy, "Total supply of vault should not change");
        assertEq(
            slisBnbLockedInVaultAfter,
            slisBnbLockedInClisBnbStrategyVaultBefore,
            "SlisBnb locked in vault should not change"
        );
        assertEq(
            clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET),
            clisBnbBalanceOfYieldnestMpcWalletBefore,
            "ClisBnb balance of YieldnestMpcWallet should not change"
        );
        assertGt(
            ynBNBx.totalAssets(),
            totalAssetsBeforeOfYnBNBx,
            "total assets of ynBNBx should be greater than total assets of before"
        );
        assertEq(
            ynBNBx.totalSupply(),
            totalSupplyBeforeOfYnBNBx,
            "total supply of ynBNBx should be equal to total supply of before"
        );
        assertGt(
            ynBNBx.previewRedeem(1 ether), ynBNBxRateBefore, "ynBNBx rate should be greater than ynBNBx rate before"
        );
    }

    function test_reward_stream_allocation_to_clisBnbStrategy(uint256 depositAmount, uint256 rewardAmount) public {
        rewardAmount = bound(rewardAmount, 0.1 ether, 1000000 ether);

        test_reward_stream_to_clisBnbStrategy(depositAmount, rewardAmount);

        uint256 clisBnbStrategyRateBefore = clisBnbStrategy.previewRedeem(1 ether);
        uint256 totalAssetsBeforeOfClisBnbStrategy = clisBnbStrategy.totalAssets();
        uint256 totalSupplyBeforeOfClisBnbStrategy = clisBnbStrategy.totalSupply();
        uint256 slisBnbLockedInClisBnbStrategyVaultBefore =
            _getStakedSlisBnbBalanceByVault(address(slisBnb), address(clisBnbStrategy));
        uint256 clisBnbBalanceOfYieldnestMpcWalletBefore = clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET);
        uint256 ynBNBxRateBefore = ynBNBx.previewRedeem(1 ether);
        uint256 totalAssetsBeforeOfYnBNBx = ynBNBx.totalAssets();
        uint256 totalSupplyBeforeOfYnBNBx = ynBNBx.totalSupply();

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
        uint256 totalAssetsAfterOfClisBnbStrategy = clisBnbStrategy.totalAssets();
        uint256 totalSupplyAfterOfClisBnbStrategy = clisBnbStrategy.totalSupply();
        uint256 slisBnbLockedInVaultAfter =
            _getStakedSlisBnbBalanceByVault(address(baseAsset), address(clisBnbStrategy));
        assertEq(clisBnbStrategyRateAfter, clisBnbStrategyRateBefore, "ClisBnb strategy rate should not change");
        assertEq(
            totalAssetsAfterOfClisBnbStrategy,
            totalAssetsBeforeOfClisBnbStrategy,
            "Total assets of vault should not change"
        );
        assertEq(
            totalSupplyAfterOfClisBnbStrategy,
            totalSupplyBeforeOfClisBnbStrategy,
            "Total supply of vault should not change"
        );
        assertEq(
            slisBnbLockedInVaultAfter,
            slisBnbLockedInClisBnbStrategyVaultBefore + rewardAmount,
            "SlisBnb locked in vault should increase by reward amount"
        );
        assertGt(
            clisBnb.balanceOf(MC.YIELDNEST_MPC_WALLET),
            clisBnbBalanceOfYieldnestMpcWalletBefore,
            "ClisBnb balance of YieldnestMpcWallet should increase due to reward stream allocation"
        );
        assertEq(
            ynBNBx.totalAssets(),
            totalAssetsBeforeOfYnBNBx,
            "total assets of ynBNBx should be greater than total assets of before"
        );
        assertEq(
            ynBNBx.totalSupply(),
            totalSupplyBeforeOfYnBNBx,
            "total supply of ynBNBx should be equal to total supply of before"
        );
        assertEq(
            ynBNBx.previewRedeem(1 ether), ynBNBxRateBefore, "ynBNBx rate should be greater than ynBNBx rate before"
        );
    }

    function test_ynBNBx_withdraw_from_ynasBNBK() public {
        address[] memory target = new address[](1);
        target[0] = address(ynasBNBK);

        uint256[] memory amount = new uint256[](1);
        amount[0] = 0;

        uint256 shares = IERC20(address(ynasBNBK)).balanceOf(address(ynBNBx));
        uint256 withdrawableWbnb = ynasBNBK.previewRedeem(shares);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(
            BaseStrategy.redeemAsset.selector, MC.ASBNB, shares, address(ynBNBx), address(ynBNBx)
        );

        {
            IVault.FunctionRule memory rule = IVault.FunctionRule({
                isActive: true,
                paramRules: new IVault.ParamRule[](0),
                validator: IValidator(address(0))
            });

            // add rule for processor
            vm.startPrank(PROCESSOR_MANAGER);
            ynBNBx.setProcessorRule(address(ynasBNBK), BaseStrategy.redeemAsset.selector, rule);
            vm.stopPrank();
        }

        uint256 asBNBBalanceOfynBNBxBefore = IERC20(MC.ASBNB).balanceOf(address(ynBNBx));
        uint256 totalSupplyOfynBNBxBefore = ynBNBx.totalSupply();
        uint256 totalSupplyOfasBNBkBefore = ynasBNBK.totalSupply();
        uint256 totalAssetsOfynBNBxBefore = ynBNBx.totalAssets();
        uint256 ynBNBxRateBefore = ynBNBx.previewRedeem(1e18);

        vm.startPrank(YNProcessor);
        ynBNBx.processor(target, amount, data);
        ynBNBx.processAccounting();
        vm.stopPrank();

        {
            uint256 asBNBBalanceReceived = IERC20(MC.ASBNB).balanceOf(address(ynBNBx)) - asBNBBalanceOfynBNBxBefore;
            uint256 wbnbBalanceReceived = ynBNBxProvider.getRate(MC.ASBNB) * asBNBBalanceReceived / 1e18;
            assertApproxEqAbs(
                wbnbBalanceReceived,
                withdrawableWbnb,
                2,
                "wbnb balance received should be equal to withdrawable wbnb after full redemption"
            );

            uint256 totalSupplyOfasBNBkAfter = ynasBNBK.totalSupply();
            uint256 totalSupplyOfynBNBxAfter = ynBNBx.totalSupply();
            assertApproxEqAbs(
                totalSupplyOfasBNBkAfter,
                totalSupplyOfasBNBkBefore - shares,
                2,
                "total supply of asBNBk should be equal to total supply of asBNBk before minus shares"
            );

            uint256 totalAssetsOfasBNBkAfter = ynasBNBK.totalAssets();
            uint256 totalAssetsOfynBNBxAfter = ynBNBx.totalAssets();
            uint256 ynBNBxRateAfter = ynBNBx.previewRedeem(1e18);
            assertApproxEqAbs(
                totalAssetsOfasBNBkAfter, 0, 5, "asBNBk should have nearly 0 total assets after full redemption"
            );
            assertApproxEqAbs(
                totalAssetsOfynBNBxAfter,
                totalAssetsOfynBNBxBefore,
                1e6,
                "total assets of ynBNBx should be equal to total assets of ynBNBx before plus after redemption"
            );
            assertEq(
                totalSupplyOfynBNBxAfter,
                totalSupplyOfynBNBxBefore,
                "total supply of ynBNBx should be equal to total supply of ynBNBx before"
            );
            assertApproxEqAbs(ynBNBxRateAfter, ynBNBxRateBefore, 5, "ynBNBx rate should be equal to ynBNBx rate before");
        }
    }
}
