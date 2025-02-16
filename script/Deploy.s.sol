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

        uint256 subscriptionFeeUSD = 200;
        uint256 subscriptionPeriod = 90;
        address owner =  deployer;
        address coldWallet = deployer;
        address bnb;
        address usdc;
        address usdt;
        address wbtc;
        address priceFeedBNBUSD;
        address priceFeedETHUSD;
        address priceFeedWBTCUSD;

        // Deploying SubscriptionPayment contract
        SubscriptionPayment subscriptionPayment = new SubscriptionPayment(
            subscriptionFeeUSD,
            subscriptionPeriod,
            owner, 
            coldWallet, 
            bnb, 
            usdc, 
            usdt, 
            wbtc,
            priceFeedBNBUSD,
            priceFeedETHUSD,
            priceFeedWBTCUSD
        );
        console.log("SubscriptionPayment deployed at: ", address(subscriptionPayment));

        vm.stopBroadcast();
    }
}
