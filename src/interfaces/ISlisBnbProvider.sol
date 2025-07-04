// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

interface ISlisBnbProvider {
    function provide(uint256 amount, address delegatee) external;
    function release(address recipient, uint256 amount) external;
    function convertSnBnbToBnb(uint256 amount) external view returns (uint256);
    function exchangeRate() external view returns (uint256);
    function RATE_DENOMINATOR() external view returns (uint256);
    function userLpRate() external view returns (uint256);
}
