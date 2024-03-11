// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TestInitialized} from "../TestInitialized.t.sol";

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {DeployFlamelingToken} from "../../script/DeployFlamelingToken.s.sol";
import {FlamelingToken} from "../../src/FlamelingToken.sol";

contract FuzzDividends is TestInitialized {
    uint256 constant MIN_DIVIDEND_BALANCE = 100_000 * 10 ** 18;

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

        vm.deal(USER1, 100 ether);
    }

    function test__Fuzz__DividendEligibility(uint256 amount) public {
        vm.assume(amount > 0 && amount < token.balanceOf(USER1));

        vm.prank(USER1);
        token.transfer(USER2, amount);

        if (token.balanceOf(USER1) < token.getMinSharesRequired()) {
            assertEq(token.getSharesOf(USER1), 0);
        } else {
            assertEq(token.getSharesOf(USER1), token.balanceOf(USER1));
        }

        if (token.balanceOf(USER2) < token.getMinSharesRequired()) {
            assertEq(token.getSharesOf(USER2), 0);
        } else {
            assertEq(token.getSharesOf(USER2), token.balanceOf(USER2));
        }
    }

    function test__Fuzz__ReceivesDividends(uint256 amount) public {
        vm.assume(amount >= 1e9 && amount < token.balanceOf(USER1));

        buyTokens(USER1, 2_500_000 ether);
        console.log(
            "Contract Balance",
            toDecimals(token.balanceOf(token.getDividendToken()), 18)
        );
        console.log("Token Account", toDecimals(token.balanceOf(USER1), 18));
        console.log(
            "Dividends Pending",
            toDecimals(token.getDividendFeesPending(), 18)
        );
        sellTokens(USER1, amount);
        console.log(
            "Contract Balance",
            toDecimals(token.balanceOf(token.getDividendToken()), 18)
        );
        console.log("Token Account", toDecimals(token.balanceOf(USER1), 18));
        console.log(
            "Dividends Pending",
            toDecimals(token.getDividendFeesPending(), 18)
        );

        if (token.balanceOf(USER1) > token.getSwapThreshold()) {
            assertEq(token.getNumberOfDividendAccounts(), 1);

            uint256 dividendBalance = IERC20(token.getDividendToken())
                .balanceOf(USER1);
            uint256 dividendContractBalance = IERC20(token.getDividendToken())
                .balanceOf(address(token));
            assertApproxEqAbs(
                dividendBalance + dividendContractBalance,
                token.getTotalDividends(),
                10
            );
        } else {
            assertEq(token.getNumberOfDividendAccounts(), 0);
        }
    }
}
