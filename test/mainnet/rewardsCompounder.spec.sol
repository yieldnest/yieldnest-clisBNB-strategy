// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployRewardsCompounder} from "script/DeployRewardsCompounder.s.sol";
import {MainnetActors} from "script/Actors.sol";
import {RewardsCompounder} from "src/RewardsCompounder.sol";
import {MainnetContracts as MC} from "script/Contracts.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ClisBnbStrategy} from "src/ClisBnbStrategy.sol";
import {Interaction} from "src/interfaces/Interaction.sol";

contract RewardsCompounderTest is Test, MainnetActors {
    DeployRewardsCompounder public deployRewardsCompounder;
    RewardsCompounder public rewardsCompounder;
    address public owner = PROCESSOR;
    uint256 public minRewardsToCompound = 5 ether;
    IERC20 public slisBnb = IERC20(MC.SLIS_BNB);
    IERC20 public clisBnb = IERC20(MC.CLIS_BNB);
    ClisBnbStrategy public clisBnbStrategy = ClisBnbStrategy(payable(0x1cBfbC3CB909Fb0BF0E511AFAe6cDBa6ba5e2252));
    Interaction public interaction = Interaction(MC.INTERACTION);

    function setUp() public {
        deployRewardsCompounder = new DeployRewardsCompounder();
        deployRewardsCompounder.setEnv(DeployRewardsCompounder.Env.TEST);
        deployRewardsCompounder.setMinRewardsToCompound(minRewardsToCompound);
        deployRewardsCompounder.setOwner(owner);

        deployRewardsCompounder.run();

        rewardsCompounder = RewardsCompounder(deployRewardsCompounder.rewardsCompounder());

        vm.startPrank(ADMIN);
        deployRewardsCompounder.clisBnbStrategy().grantRole(
            clisBnbStrategy.PROCESSOR_ROLE(), address(rewardsCompounder)
        );
        vm.stopPrank();
    }

    function test_deploy_success() public view {
        assertNotEq(address(rewardsCompounder), address(0), "rewardsCompounder should be deployed");
        assertEq(address(rewardsCompounder.strategy()), address(deployRewardsCompounder.clisBnbStrategy()));
        assertEq(address(rewardsCompounder.slisBnb()), MC.SLIS_BNB);
        assertEq(rewardsCompounder.minRewardsToCompound(), minRewardsToCompound);
        assertEq(rewardsCompounder.owner(), owner);
    }

    function test_compoundRewards_success() public {
        vm.startPrank(PROCESSOR);
        deal(
            address(slisBnb),
            address(clisBnbStrategy),
            rewardsCompounder.minRewardsToCompound() + slisBnb.balanceOf(address(clisBnbStrategy))
        );
        uint256 initialSlisBnbBalanceOfClisBnbStrategy = slisBnb.balanceOf(address(clisBnbStrategy));
        uint256 initialLockedSlisBnbOfClisBnbStrategy = interaction.locked(address(slisBnb), address(clisBnbStrategy));
        uint256 initialSlisBnbBalanceOfRewardsCompounder = slisBnb.balanceOf(address(rewardsCompounder));
        uint256 initialClisBNBBalanceOfMpcWallet = clisBnb.balanceOf(clisBnbStrategy.yieldNestMpcWallet());
        uint256 initialTotalAssetsOfStrategy = clisBnbStrategy.totalAssets();
        uint256 initialTotalSupplyOfClisBnb = clisBnbStrategy.totalSupply();

        assertTrue(
            rewardsCompounder.shouldCompoundRewards(),
            "shouldCompoundRewards should return true due to enough slisBnb balance"
        );
        rewardsCompounder.compoundRewards();

        assertEq(
            slisBnb.balanceOf(address(clisBnbStrategy)),
            0,
            "slisBnb balance of clisBnbStrategy should be 0 after compoundRewards"
        );
        assertEq(
            slisBnb.balanceOf(address(rewardsCompounder)),
            initialSlisBnbBalanceOfRewardsCompounder,
            "slisBnb balance of rewardsCompounder should be the same"
        );
        assertGt(
            clisBnb.balanceOf(clisBnbStrategy.yieldNestMpcWallet()),
            initialClisBNBBalanceOfMpcWallet,
            "clisBnb balance of mpcWallet should be greater than initialClisBNBBalanceOfMpcWallet"
        );
        assertEq(
            clisBnbStrategy.totalAssets(),
            initialTotalAssetsOfStrategy,
            "totalAssets of strategy should be equal to initialTotalAssetsOfStrategy"
        );
        assertEq(
            clisBnbStrategy.totalSupply(),
            initialTotalSupplyOfClisBnb,
            "totalSupply of clisBnb should be equal to initialTotalSupplyOfClisBnb"
        );
        assertEq(
            interaction.locked(address(slisBnb), address(clisBnbStrategy)),
            initialLockedSlisBnbOfClisBnbStrategy + initialSlisBnbBalanceOfClisBnbStrategy,
            "locked slisBnb should be equal to initialLockedSlisBnbOfClisBnbStrategy + initialSlisBnbBalanceOfClisBnbStrategy due to compoundRewards"
        );
        vm.stopPrank();
    }

    function test_compoundRewards_notEnoughSlisBnbBalance() public {
        vm.startPrank(PROCESSOR);
        deal(address(slisBnb), address(clisBnbStrategy), rewardsCompounder.minRewardsToCompound() - 1);
        assertFalse(
            rewardsCompounder.shouldCompoundRewards(),
            "shouldCompoundRewards should return false due to not enough slisBnb balance"
        );

        vm.expectRevert(abi.encodeWithSelector(RewardsCompounder.NotEnoughRewardsToCompound.selector));
        rewardsCompounder.compoundRewards();
        vm.stopPrank();
    }

    function test_shouldCompoundRewards_notEnoughSlisBnbBalance() public {
        test_compoundRewards_success();

        assertFalse(
            rewardsCompounder.shouldCompoundRewards(),
            "shouldCompoundRewards should return false due to already compounded rewards"
        );
        vm.expectRevert(abi.encodeWithSelector(RewardsCompounder.NotEnoughRewardsToCompound.selector));
        rewardsCompounder.compoundRewards();
    }
}
