// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

import {RewardsCompounder} from "src/RewardsCompounder.sol";
import {BaseScript} from "script/BaseScript.sol";
import {Script, stdJson} from "lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ClisBnbStrategy} from "src/ClisBnbStrategy.sol";

contract DeployRewardsCompounder is BaseScript, Test {
    using stdJson for string;

    enum Env {
        TEST,
        PROD
    }

    RewardsCompounder public rewardsCompounder;
    uint256 public minRewardsToCompound;
    address public owner;
    Env public deploymentEnv = Env.PROD;

    function symbol() public pure override returns (string memory) {
        return "clisBnbRewardsCompounder";
    }

    function setEnv(Env env) public {
        deploymentEnv = env;
    }

    function setMinRewardsToCompound(uint256 _minRewardsToCompound) public {
        minRewardsToCompound = _minRewardsToCompound;
    }

    function setOwner(address _owner) public {
        owner = _owner;
    }

    function run() public {
        _setup();

        vm.startBroadcast();

        deployer = msg.sender;
        clisBnbStrategy = ClisBnbStrategy(payable(contracts.CLIS_BNB_STRATEGY()));

        assertGt(minRewardsToCompound, 0, "minRewardsToCompound must be greater than 0");
        assertNotEq(owner, address(0), "owner must be set");
        assertNotEq(address(clisBnbStrategy), address(0), "clisBnbStrategy must be set");

        rewardsCompounder = new RewardsCompounder(payable(address(clisBnbStrategy)), minRewardsToCompound, owner);

        _saveDeployment();

        vm.stopBroadcast();
    }

    function _deploymentFilePath() internal view virtual override returns (string memory) {
        return string.concat(vm.projectRoot(), "/deployments/", symbol(), "-", Strings.toString(block.chainid), ".json");
    }

    function _saveDeployment() internal virtual override {
        vm.serializeString(symbol(), "symbol", symbol());
        vm.serializeAddress(symbol(), "deployer", deployer);
        vm.serializeAddress(symbol(), "owner", owner);

        string memory jsonOutput =
            vm.serializeAddress(symbol(), string.concat(symbol(), "rewardsCompounder"), address(rewardsCompounder));
        vm.writeJson(jsonOutput, _deploymentFilePath());
    }
}
