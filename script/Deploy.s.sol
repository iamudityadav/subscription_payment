// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {SubscriptionPayment} from "../src/SubscriptionPayment.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        console.log("Deployer: ", deployer);

        vm.startBroadcast(deployerKey);

        address owner =  deployer;
        address coldWallet = deployer;
        address bnb = 0x871ACbEabBaf8Bed65c22ba7132beCFaBf8c27B5;
        address usdc = 0x2B0974b96511a728CA6342597471366D3444Aa2a;
        address usdt= 0xA1d7f71cbBb361A77820279958BAC38fC3667c1a;
        address wbtc = 0xD0684a311F47AD7fdFf03951d7b91996Be9326E1;

        // Deploying SubscriptionPayment contract
        SubscriptionPayment subscriptionPayment = new SubscriptionPayment(
            owner, 
            coldWallet, 
            bnb, 
            usdc, 
            usdt, 
            wbtc
        );
        console.log("SubscriptionPayment deployed at: ", address(subscriptionPayment));

        vm.stopBroadcast();
    }
}
