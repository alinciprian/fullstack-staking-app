//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {SimpleStaking} from "../src/SimpleStaking.sol";
import {SimpleToken} from "../src/SimpleToken.sol";
import {devUSDC} from "../src/devUSDC.sol";

contract Deploy is Script {
    uint256 initialSupply = 100000000 * 1e18;
    uint256 rewardRate = 1 * 1e18;
    address owner = 0x80F719526E1AF4364E3AC1581c4C9626F61c91Fb;

    function run() external returns (SimpleToken simpleToken, SimpleStaking simpleStaking, devUSDC dUSDC) {
        vm.startBroadcast();

        simpleToken = new SimpleToken();
        dUSDC = new devUSDC(initialSupply);
        simpleStaking = new SimpleStaking(address(simpleToken), address(dUSDC), rewardRate);

        simpleToken.mint(owner, initialSupply);
        dUSDC.transfer(address(simpleStaking), initialSupply);

        vm.stopBroadcast();
    }
}
