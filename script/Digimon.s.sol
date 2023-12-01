// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import { Script } from "forge-std/Script.sol";
import { Digimon } from "../src/Digimon.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DigimonScript is Script {
    Digimon internal nft;

    function run() public {
        vm.startBroadcast();
        nft = new Digimon("Digimon", "DMON", "DMON.com/", 5000000000000000, 5, 3333);
        vm.stopBroadcast();
    }
}
