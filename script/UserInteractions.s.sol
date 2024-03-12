// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {FlamelingToken} from "../src/FlamelingToken.sol";

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract BuyTokens is Script {
    uint256 public amount = 625_000 * 10 ** 18;

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
        console.log("Bought Tokens: ", token.balanceOf(tx.origin));
    }

    function run() external {
        address recentContractAddress = DevOpsTools.get_most_recent_deployment(
            "FlamelingToken",
            block.chainid
        );
        buyTokens(recentContractAddress);
    }
}

contract SellTokens is Script {
    uint256 public amount = 625_000 * 10 ** 18;

    function sellTokens(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));
        address routerAddress = token.getRouterV2Address();
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = router.WETH();

        uint256 startingBalance = (tx.origin).balance;

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

        console.log("Sold Tokens for: ", (tx.origin).balance - startingBalance);
    }

    function run() external {
        address recentContractAddress = DevOpsTools.get_most_recent_deployment(
            "FlamelingToken",
            block.chainid
        );
        sellTokens(recentContractAddress);
    }
}

contract ApproveTokens is Script {
    uint256 public amount = 625_000 * 10 ** 18;
    address public spender = makeAddr("spender");

    function approveTokens(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));

        vm.startBroadcast();
        token.approve(spender, amount);
        vm.stopBroadcast();
        console.log("Approved Tokens: ", token.allowance(tx.origin, spender));
    }

    function run() external {
        address recentContractAddress = DevOpsTools.get_most_recent_deployment(
            "FlamelingToken",
            block.chainid
        );
        approveTokens(recentContractAddress);
    }
}

contract TransferTokens is Script {
    address public newAddress = makeAddr("new-address");
    uint256 public amount = 625_000 * 10 ** 18;

    function transferTokens(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));
        vm.startBroadcast();
        uint256 gasLeft = gasleft();
        token.transfer(newAddress, amount);
        console.log("TransferTokens - gas: ", gasLeft - gasleft());
        vm.stopBroadcast();
    }

    function run() external {
        address recentContractAddress = DevOpsTools.get_most_recent_deployment(
            "FlamelingToken",
            block.chainid
        );
        transferTokens(recentContractAddress);
    }
}

// claimTokens
