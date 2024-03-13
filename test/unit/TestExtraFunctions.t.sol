// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TestInitialized} from "../TestInitialized.t.sol";

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {DeployFlamelingToken} from "../../script/DeployFlamelingToken.s.sol";
import {FlamelingToken} from "../../src/FlamelingToken.sol";
import {TestUserFunctions} from "./TestUserFunctions.t.sol";

import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract TestExtraFunctions is TestInitialized {
    event DividendsDistributed(uint256 indexed amount);

    function test__FeesPending() public fundedWithTokens(USER1) withLP {
        uint256 totalTxFee = token.getBaseFee() + token.getDividendFee();
        uint256 totalFees = (SEND_TOKENS * totalTxFee) / 10000;

        sellTokens(USER1, SEND_TOKENS);

        assertEq(token.balanceOf(address(token)), totalFees);
        assertEq(
            token.getBaseFeesPending() + token.getDividendFeesPending(),
            totalFees
        );
    }

    function test__CollectsBaseFee()
        public
        fundedWithTokens(USER1)
        fundedWithETH(USER1)
        withLP
    {
        uint256 currentBalance = token.getFeeAddress().balance;

        // SEND_TOKENS = 1_000_000
        // 4% of 1_000_000 = 40_000
        sellTokens(USER1, SEND_TOKENS); // 40_000
        // console.log(token.getBaseFeesPending());
        assertEq(token.getFeeAddress().balance - currentBalance, 0);
        buyTokens(USER1, SEND_TOKENS); // 80_000
        // console.log(token.getBaseFeesPending());
        assertEq(token.getFeeAddress().balance - currentBalance, 0);
        sellTokens(USER1, SEND_TOKENS); // 120_000
        // console.log(token.getBaseFeesPending());
        assertEq(token.getFeeAddress().balance - currentBalance, 0);
        buyTokens(USER1, SEND_TOKENS); // 160_000 => threshold hit but no swap
        // console.log(token.getBaseFeesPending());
        assertEq(token.getFeeAddress().balance - currentBalance, 0);
        assertGt(
            token.balanceOf(address(token)),
            160_000 * 10 ** token.decimals()
        );
        sellTokens(USER1, SEND_TOKENS); // => threshold hit -> swap
        assertGt(token.getFeeAddress().balance - currentBalance, 0);
        // console.log(token.getBaseFeesPending());
        console.log(
            "Fee collected: %e",
            (token.getFeeAddress().balance - currentBalance)
        );
    }

    function test__DistributesRewards()
        public
        fundedWithTokens(USER1)
        fundedWithTokens(USER2)
        fundedWithTokens(USER3)
        withLP
    {
        vm.startPrank(token.owner());
        token.excludeFromFees(token.owner(), false);
        vm.stopPrank();

        sellTokens(token.owner(), 15_000_000 ether); // 2 % should be 300_000

        vm.startPrank(token.owner());
        token.excludeFromFees(token.owner(), true);
        token.transfer(makeAddr("any"), 100 ether);
        vm.stopPrank();

        console.log(
            "\nNumber of DividendAccounts: ",
            token.getNumberOfDividendAccounts()
        );
        console.log(
            "Token Contract Balance: ",
            token.balanceOf(address(token))
        );
        console.log(
            "Dividend Contract Balance: ",
            IERC20(token.getDividendToken()).balanceOf(address(token))
        );

        uint dividendBalance1 = IERC20(token.getDividendToken()).balanceOf(
            USER1
        );
        uint dividendBalance2 = IERC20(token.getDividendToken()).balanceOf(
            USER2
        );
        uint dividendBalance3 = IERC20(token.getDividendToken()).balanceOf(
            USER3
        );

        console.log("Dividend Balance: ", dividendBalance1);
        console.log("Dividend Balance: ", dividendBalance2);
        console.log("Dividend Balance: ", dividendBalance3);

        assertEq(dividendBalance1, dividendBalance2);
        assertEq(dividendBalance3, dividendBalance2);
    }

    function test__EmitEvent_DividendsDistributed()
        public
        fundedWithTokens(USER1)
        fundedWithTokens(USER2)
        fundedWithTokens(USER3)
        withLP
    {
        vm.startPrank(token.owner());
        token.excludeFromFees(token.owner(), false);
        vm.stopPrank();

        sellTokens(token.owner(), 15_000_000 ether); // 2 % should be 300_000

        vm.startPrank(token.owner());
        token.excludeFromFees(token.owner(), true);

        uint256 tokenAmount = 359181708435969060461006; // token amount to be received (can't be calculated in advance accurately)

        vm.expectEmit(true, true, true, true);
        emit DividendsDistributed(tokenAmount);

        token.transfer(makeAddr("any"), 100 ether);
        vm.stopPrank();
    }

    function test__NoRewardsDistributionIfNoShares() public withLP {
        vm.startPrank(token.owner());
        token.excludeFromFees(token.owner(), false);
        vm.stopPrank();

        sellTokens(token.owner(), 15_000_000 ether); // 2 % should be 300_000

        assertEq(token.getTotalShares(), 0);
        vm.startPrank(token.owner());
        token.transfer(makeAddr("any"), 100);
        vm.stopPrank();

        assertEq(
            IERC20(token.getDividendToken()).balanceOf(address(token)),
            token.getTotalDividends()
        );
    }
}
