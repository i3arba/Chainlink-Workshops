// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Trident} from "../src/Trident.sol";
import {TridentFunctions}  from "../src/TridentFunctions.sol";

contract CounterScript is Script {
    function setUp() public {}

    address router = 0x0 ; //Input the Functions router of the blockchain you want to use
    bytes32 donId = 0x1; //Input the Functions donId of the blockchain you want to use
    uint64 subId = 0; //Create your subscription and input in here

    function run() public {
        vm.broadcast();
        TridentFunctions functions = new TridentFunctions(
            router, 
            donId, 
            subId 
        );
        Trident trident = new Trident(functions);

    }
}
