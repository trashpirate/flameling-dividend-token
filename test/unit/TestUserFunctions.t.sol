// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TestInitialized} from "../TestInitialized.t.sol";

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {DeployFlamelingToken} from "../../script/DeployFlamelingToken.s.sol";
import {FlamelingToken} from "../../src/FlamelingToken.sol";
import {DividendShares} from "./../../src/DividendShares.sol";

contract TestUserFunctions is TestInitialized {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event DividendsWithdrawn(address indexed sender, uint256 amount);

    function calcDividendsOf(address account) public view returns (uint256) {
        uint256 totalDividends = token.getTotalDividends();
        uint256 dividendsToClaim = (((2 ** 128 * totalDividends) /
            token.getTotalShares()) * (token.getSharesOf(account))) / 2 ** 128;
        return dividendsToClaim;
    }

    function test__Approval() public fundedWithTokens(USER1) {
        vm.prank(USER1);
        token.approve(SPENDER, SEND_TOKENS);

        assertEq(token.allowance(USER1, SPENDER), SEND_TOKENS);
    }

    function test__EmitEvent__Approval() public fundedWithTokens(USER1) {
        vm.expectEmit(true, true, true, true);
        emit Approval(USER1, SPENDER, SEND_TOKENS);

        vm.prank(USER1);
        token.approve(SPENDER, SEND_TOKENS);
    }

    function test__Transfer()
        public
        fundedWithTokens(USER1)
        fundedWithTokens(USER2)
    {
        uint256 endingBalanceUser1 = token.balanceOf(USER1) - SEND_TOKENS;
        uint256 endingBalanceUser2 = token.balanceOf(USER2) + SEND_TOKENS;
        vm.prank(USER1);
        token.transfer(USER2, SEND_TOKENS);

        assertEq(token.balanceOf(USER1), endingBalanceUser1);
        assertEq(token.balanceOf(USER2), endingBalanceUser2);
    }

    function test__EmitEvent__Transfer()
        public
        fundedWithTokens(USER1)
        fundedWithTokens(USER2)
        withLP
    {
        vm.expectEmit(true, true, true, true);
        emit Transfer(USER1, USER2, SEND_TOKENS);

        vm.prank(USER1);
        token.transfer(USER2, SEND_TOKENS);
    }

    function test__EmitEvent__TransferFrom()
        public
        fundedWithTokens(USER1)
        fundedWithTokens(USER2)
    {
        vm.prank(USER1);
        token.approve(SPENDER, SEND_TOKENS);

        vm.expectEmit(true, true, true, true);
        emit Transfer(USER1, USER2, SEND_TOKENS);

        vm.prank(SPENDER);
        token.transferFrom(USER1, USER2, SEND_TOKENS);
    }

    function test__BurnTokens() public fundedWithTokens(USER1) {
        uint256 endingBalanceUser = token.balanceOf(USER1) - SEND_TOKENS;

        vm.prank(USER1);
        token.transfer(BURN_ADDRESS, SEND_TOKENS);

        assertEq(token.balanceOf(USER1), endingBalanceUser);
        assertEq(token.balanceOf(BURN_ADDRESS), SEND_TOKENS);
    }

    function test__SellTokens() public fundedWithTokens(USER1) withLP {
        uint256 endingBalanceUser1 = token.balanceOf(USER1) - SEND_TOKENS;
        sellTokens(USER1, SEND_TOKENS);

        assertEq(token.balanceOf(USER1), endingBalanceUser1);
    }

    function test__BuyTokens() public fundedWithETH(USER1) withLP {
        uint256 fee = (SEND_TOKENS * token.getTotalTransactionFee()) / 10000;
        buyTokens(USER1, SEND_TOKENS);

        assertApproxEqAbs(token.balanceOf(USER1), SEND_TOKENS - fee, 10 ** 9);
    }

    function test__DistributesDividendsOnSwaps()
        public
        fundedWithTokens(USER1)
        fundedWithTokens(USER2)
        fundedWithETH(USER1)
        fundedWithETH(USER2)
        withLP
    {
        uint256 transferAmount = 875000 * 10 ** 18;

        vm.prank(USER1);
        token.transfer(USER2, transferAmount);
        buyTokens(USER1, transferAmount);
        buyTokens(USER2, transferAmount / 2);
        sellTokens(USER1, transferAmount * 3);
        sellTokens(USER2, transferAmount);

        // address owner = token.owner();
        // vm.prank(owner);
        // token.updateGasForProcessing(300000);

        // vm.startPrank(USER2);
        // uint gasLeft = gasleft();
        // token.transfer(USER1, transferAmount);
        // console.log(gasLeft - gasleft());
        // vm.stopPrank();

        uint256 tokenBalance1 = token.balanceOf(USER1);
        uint256 claimedDividends1 = IERC20(token.getDividendToken()).balanceOf(
            USER1
        );
        console.log("Token Balance 1: ", toDecimals(tokenBalance1, 18));
        console.log(
            "Withdrawn Dividends 1: ",
            toDecimals(claimedDividends1, 18)
        );

        uint256 tokenBalance2 = token.balanceOf(USER2);
        uint256 claimedDividends2 = IERC20(token.getDividendToken()).balanceOf(
            USER2
        );
        console.log("Token Balance 2: ", toDecimals(tokenBalance2, 18));
        console.log(
            "Withdrawn Dividends 2: ",
            toDecimals(claimedDividends2, 18)
        );

        console.log(
            "Total Dividends",
            toDecimals(token.getTotalDividends(), 18)
        );

        uint256 dividendContractBalance = IERC20(token.getDividendToken())
            .balanceOf(address(token));
        console.log(
            "\nDividend Contract Balance: ",
            toDecimals(dividendContractBalance, 18)
        );
        console.log("Dividend Remainder", token.getRemainingDividends());

        uint256 checkRatio = (claimedDividends2 * tokenBalance1) /
            tokenBalance2;

        assertEq(checkRatio, claimedDividends1);

        assertEq(
            claimedDividends1 + claimedDividends2 + dividendContractBalance,
            token.getTotalDividends()
        );
    }

    function test__DoesNotDistributeDividendsBelowTreshold()
        public
        fundedWithTokens(USER1)
        withLP
    {
        uint256 transferAmount = 225000 * 10 ** 18;

        for (uint256 index = 0; index < 2; index++) {
            sellTokens(USER1, transferAmount);
            sellTokens(USER1, transferAmount);
        }

        assertEq(IERC20(token.getDividendToken()).balanceOf(USER1), 0);
    }

    function test__CanWithdrawDividends()
        public
        fundedWithTokens(USER1)
        fundedWithETH(USER1)
        fundedWithTokens(USER2)
        fundedWithETH(USER2)
        withLP
    {
        address owner = token.owner();
        vm.prank(owner);
        token.updateGasForProcessing(0);

        buyTokens(USER1, SEND_TOKENS);
        buyTokens(USER2, SEND_TOKENS);
        sellTokens(USER1, SEND_TOKENS);
        sellTokens(USER2, SEND_TOKENS);

        vm.prank(USER1);
        token.withdrawDividends();
        uint256 claimedDividends1 = IERC20(token.getDividendToken()).balanceOf(
            USER1
        );
        console.log("\nUSER 1");
        console.log("Token Balance: ", token.balanceOf(USER1));
        console.log("Withdrawn Dividends: ", claimedDividends1);

        vm.prank(USER2);
        token.withdrawDividends();
        uint256 claimedDividends2 = IERC20(token.getDividendToken()).balanceOf(
            USER2
        );
        console.log("\nUSER 2");
        console.log("Token Balance: ", token.balanceOf(USER2));
        console.log("Withdrawn Dividends: ", claimedDividends2);

        uint256 contractDividendBalance = IERC20(token.getDividendToken())
            .balanceOf(address(token));
        console.log("\nContract Dividend Balance: ", contractDividendBalance);
        console.log("\nTotal Dividends: ", token.getTotalDividends());
        console.log("\nDividend Remainder: ", token.getRemainingDividends());

        assertEq(
            claimedDividends1 + claimedDividends2 + contractDividendBalance,
            token.getTotalDividends()
        );
    }

    function test__EmitEvent__withdrawDividends()
        public
        fundedWithTokens(USER1)
        fundedWithETH(USER1)
        withLP
    {
        address owner = token.owner();
        vm.prank(owner);
        token.updateGasForProcessing(0);

        sellTokens(USER1, SEND_TOKENS);
        buyTokens(USER1, SEND_TOKENS);
        sellTokens(USER1, SEND_TOKENS);
        sellTokens(USER1, SEND_TOKENS);

        uint256 dividends = calcDividendsOf(USER1);

        vm.expectEmit(true, false, false, false);
        emit DividendsWithdrawn(USER1, dividends);

        vm.prank(USER1);
        token.withdrawDividends();
    }

    function test__RevertsWhen__NoClaimableDividendsZeroContractBalance()
        public
        fundedWithTokens(USER1)
        fundedWithETH(USER1)
        withLP
    {
        address owner = token.owner();
        vm.prank(owner);
        token.updateGasForProcessing(0);

        sellTokens(USER1, SEND_TOKENS);
        buyTokens(USER1, SEND_TOKENS);
        sellTokens(USER1, SEND_TOKENS);

        vm.expectRevert(
            DividendShares.DividendShares__NoDividendsToClaim.selector
        );
        vm.prank(USER1);
        token.withdrawDividends();
    }

    function test__RevertsWhen__NoClaimableDividendsInsufficientContractBalance()
        public
        fundedWithTokens(USER1)
        fundedWithETH(USER1)
        withLP
    {
        sellTokens(USER1, SEND_TOKENS);
        buyTokens(USER1, SEND_TOKENS);
        sellTokens(USER1, SEND_TOKENS);
        sellTokens(USER1, SEND_TOKENS);

        console.log(
            "Dividend Contract Balance: ",
            toDecimals(
                IERC20(token.getDividendToken()).balanceOf(address(token)),
                18
            )
        );
        console.log(
            "Dividend User Balance: ",
            toDecimals(IERC20(token.getDividendToken()).balanceOf(USER1), 18)
        );
        vm.expectRevert(
            DividendShares.DividendShares__NoDividendsToClaim.selector
        );
        vm.prank(USER1);
        token.withdrawDividends();
    }

    function test__RevertsWhen__NotDividendEligible()
        public
        fundedWithTokens(USER1)
        fundedWithETH(USER1)
        withLP
    {
        vm.startPrank(token.owner());
        token.transfer(USER3, 90_000 * 10 ** 18);
        vm.stopPrank();

        address owner = token.owner();
        vm.prank(owner);
        token.updateGasForProcessing(0);

        sellTokens(USER1, SEND_TOKENS);
        buyTokens(USER1, SEND_TOKENS);
        sellTokens(USER1, SEND_TOKENS);
        sellTokens(USER1, SEND_TOKENS);

        vm.expectRevert();
        vm.prank(USER3);
        token.withdrawDividends();
    }

    function test__RevertsWhen__InsufficientBalance()
        public
        fundedWithTokens(USER1)
    {
        vm.expectRevert();
        vm.prank(USER1);
        token.transfer(USER2, (STARTING_BALANCE * 1200) / 1000);
    }

    function test__RevertsWhen__ReceiverIsZeroAddress()
        public
        fundedWithTokens(USER1)
    {
        vm.expectRevert();
        vm.prank(USER1);
        token.transfer(address(0), SEND_TOKENS);
    }

    function test__RevertsWhen__SenderIsZeroAddress()
        public
        fundedWithTokens(USER1)
    {
        vm.expectRevert();
        vm.prank(address(0));
        token.transfer(USER2, SEND_TOKENS);
    }
}
