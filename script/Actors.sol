/* solhint-disable one-contract-per-file */
// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

interface IActors {
    function YnSecurityCouncil() external view returns (address);
    function PROCESSOR_MANAGER() external view returns (address);
    function ASSET_MANAGER() external view returns (address);
    function LISTA_DEPENDENCY_MANAGER() external view returns (address);
    function ADMIN() external view returns (address);
    function DEPOSIT_MANAGER() external view returns (address);
    function KEEPER() external view returns (address);
    function PROCESSOR() external view returns (address);
    function PROVIDER_MANAGER() external view returns (address);
    function BUFFER_MANAGER() external view returns (address);
    function PAUSER() external view returns (address);
    function UNPAUSER() external view returns (address);
    function FEE_MANAGER() external view returns (address);
    function ALLOCATOR_MANAGER() external view returns (address);
    function PROPOSER_1() external view returns (address);
    function EXECUTOR_1() external view returns (address);
    function YNBNBX() external view returns (address);
}

contract MainnetActors is IActors {
    address public constant YnSecurityCouncil = 0x721688652DEa9Cabec70BD99411EAEAB9485d436;
    address public constant YnProcessor = 0x258d7614d9c608D191A8a103f95B7Df066a19bbF;
    address public constant PROCESSOR_MANAGER = YnSecurityCouncil;
    address public constant ASSET_MANAGER = YnSecurityCouncil;
    address public constant LISTA_DEPENDENCY_MANAGER = YnSecurityCouncil;
    address public constant ADMIN = YnSecurityCouncil;
    address public constant DEPOSIT_MANAGER = YnSecurityCouncil;
    address public constant KEEPER = address(0xdeadb11e);
    address public constant PROCESSOR = YnProcessor;
    address public constant PROVIDER_MANAGER = YnSecurityCouncil;
    address public constant BUFFER_MANAGER = YnSecurityCouncil;
    address public constant PAUSER = YnSecurityCouncil;
    address public constant UNPAUSER = YnSecurityCouncil;
    address public constant FEE_MANAGER = YnSecurityCouncil;
    address public constant ALLOCATOR_MANAGER = YnSecurityCouncil;
    address public constant PROPOSER_1 = YnSecurityCouncil;
    address public constant EXECUTOR_1 = YnSecurityCouncil;
    address public constant YNBNBX = 0x32C830f5c34122C6afB8aE87ABA541B7900a2C5F;
}

contract TestnetActors is IActors {
    address public constant YnSecurityCouncil = 0x72fdBD51085bDa5eEEd3b55D1a46E2e92f0837a5;

    address public constant YnProcessor = YnSecurityCouncil;
    address public constant PROCESSOR_MANAGER = YnSecurityCouncil;
    address public constant ASSET_MANAGER = YnSecurityCouncil;
    address public constant LISTA_DEPENDENCY_MANAGER = YnSecurityCouncil;
    address public constant ADMIN = YnSecurityCouncil;
    address public constant DEPOSIT_MANAGER = YnSecurityCouncil;
    address public constant KEEPER = address(0xdeadb11e);
    address public constant PROCESSOR = YnProcessor;
    address public constant PROVIDER_MANAGER = YnSecurityCouncil;
    address public constant BUFFER_MANAGER = YnSecurityCouncil;
    address public constant PAUSER = YnSecurityCouncil;
    address public constant UNPAUSER = YnSecurityCouncil;
    address public constant FEE_MANAGER = YnSecurityCouncil;
    address public constant ALLOCATOR_MANAGER = YnSecurityCouncil;
    address public constant PROPOSER_1 = YnSecurityCouncil;
    address public constant EXECUTOR_1 = YnSecurityCouncil;
    address public constant YNBNBX = 0x0000000000000000000000000000000000000000;
}
