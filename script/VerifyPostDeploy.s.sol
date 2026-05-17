// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {GameGovernor} from "../contracts/GameGovernor.sol";
import {GameVault4626} from "../contracts/GameVault4626.sol";

contract VerifyPostDeploy is Script {
    function run() external view {
        address governorAddress = vm.envAddress("GOVERNOR");
        address timelockAddress = vm.envAddress("TIMELOCK");
        address vaultAddress = vm.envAddress("VAULT");
        address deployer = vm.envOr("DEPLOYER", address(0));

        GameGovernor governor = GameGovernor(payable(governorAddress));
        TimelockController timelock = TimelockController(payable(timelockAddress));
        GameVault4626 vault = GameVault4626(vaultAddress);

        require(timelock.getMinDelay() == 2 days, "wrong timelock delay");
        require(governor.votingDelay() == 7_200, "wrong voting delay");
        require(governor.votingPeriod() == 50_400, "wrong voting period");
        require(governor.proposalThreshold() == 1_000_000 ether, "wrong proposal threshold");
        require(vault.hasRole(vault.TREASURY_ROLE(), timelockAddress), "timelock does not control treasury");
        require(vault.hasRole(vault.PAUSER_ROLE(), timelockAddress), "timelock is not vault pauser");
        require(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), timelockAddress), "timelock is not vault admin");
        require(timelock.hasRole(timelock.PROPOSER_ROLE(), governorAddress), "governor is not proposer");
        require(timelock.hasRole(timelock.CANCELLER_ROLE(), governorAddress), "governor is not canceller");
        require(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)), "open executor missing");
        require(timelock.hasRole(timelock.TIMELOCK_ADMIN_ROLE(), timelockAddress), "timelock is not self-admin");

        if (deployer != address(0)) {
            require(!vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), deployer), "deployer still has vault admin");
            require(!timelock.hasRole(timelock.TIMELOCK_ADMIN_ROLE(), deployer), "deployer still has timelock admin");
        }

        console2.log("Post-deployment checks passed");
        console2.log("Governor:", governorAddress);
        console2.log("Timelock:", timelockAddress);
        console2.log("Vault:", vaultAddress);
    }
}
