// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";
import {TestInitialized} from "../TestInitialized.t.sol";

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {DeployFlamelingToken} from "../../script/DeployFlamelingToken.s.sol";
import {FlamelingToken} from "../../src/FlamelingToken.sol";
import {ERC20Token} from "../../mock/ERC20Token.sol";
import {Handler} from "./handlers/Handler.sol";

contract Invariants is TestInitialized {
    uint256 constant MIN_DIVIDEND_BALANCE = 100_000 * 10 ** 18;
    uint256 counter;
    Handler handler;

    ERC20Token dividendToken;

    function addLiqudity(
        FlamelingToken token
    ) public returns (uint256, uint256) {
        vm.deal(token.owner(), 100 ether);

        uint256 lpSupply = token.balanceOf(token.owner());

        address routerAddress = token.getRouterV2Address();
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

        vm.startPrank(token.owner());

        token.approve(routerAddress, lpSupply);

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = router
            .addLiquidityETH{value: 100 ether}(
            address(token),
            lpSupply,
            0,
            0,
            token.owner(),
            block.timestamp
        );
        vm.stopPrank();

        console.log("\nDIVIDEND TOKEN");
        console.log("Token Amount: ", amountToken);
        console.log("ETH Amount: ", amountETH);
        console.log("Liquidity Amount: ", liquidity);
        console.log("");
        return (amountToken, amountETH);
    }

    function setUp() external virtual override {
        deployment = new DeployFlamelingToken();
        token = deployment.run();

        addLiqudity(token);

        handler = new Handler(token);
        dividendToken = handler.dividendToken();

        excludeSender(address(0));
        excludeSender(address(token));
        excludeSender(token.getPairV2Address());
        excludeSender(token.getRouterV2Address());
        excludeSender(token.owner());
        excludeSender(token.getFeeAddress());
        excludeSender(address(handler));

        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = Handler.sellTokens.selector;
        selectors[1] = Handler.buyTokens.selector;
        selectors[2] = Handler.transferTokens.selector;
        selectors[3] = Handler.approveTokens.selector;
        selectors[4] = Handler.transferFromTokens.selector;

        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectors})
        );

        targetContract(address(handler));
    }

    function invariant__TokenSupply() public skipFork {
        uint256 sumOfBalances;
        uint256 numOfActors = handler.actorCount();

        for (uint256 index = 0; index < numOfActors; index++) {
            sumOfBalances += token.balanceOf(handler.actorAtIndex(index));
        }

        uint256 lpTokens = token.balanceOf(token.getPairV2Address());
        uint256 contractTokens = token.balanceOf(address(token));

        uint256 allTokens = lpTokens + contractTokens + sumOfBalances;
        assertEq(token.totalSupply(), allTokens);
    }

    function invariant__DividendMapping() public skipFork {
        assertEq(
            handler.ghost_numberOfDividendAccounts(),
            token.getNumberOfDividendAccounts()
        );
    }

    function invariant__TotalDividendShares() public skipFork {
        assertEq(handler.ghost_totalDividendShares(), token.getTotalShares());
    }

    function invariant__TotalDividends() public skipFork {
        uint256 sumOfDividends;
        uint256 numOfActors = handler.actorCount();

        for (uint256 index = 0; index < numOfActors; index++) {
            address account = handler.actorAtIndex(index);
            uint256 dividends = dividendToken.balanceOf(account);
            sumOfDividends += dividends;
        }

        uint256 contractBalance = dividendToken.balanceOf(address(token));
        console.log("Dividend Contract Balance:", contractBalance);
        console.log("Sum of dividends:", sumOfDividends);

        assertEq(token.getTotalDividends(), sumOfDividends + contractBalance);
    }

    function invariant__CallSummary() public view skipFork {
        handler.callSummary();
    }
}
