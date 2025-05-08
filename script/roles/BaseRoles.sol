// SPDX-License-Identifier: BSD Clause-3
pragma solidity ^0.8.24;

import {ClisBnbStrategy} from "src/ClisBnbStrategy.sol";
import {IActors} from "script/Actors.sol";

library BaseRoles {
    function configureDefaultRoles(ClisBnbStrategy clisBnbStrategy, address timelock, IActors actors) internal {
        // set admin roles
        clisBnbStrategy.grantRole(clisBnbStrategy.DEFAULT_ADMIN_ROLE(), actors.ADMIN());
        clisBnbStrategy.grantRole(clisBnbStrategy.PROCESSOR_ROLE(), actors.PROCESSOR());
        clisBnbStrategy.grantRole(clisBnbStrategy.PAUSER_ROLE(), actors.PAUSER());
        clisBnbStrategy.grantRole(clisBnbStrategy.UNPAUSER_ROLE(), actors.UNPAUSER());
        clisBnbStrategy.grantRole(clisBnbStrategy.DEPOSIT_MANAGER_ROLE(), actors.DEPOSIT_MANAGER());
        clisBnbStrategy.grantRole(clisBnbStrategy.LISTA_DEPENDENCY_MANAGER_ROLE(), actors.LISTA_DEPENDENCY_MANAGER());

        // set timelock roles
        clisBnbStrategy.grantRole(clisBnbStrategy.PROVIDER_MANAGER_ROLE(), timelock);
        clisBnbStrategy.grantRole(clisBnbStrategy.ASSET_MANAGER_ROLE(), timelock);
        clisBnbStrategy.grantRole(clisBnbStrategy.BUFFER_MANAGER_ROLE(), timelock);
        clisBnbStrategy.grantRole(clisBnbStrategy.PROCESSOR_MANAGER_ROLE(), timelock);
        clisBnbStrategy.grantRole(clisBnbStrategy.ALLOCATOR_MANAGER_ROLE(), timelock);
    }

    function configureDefaultRolesStrategy(ClisBnbStrategy clisBnbStrategy, address timelock, IActors actors)
        internal
    {
        configureDefaultRoles(clisBnbStrategy, timelock, actors);
    }

    function configureTemporaryRoles(ClisBnbStrategy clisBnbStrategy) internal {
        configureTemporaryRoles(clisBnbStrategy, address(this));
    }

    function configureTemporaryRoles(ClisBnbStrategy clisBnbStrategy, address deployer) internal {
        clisBnbStrategy.grantRole(clisBnbStrategy.DEFAULT_ADMIN_ROLE(), deployer);
        clisBnbStrategy.grantRole(clisBnbStrategy.PROCESSOR_MANAGER_ROLE(), deployer);
        clisBnbStrategy.grantRole(clisBnbStrategy.BUFFER_MANAGER_ROLE(), deployer);
        clisBnbStrategy.grantRole(clisBnbStrategy.PROVIDER_MANAGER_ROLE(), deployer);
        clisBnbStrategy.grantRole(clisBnbStrategy.ASSET_MANAGER_ROLE(), deployer);
        clisBnbStrategy.grantRole(clisBnbStrategy.UNPAUSER_ROLE(), deployer);
        clisBnbStrategy.grantRole(clisBnbStrategy.ALLOCATOR_MANAGER_ROLE(), deployer);
        clisBnbStrategy.grantRole(clisBnbStrategy.DEPOSIT_MANAGER_ROLE(), deployer);
        clisBnbStrategy.grantRole(clisBnbStrategy.LISTA_DEPENDENCY_MANAGER_ROLE(), deployer);
    }

    function configureTemporaryRolesStrategy(ClisBnbStrategy clisBnbStrategy, address deployer) internal {
        configureTemporaryRoles(clisBnbStrategy, deployer);
    }

    function renounceTemporaryRoles(ClisBnbStrategy clisBnbStrategy, address deployer) internal {
        clisBnbStrategy.renounceRole(clisBnbStrategy.DEFAULT_ADMIN_ROLE(), deployer);
        clisBnbStrategy.renounceRole(clisBnbStrategy.PROCESSOR_MANAGER_ROLE(), deployer);
        clisBnbStrategy.renounceRole(clisBnbStrategy.BUFFER_MANAGER_ROLE(), deployer);
        clisBnbStrategy.renounceRole(clisBnbStrategy.PROVIDER_MANAGER_ROLE(), deployer);
        clisBnbStrategy.renounceRole(clisBnbStrategy.ASSET_MANAGER_ROLE(), deployer);
        clisBnbStrategy.renounceRole(clisBnbStrategy.UNPAUSER_ROLE(), deployer);
        clisBnbStrategy.renounceRole(clisBnbStrategy.ALLOCATOR_MANAGER_ROLE(), deployer);
        clisBnbStrategy.renounceRole(clisBnbStrategy.DEPOSIT_MANAGER_ROLE(), deployer);
        clisBnbStrategy.renounceRole(clisBnbStrategy.LISTA_DEPENDENCY_MANAGER_ROLE(), deployer);
    }

    function renounceTemporaryRolesStrategy(ClisBnbStrategy clisBnbStrategy, address deployer) internal {
        renounceTemporaryRoles(clisBnbStrategy, deployer);
    }
}
