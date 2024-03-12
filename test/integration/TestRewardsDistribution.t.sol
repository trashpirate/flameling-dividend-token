// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TestInitialized} from "../TestInitialized.t.sol";

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {DeployFlamelingToken} from "../../script/DeployFlamelingToken.s.sol";
import {FlamelingToken} from "../../src/FlamelingToken.sol";
import {DistributeRewards} from "../../script/RewardDistribution.s.sol";

contract TestRewardsDistribution is TestInitialized {
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

    function test__Integration__DistributeRewards()
        public
        fundedWithTokens(msg.sender)
        withLP
    {
        vm.startPrank(token.owner());
        token.transfer(msg.sender, token.balanceOf(token.owner()));
        token.excludeFromDividends(msg.sender);
        token.excludeFromFees(makeAddr("any"), true);
        vm.stopPrank();

        IERC20 dividendToken = IERC20(token.getDividendToken());

        DistributeRewards distributeRewards = new DistributeRewards();
        distributeRewards.sellTokens(address(token));
        distributeRewards.transferTokens(address(token));
        distributeRewards.transferTokens(address(token));
        distributeRewards.transferTokens(address(token));
        distributeRewards.transferTokens(address(token));

        uint256 totalDividendsDistributed;
        for (
            uint256 index = 1;
            index <= distributeRewards.numAccounts();
            index++
        ) {
            uint256 dividendBalance = dividendToken.balanceOf(
                makeAddr(vm.toString(index))
            );
            totalDividendsDistributed += dividendBalance;
            console.log(
                "Tokens: %s, Dividend Balance: %s",
                token.balanceOf(makeAddr(vm.toString(index))),
                dividendBalance
            );
        }

        totalDividendsDistributed += dividendToken.balanceOf(msg.sender);

        console.log(
            "Contract Dividend Balance",
            dividendToken.balanceOf(address(token))
        );
        console.log("Dividend Remainder", token.getRemainingDividends());

        assertApproxEqAbs(
            token.getTotalDividends(),
            totalDividendsDistributed + token.getRemainingDividends(),
            100
        );
    }
}
