// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TestInitialized} from "../TestInitialized.t.sol";

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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

    function test__Integration__GasOptimization()
        public
        fundedWithTokens(msg.sender)
        withLP
    {
        vm.deal(msg.sender, 10 ether);
        vm.startPrank(token.owner());
        token.transfer(msg.sender, token.balanceOf(token.owner()));
        token.excludeFromDividends(msg.sender);
        token.excludeFromFees(makeAddr("any"), true);
        vm.stopPrank();

        IERC20 dividendToken = IERC20(token.getDividendToken());

        DistributeRewards distributeRewards = new DistributeRewards();
        distributeRewards.fundAccounts(address(token));
        distributeRewards.sellTokens(address(token));
        distributeRewards.transferTokens(address(token));
        console.log(
            "Processed: %s / %s ",
            token.getLastIndexProcessed(),
            token.getNumberOfDividendAccounts()
        );
        distributeRewards.buyTokens(address(token));
        console.log(
            "Processed: %s / %s ",
            token.getLastIndexProcessed(),
            token.getNumberOfDividendAccounts()
        );

        console.log(
            "Contract Dividend Balance",
            dividendToken.balanceOf(address(token))
        );
        console.log("Dividend Remainder", token.getRemainingDividends());
    }
}
