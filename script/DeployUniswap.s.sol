// SPDX-License-Identifier: MIT

pragma solidity >=0.4.0;

import {Script, console} from "forge-std/Script.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract DeployUniswap is Script {
    IUniswapV2Router02 uniswapRouter;

    function run() external returns (address router) {
        vm.startBroadcast();
        address weth = deployCode("WETH.sol:WBNB");
        console.log("WBNB: %s", weth);

        address factory = deployCode(
            "UniswapV2Factory.sol",
            abi.encode(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266)
        );
        console.log("Factory: %s", factory);

        router = deployCode("UniswapV2Router02.sol", abi.encode(factory, weth));
        console.log("Router: %s", router);
        vm.stopBroadcast();

        uniswapRouter = IUniswapV2Router02(router);
    }
}
