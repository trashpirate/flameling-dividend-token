// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TestInitialized} from "../TestInitialized.t.sol";

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {DeployFlamelingToken} from "../../script/DeployFlamelingToken.s.sol";
import {FlamelingToken} from "../../src/FlamelingToken.sol";
import {BuyTokens, SellTokens, ApproveTokens, TransferTokens} from "../../script/UserInteractions.s.sol";

contract TestUserInteractions is TestInitialized {
    modifier funded() {
        // fund user with tokens
        vm.startPrank(token.owner());
        token.transfer(msg.sender, STARTING_BALANCE);
        vm.stopPrank();
        _;
    }

    function setUp() external virtual override {
        deployment = new DeployFlamelingToken();
        token = deployment.run();
    }

    function test__Integration__ApproveTokens() public fundedWithTokens(msg.sender) {
        ApproveTokens approveTokens = new ApproveTokens();
        approveTokens.approveTokens(address(token));

        assertEq(token.allowance(msg.sender, approveTokens.spender()), approveTokens.amount());
    }

    function test__Integration__TransferTokens() public fundedWithTokens(msg.sender) {
        uint256 tokenBalance = token.balanceOf(msg.sender);
        TransferTokens transferTokens = new TransferTokens();
        transferTokens.transferTokens(address(token));

        assertEq(token.balanceOf(msg.sender), tokenBalance - transferTokens.amount());
        assertEq(token.balanceOf(transferTokens.newAddress()), transferTokens.amount());
    }

    function test__Integration__BuyTokens() public withLP {
        vm.deal(msg.sender, 10 ether);
        BuyTokens buyTokens = new BuyTokens();
        buyTokens.buyTokens(address(token));

        uint256 taxedAmount = buyTokens.amount() - buyTokens.amount() * 400 / 10000;

        assertApproxEqAbs(token.balanceOf(msg.sender), taxedAmount, 10 ** 18);
    }

    function test__Integration__SellTokens() public fundedWithTokens(msg.sender) withLP {
        uint256 startingBalance = (msg.sender).balance;
        uint256 tokenBalance = token.balanceOf(msg.sender);

        SellTokens sellTokens = new SellTokens();
        sellTokens.sellTokens(address(token));

        assertGt(msg.sender.balance, startingBalance);
        assertEq(token.balanceOf(msg.sender), tokenBalance - sellTokens.amount());
    }

    function test__Integration__ReceiveDividendTokens() public fundedWithTokens(msg.sender) withLP {
        // uint256 startingBalance = (msg.sender).balance;
        SellTokens sellTokens = new SellTokens();
        sellTokens.sellTokens(address(token));
        sellTokens.sellTokens(address(token));
        sellTokens.sellTokens(address(token));
        sellTokens.sellTokens(address(token));

        uint256 dividendTokenBalance = IERC20(token.getDividendToken()).balanceOf(msg.sender);
        assertApproxEqAbs(dividendTokenBalance, token.getTotalDividends(), 10);
    }
}
