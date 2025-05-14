// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {BaseVault} from "lib/yieldnest-vault/src/BaseVault.sol";
import {ClisBnbStrategy} from "src/ClisBnbStrategy.sol";
import {IClisBnbActors} from "script/Actors.sol";
import {console} from "lib/forge-std/src/console.sol";
import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ProxyUtils} from "lib/yieldnest-vault/script/ProxyUtils.sol";
import {TimelockController} from "lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";

library RolesVerification {
    function verifyRole(IAccessControl control, address account, bytes32 role, bool expected, string memory message)
        internal
        view
    {
        Vm vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

        bool hasRole = control.hasRole(role, account);
        console.log(hasRole == expected ? "\u2705" : "\u274C", message, account);
        vm.assertEq(hasRole, expected, message);
    }

    function verifyDefaultRoles(ClisBnbStrategy strategy, TimelockController timelock, IClisBnbActors actors)
        internal
        view
    {
        verifyRole(strategy, actors.ADMIN(), strategy.DEFAULT_ADMIN_ROLE(), true, "Admin has DEFAULT_ADMIN_ROLE");
        verifyRole(strategy, actors.PROCESSOR(), strategy.PROCESSOR_ROLE(), true, "Processor has PROCESSOR_ROLE");
        verifyRole(strategy, actors.PAUSER(), strategy.PAUSER_ROLE(), true, "Pauser has PAUSER_ROLE");
        verifyRole(strategy, actors.UNPAUSER(), strategy.UNPAUSER_ROLE(), true, "Unpauser has UNPAUSER_ROLE");
        verifyRole(
            strategy,
            actors.DEPOSIT_MANAGER(),
            strategy.DEPOSIT_MANAGER_ROLE(),
            true,
            "Deposit manager has DEPOSIT_MANAGER_ROLE"
        );
        verifyRole(
            strategy,
            actors.LISTA_DEPENDENCY_MANAGER(),
            strategy.LISTA_DEPENDENCY_MANAGER_ROLE(),
            true,
            "Lista dependency manager has LISTA_DEPENDENCY_MANAGER_ROLE"
        );

        verifyRole(
            strategy, address(timelock), strategy.PROVIDER_MANAGER_ROLE(), true, "Timelock has PROVIDER_MANAGER_ROLE"
        );
        verifyRole(strategy, address(timelock), strategy.ASSET_MANAGER_ROLE(), true, "Timelock has ASSET_MANAGER_ROLE");
        verifyRole(
            strategy, address(timelock), strategy.BUFFER_MANAGER_ROLE(), true, "Timelock has BUFFER_MANAGER_ROLE"
        );
        verifyRole(
            strategy, address(timelock), strategy.PROCESSOR_MANAGER_ROLE(), true, "Timelock has PROCESSOR_MANAGER_ROLE"
        );
        verifyRole(
            strategy, address(timelock), strategy.ALLOCATOR_MANAGER_ROLE(), true, "Timelock has ALLOCATOR_MANAGER_ROLE"
        );

        verifyRole(strategy, actors.YNBNBX(), strategy.ALLOCATOR_ROLE(), true, "Allocator has ALLOCATOR_ROLE");
    }

    function verifyTemporaryRoles(ClisBnbStrategy strategy, address deployer) internal view {
        verifyRole(strategy, deployer, strategy.DEFAULT_ADMIN_ROLE(), false, "Deployer has DEFAULT_ADMIN_ROLE");
        verifyRole(strategy, deployer, strategy.PROCESSOR_MANAGER_ROLE(), false, "Deployer has PROCESSOR_MANAGER_ROLE");
        verifyRole(strategy, deployer, strategy.BUFFER_MANAGER_ROLE(), false, "Deployer has BUFFER_MANAGER_ROLE");
        verifyRole(strategy, deployer, strategy.PROVIDER_MANAGER_ROLE(), false, "Deployer has PROVIDER_MANAGER_ROLE");
        verifyRole(strategy, deployer, strategy.ASSET_MANAGER_ROLE(), false, "Deployer has ASSET_MANAGER_ROLE");
        verifyRole(strategy, deployer, strategy.UNPAUSER_ROLE(), false, "Deployer has UNPAUSER_ROLE");
        verifyRole(strategy, deployer, strategy.ALLOCATOR_MANAGER_ROLE(), false, "Deployer has ALLOCATOR_MANAGER_ROLE");
        verifyRole(strategy, deployer, strategy.DEPOSIT_MANAGER_ROLE(), false, "Deployer has DEPOSIT_MANAGER_ROLE");
        verifyRole(
            strategy,
            deployer,
            strategy.LISTA_DEPENDENCY_MANAGER_ROLE(),
            false,
            "Deployer has LISTA_DEPENDENCY_MANAGER_ROLE"
        );
    }
}
