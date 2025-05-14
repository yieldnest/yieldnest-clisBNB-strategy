// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {Script, stdJson} from "lib/forge-std/src/Script.sol";

import {IProvider} from "lib/yieldnest-vault/src/interface/IProvider.sol";
import {MainnetActors, TestnetActors} from "script/Actors.sol";
import {BscContracts, ChapelContracts, IContracts} from "script/Contracts.sol";

import {TransparentUpgradeableProxy} from
    "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {TimelockController} from "lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

import {ProxyUtils} from "lib/yieldnest-vault/script/ProxyUtils.sol";
import {ClisBnbStrategy} from "src/ClisBnbStrategy.sol";
import {IClisBnbActors} from "script/Actors.sol";

abstract contract BaseScript is Script {
    using stdJson for string;

    uint256 public minDelay;
    IClisBnbActors public actors;
    IContracts public contracts;

    address public deployer;
    TimelockController public timelock;
    IProvider public rateProvider;
    ClisBnbStrategy public clisBnbStrategy;
    ClisBnbStrategy public clisBnbStrategyImplementation;

    address public clisBnbStrategyProxyAdmin;
    address public clisBnbStrategyImplementationProxyAdmin;

    error UnsupportedChain();
    error InvalidSetup();

    // needs to be overridden by child script
    function symbol() public view virtual returns (string memory);

    function _setup() public virtual {
        deployer = msg.sender;

        if (block.chainid == 56) {
            minDelay = 1 days;
            MainnetActors _actors = new MainnetActors();
            actors = IClisBnbActors(_actors);
            contracts = IContracts(new BscContracts());
        }
        if (block.chainid == 97) {
            minDelay = 10 seconds;
            TestnetActors _actors = new TestnetActors();
            actors = IClisBnbActors(_actors);
            contracts = IContracts(new ChapelContracts());
        }
    }

    function _verifySetup() public view virtual {
        if (block.chainid != 56 && block.chainid != 97) {
            revert UnsupportedChain();
        }
        if (
            address(actors) == address(0) || address(contracts) == address(0) || address(rateProvider) == address(0)
                || address(timelock) == address(0)
        ) {
            revert InvalidSetup();
        }
    }

    function _deployTimelockController() internal virtual {
        address[] memory proposers = new address[](1);
        proposers[0] = actors.PROPOSER_1();

        address[] memory executors = new address[](1);
        executors[0] = actors.EXECUTOR_1();

        address admin = actors.ADMIN();

        timelock = new TimelockController(minDelay, proposers, executors, admin);
    }

    function _loadDeployment() internal virtual {
        if (!vm.isFile(_deploymentFilePath())) {
            return;
        }
        string memory jsonInput = vm.readFile(_deploymentFilePath());

        deployer = address(vm.parseJsonAddress(jsonInput, ".deployer"));
        timelock = TimelockController(payable(address(vm.parseJsonAddress(jsonInput, ".timelock"))));
        rateProvider = IProvider(payable(address(vm.parseJsonAddress(jsonInput, ".rateProvider"))));

        clisBnbStrategy =
            ClisBnbStrategy(payable(address(vm.parseJsonAddress(jsonInput, string.concat(".", symbol(), "-proxy")))));
        clisBnbStrategyImplementation = ClisBnbStrategy(
            payable(address(vm.parseJsonAddress(jsonInput, string.concat(".", symbol(), "-implementation"))))
        );
        clisBnbStrategyProxyAdmin = address(vm.parseJsonAddress(jsonInput, string.concat(".", symbol(), "-proxyAdmin")));
    }

    function _deploymentFilePath() internal view virtual returns (string memory) {
        return string.concat(vm.projectRoot(), "/deployments/", symbol(), "-", Strings.toString(block.chainid), ".json");
    }

    function _saveDeployment() internal virtual {
        vm.serializeString(symbol(), "symbol", symbol());
        vm.serializeAddress(symbol(), "deployer", deployer);
        vm.serializeAddress(symbol(), "admin", actors.ADMIN());
        vm.serializeAddress(symbol(), "timelock", address(timelock));
        vm.serializeAddress(symbol(), "rateProvider", address(rateProvider));

        vm.serializeAddress(
            symbol(), string.concat(symbol(), "-proxyAdmin"), ProxyUtils.getProxyAdmin(address(clisBnbStrategy))
        );
        vm.serializeAddress(symbol(), string.concat(symbol(), "-proxy"), address(clisBnbStrategy));

        string memory jsonOutput = vm.serializeAddress(
            symbol(), string.concat(symbol(), "-implementation"), address(clisBnbStrategyImplementation)
        );

        vm.writeJson(jsonOutput, _deploymentFilePath());
    }
}
