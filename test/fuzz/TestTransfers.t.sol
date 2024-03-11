// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TestInitialized} from "../TestInitialized.t.sol";

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {DeployFlamelingToken} from "../../script/DeployFlamelingToken.s.sol";
import {FlamelingToken} from "../../src/FlamelingToken.sol";

contract FuzzTransfers is TestInitialized {
    function addLiqudity(
        FlamelingToken token
    ) public returns (uint256, uint256) {
        vm.deal(token.owner(), 100 ether);

        uint256 lpSupply = 800_000_000 * 10 ** 18;

        address routerAddress = token.getRouterV2Address();

        vm.startPrank(token.owner());

        token.approve(routerAddress, lpSupply);

        (uint256 liquidityToken, uint256 liquidityETH, ) = IUniswapV2Router02(
            routerAddress
        ).addLiquidityETH{value: 10 ether}(
            address(token),
            lpSupply,
            0,
            0,
            token.owner(),
            block.timestamp
        );
        vm.stopPrank();

        // console.log(liquidityToken);
        // console.log(liquidityETH);
        // console.log(liquidity);

        return (liquidityToken, liquidityETH);
    }

    function setUp() external virtual override {
        deployment = new DeployFlamelingToken();
        token = deployment.run();

        addLiqudity(token);

        vm.startPrank(token.owner());
        token.transfer(USER1, token.balanceOf(token.owner()));
        vm.stopPrank();
    }

    function test__Fuzz__Transfer(uint256 amount) public skipFork {
        vm.assume(amount <= token.balanceOf(USER1));

        uint256 endingBalanceUser1 = token.balanceOf(USER1) - amount;
        uint256 endingBalanceUser2 = token.balanceOf(USER2) + amount;

        vm.prank(USER1);
        token.transfer(USER2, amount);

        assertEq(token.balanceOf(USER1), endingBalanceUser1);
        assertEq(token.balanceOf(USER2), endingBalanceUser2);
    }

    function test__Fuzz__TransferFrom(uint256 amount) public skipFork {
        vm.assume(amount <= token.balanceOf(USER1));

        uint256 endingBalanceUser1 = token.balanceOf(USER1) - amount;
        uint256 endingBalanceUser2 = token.balanceOf(USER2) + amount;

        vm.prank(USER1);
        token.approve(SPENDER, amount);

        vm.prank(SPENDER);
        token.transferFrom(USER1, USER2, amount);

        assertEq(token.balanceOf(USER1), endingBalanceUser1);
        assertEq(token.balanceOf(USER2), endingBalanceUser2);
    }

    function test__Fuzz__Sell(uint256 amount) public skipFork {
        vm.assume(amount >= 10 ** 18 && amount < token.balanceOf(USER1));

        uint256 endingBalanceUser1 = token.balanceOf(USER1) - amount;
        uint256 startingETHBalance1 = USER1.balance;

        address routerAddress = token.getRouterV2Address();
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = router.WETH();

        vm.startPrank(USER1);
        token.approve(routerAddress, amount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            USER1,
            block.timestamp
        );
        vm.stopPrank();

        assertGt(USER1.balance, startingETHBalance1);
        assertEq(token.balanceOf(USER1), endingBalanceUser1);
    }

    function test__Fuzz__Buy(
        uint256 amount
    ) public fundedWithETH(USER1) skipFork {
        vm.assume(amount >= 10 ** 18 && amount < 100_000_000 * 10 ** 18);

        console.log("\nTransfer Amount", amount);
        uint256 fee = (amount * token.getTotalTransactionFee()) / 10000;
        uint256 endingBalance = token.balanceOf(USER1) + amount - fee;

        address routerAddress = token.getRouterV2Address();
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(token);

        uint256 ethAmount = router.getAmountsIn(amount, path)[0];
        console.log("ETH Amount", ethAmount);

        vm.startPrank(USER1);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: ethAmount
        }(0, path, USER1, block.timestamp);
        vm.stopPrank();

        assertApproxEqAbs(token.balanceOf(USER1), endingBalance, 1 ether);
    }
}
