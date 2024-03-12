// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {FlamelingToken} from "../src/FlamelingToken.sol";

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract DistributeRewards is Script {
    uint256 public amount = 15_000_000 * 10 ** 18;
    uint256 public newBalance = 100_000 ether;
    uint256 public numAccounts = 20;

    function fundAccounts(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));

        vm.startBroadcast();
        for (uint256 index = 1; index <= numAccounts; index++) {
            token.transfer(
                makeAddr(vm.toString(index)),
                newBalance + index * 100_000 ether
            );
        }
        vm.stopBroadcast();
    }

    function buyTokens(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));
        address routerAddress = token.getRouterV2Address();
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(token);

        uint256 ethAmount = router.getAmountsIn(amount, path)[0];

        vm.startBroadcast();
        uint256 gasLeft = gasleft();
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: ethAmount
        }(0, path, tx.origin, block.timestamp);
        console.log("BuyTokens - gas: ", gasLeft - gasleft());
        vm.stopBroadcast();
    }

    function sellTokens(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));

        // sell tokens
        address routerAddress = token.getRouterV2Address();
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = router.WETH();

        vm.startBroadcast();
        token.approve(routerAddress, amount);
        uint256 gasLeft = gasleft();
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            payable(tx.origin),
            block.timestamp
        );
        console.log("SellTokens - gas: ", gasLeft - gasleft());
        vm.stopBroadcast();

        // console.log("Sold Tokens for: ", (tx.origin).balance - startingBalance);
    }

    function transferTokens(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));
        vm.startBroadcast();
        uint256 gasLeft = gasleft();
        token.transfer(makeAddr("any"), 100 ether);
        console.log("TransferTokens - gas: ", gasLeft - gasleft());
        vm.stopBroadcast();
    }

    function run() external {
        address recentContractAddress = DevOpsTools.get_most_recent_deployment(
            "FlamelingToken",
            block.chainid
        );
        fundAccounts(recentContractAddress);
        sellTokens(recentContractAddress);
        transferTokens(recentContractAddress);
    }

    receive() external payable {}
}
