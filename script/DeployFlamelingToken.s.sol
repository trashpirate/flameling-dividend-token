// SPDX-License-Identifier: MIT

pragma solidity >=0.4.0;

import {Script} from "forge-std/Script.sol";
import {FlamelingToken} from "../src/FlamelingToken.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DeployFlamelingToken is Script {
    HelperConfig public helperConfig;

    function run() external returns (FlamelingToken token) {
        helperConfig = new HelperConfig(false, 0);
        (
            string memory name,
            string memory symbol,
            address initialOwner,
            address feeAddress,
            address tokenAddress,
            address routerAddress
        ) = helperConfig.activeNetworkConfig();
        vm.startBroadcast();
        token = new FlamelingToken(
            name,
            symbol,
            initialOwner,
            feeAddress,
            tokenAddress,
            routerAddress
        );
        vm.stopBroadcast();
    }
}
