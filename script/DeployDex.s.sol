//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Script} from 'forge-std/Script.sol';
import {DEX} from '../src/dex.sol';

contract DeployDex is Script{
    function run() external returns (DEX){
        vm.startBroadcast();
        DEX dex = new DEX();
        vm.stopBroadcast();
        return dex;
    }
}