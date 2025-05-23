/* solhint-disable one-contract-per-file */
// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {IActors as IYnBNBxActors} from "lib/yieldnest-vault/script/Actors.sol";
import {TestnetActors as TestnetYnBNBxActors} from "lib/yieldnest-vault/script/Actors.sol";
import {MainnetActors as MainnetYnBNBxActors} from "lib/yieldnest-vault/script/Actors.sol";

interface IClisBnbActors is IYnBNBxActors {
    function LISTA_DEPENDENCY_MANAGER() external view returns (address);
    function DEPOSIT_MANAGER() external view returns (address);
    function YNBNBX() external view returns (address);
}

contract MainnetActors is MainnetYnBNBxActors, IClisBnbActors {
    address public constant LISTA_DEPENDENCY_MANAGER = YnSecurityCouncil;
    address public constant DEPOSIT_MANAGER = YnSecurityCouncil;
    address public constant YNBNBX = 0x32C830f5c34122C6afB8aE87ABA541B7900a2C5F;

    address public constant TIMELOCK = 0xd7C83Dc5b7accc62dcc958bD1919a13DdB7eD06c;
}

contract TestnetActors is TestnetYnBNBxActors, IClisBnbActors {
    address public constant YnProcessor = YnSecurityCouncil;
    address public constant LISTA_DEPENDENCY_MANAGER = YnSecurityCouncil;
    address public constant DEPOSIT_MANAGER = YnSecurityCouncil;
    address public constant YNBNBX = 0x19c3C015Fc0A85E1eAB197d3163Eb726861A1D93;
    address public constant YnBootstrapper = YnSecurityCouncil;
}
