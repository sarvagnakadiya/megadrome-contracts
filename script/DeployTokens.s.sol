// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {BuriBuriZeamon} from "contracts/tokens/BuriBuriZeamon.sol";
import {QuantumRobot} from "contracts/tokens/QuantumRobot.sol";

contract DeployTokens is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
        address deployer = vm.rememberKey(deployerPrivateKey);

        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        BuriBuriZeamon bbz = new BuriBuriZeamon();
        QuantumRobot qubot = new QuantumRobot();

        console.log("=== Tokens Deployed ===");
        console.log("BuriBuriZeamon (BBZ):", address(bbz));
        console.log("QuantumRobot (QUBOT):", address(qubot));

        vm.stopBroadcast();

        // Save output
        string memory root = vm.projectRoot();
        string memory outputPath = string.concat(root, "/script/constants/output/DeployTokens-Monad.json");

        string memory json = "output";
        vm.serializeAddress(json, "BuriBuriZeamon", address(bbz));
        string memory finalJson = vm.serializeAddress(json, "QuantumRobot", address(qubot));
        vm.writeJson(finalJson, outputPath);

        console.log("Output saved to:", outputPath);
    }
}
