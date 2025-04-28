// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

interface Interaction {
    function locked(address token, address usr) external view returns (uint256);
}