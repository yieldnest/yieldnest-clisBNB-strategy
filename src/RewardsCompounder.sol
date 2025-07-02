// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {ClisBnbStrategy} from "src/ClisBnbStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISlisBnbProvider} from "src/interfaces/ISlisBnbProvider.sol";

/**
 * @title RewardsCompounder for ClisBnbStrategy
 * @notice This contract is used to compound rewards sent to the strategy.
 */
contract RewardsCompounder is Ownable {
    // @notice The strategy contract.
    ClisBnbStrategy public strategy;

    // @notice The slisBnb token.
    IERC20 public slisBnb;

    // @notice The minimum amount of rewards to compound.
    uint256 public minRewardsToCompound;

    error NotEnoughRewardsToCompound();

    /**
     * @notice The constructor.
     * @param _strategy The strategy contract.
     * @param _minRewardsToCompound The minimum amount of rewards to compound.
     * @param _owner The owner of the contract.
     */
    constructor(address payable _strategy, uint256 _minRewardsToCompound, address _owner) Ownable(_owner) {
        strategy = ClisBnbStrategy(_strategy);
        slisBnb = strategy.slisBnb();
        minRewardsToCompound = _minRewardsToCompound;
    }

    /**
     * @notice The function to compound rewards.
     * @dev This function will be called by keeper and it will compound rewards if there are enough rewards.
     */
    function compoundRewards() external {
        if (!shouldCompoundRewards()) {
            revert NotEnoughRewardsToCompound();
        }

        uint256 amountToCompound = slisBnb.balanceOf(address(strategy));

        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory data = new bytes[](2);

        targets[0] = address(slisBnb);
        values[0] = 0;
        data[0] = abi.encodeWithSelector(IERC20.approve.selector, address(strategy.slisBnbProvider()), amountToCompound);

        targets[1] = address(strategy.slisBnbProvider());
        values[1] = 0;
        data[1] =
            abi.encodeWithSelector(ISlisBnbProvider.provide.selector, amountToCompound, strategy.yieldNestMpcWallet());

        strategy.processor(targets, values, data);
    }

    /**
     * @notice The function to check if there are enough rewards to compound.
     * @return bool True if there are enough rewards to compound, false otherwise.
     */
    function shouldCompoundRewards() public view returns (bool) {
        return slisBnb.balanceOf(address(strategy)) >= minRewardsToCompound;
    }

    /**
     * @notice The function to set the minimum amount of rewards to compound.
     * @param _minRewardsToCompound The minimum amount of rewards to compound.
     */
    function setMinRewardsToCompound(uint256 _minRewardsToCompound) external onlyOwner {
        minRewardsToCompound = _minRewardsToCompound;
    }
}
