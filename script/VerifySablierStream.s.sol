// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MainnetActors} from "script/Actors.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {MainnetContracts} from "script/Contracts.sol";

interface ISablierFlowBase {
    function ownerOf(uint256 streamId) external view returns (address owner);
    function getBalance(uint256 streamId) external view returns (uint128 balance);
    function getRatePerSecond(uint256 streamId) external view returns (uint128 ratePerSecond);
    function getRecipient(uint256 streamId) external view returns (address recipient);
    function getSender(uint256 streamId) external view returns (address sender);
    function getToken(uint256 streamId) external view returns (IERC20 token);
    function getTokenDecimals(uint256 streamId) external view returns (uint8 tokenDecimals);
    function isPaused(uint256 streamId) external view returns (bool result);
    function isStream(uint256 streamId) external view returns (bool result);
    function isTransferable(uint256 streamId) external view returns (bool result);
    function isVoided(uint256 streamId) external view returns (bool result);
    function withdrawableAmountOf(uint256 streamId) external view returns (uint256 withdrawableAmount);
}

contract VerifySablierStream is Script, MainnetActors, Test {
    ISablierFlowBase sablierFlow = ISablierFlowBase(0x4C4610aF3f3861EC99b6F6F8066C03E4C3a0E023);

    function run() public {
        console.log("Verifying Sablier Stream");

        uint256 streamId = 4;

        bool isStream = sablierFlow.isStream(streamId);
        assertEq(isStream, true, "stream with id 4 should exist");

        bool isTransferable = sablierFlow.isTransferable(streamId);
        assertEq(isTransferable, true, "stream with id 4 should be transferable");

        bool isPaused = sablierFlow.isPaused(streamId);
        assertEq(isPaused, false, "stream with id 4 should not be paused");

        bool isVoided = sablierFlow.isVoided(streamId);
        assertEq(isVoided, false, "stream with id 4 should not be voided");

        address owner = sablierFlow.ownerOf(streamId);
        assertEq(owner, PROCESSOR, "owner of stream with id 4 should be YnProcessor");

        IERC20 token = IERC20(sablierFlow.getToken(streamId));
        assertEq(address(token), MainnetContracts.SLIS_BNB, "token of stream with id 4 should be SLIS_BNB");

        uint256 balance = sablierFlow.getBalance(streamId);
        console.log("Balance of stream with id 4 is", balance);

        uint128 ratePerSecond = sablierFlow.getRatePerSecond(streamId);
        console.log("Rate per second of stream with id 4 is", ratePerSecond);

        vm.warp(block.timestamp + 14 days);

        uint256 withdrawableAmount = sablierFlow.withdrawableAmountOf(streamId);
        console.log("Withdrawable amount of stream with id 4 is", withdrawableAmount);

        // withdrawable amount should be 11292338843615689703 i.e. (11.292338843615689703) slisBNB
        assertEq(
            withdrawableAmount,
            11292338843615689703,
            "withdrawable amount of stream with id 4 should be 11292338843615689703"
        );
        assertEq(withdrawableAmount, balance, "withdrawable amount of stream with id 4 should be equal to balance");
    }
}
