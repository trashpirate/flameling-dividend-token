// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TestInitialized} from "../TestInitialized.t.sol";

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DeployFlamelingToken} from "../../script/DeployFlamelingToken.s.sol";
import {FlamelingToken} from "../../src/FlamelingToken.sol";
import {DividendShares} from "./../../src/DividendShares.sol";
import {TestUserFunctions} from "./TestUserFunctions.t.sol";

contract TestDividendToken is TestInitialized {
    address NEW_FEE_ADDRESS = makeAddr("new-fee-address");
    address NEW_TOKEN_ADDRESS = makeAddr("new-token-address");
    address USER = makeAddr("user1");

    event DividendTokenUpdated(address indexed sender, address dividendToken);

    function test__userLoosesDividendShares() public {
        vm.startPrank(token.owner());
        token.transfer(USER, SEND_TOKENS);
        vm.stopPrank();

        assertEq(token.getSharesOf(USER), SEND_TOKENS);

        uint256 transferAmount = SEND_TOKENS - 50_000 ether;
        vm.prank(USER);
        token.transfer(makeAddr("any"), transferAmount);
        vm.stopPrank();

        assertEq(token.getSharesOf(USER), 0);
    }

    function test__UpdateDividendToken() public {
        vm.prank(token.owner());
        token.updateDividendToken(NEW_TOKEN_ADDRESS);

        assertEq(token.getDividendToken(), NEW_TOKEN_ADDRESS);
    }

    function test__RevertWhen_NotOwnerUpdatesDividendToken() public {
        vm.expectRevert();
        vm.prank(USER);
        token.updateDividendToken(NEW_TOKEN_ADDRESS);
    }

    function test__EmitEvent_DividendTokenUpdated() public {
        vm.expectEmit(true, true, true, true);
        emit DividendTokenUpdated(token.owner(), NEW_TOKEN_ADDRESS);

        vm.prank(token.owner());
        token.updateDividendToken(NEW_TOKEN_ADDRESS);
    }

    function test__ExcludeFromDividends() public {
        vm.startPrank(token.owner());
        token.excludeFromDividends(USER);
        vm.stopPrank();

        assertEq(token.getExcludedFromDividends(USER), true);
    }

    function test__IncludeInDividends() public {
        vm.startPrank(token.owner());
        token.transfer(USER, SEND_TOKENS);
        token.excludeFromDividends(USER);
        vm.stopPrank();

        assertEq(token.getExcludedFromDividends(USER), true);

        vm.startPrank(token.owner());
        token.includeInDividends(USER, token.balanceOf(USER));
        vm.stopPrank();

        assertEq(token.getExcludedFromDividends(USER), false);
        assertEq(token.getSharesOf(USER), token.balanceOf(USER));
    }

    function test__RevertWhen_NotOwnerIncludesFromDividends() public {
        vm.startPrank(token.owner());
        token.transfer(USER, SEND_TOKENS);
        token.excludeFromDividends(USER);
        vm.stopPrank();

        uint userBalance = token.balanceOf(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                USER
            )
        );
        vm.prank(USER);
        token.includeInDividends(USER, userBalance);
    }

    function test__RevertWhen_NotOwnerExcludesFromDividends() public {
        vm.startPrank(token.owner());
        token.transfer(USER, SEND_TOKENS);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                USER
            )
        );
        vm.prank(USER);
        token.excludeFromDividends(USER);
    }

    /** GETTER Functions */

    function test__NumberOfDividendAccounts() public {
        uint256 NUM = 10;
        vm.startPrank(token.owner());
        for (uint256 index = 0; index < NUM; index++) {
            address user = makeAddr(vm.toString(100 + index));
            token.transfer(user, SEND_TOKENS);
        }
        vm.stopPrank();

        uint256 numHolders = token.getNumberOfDividendAccounts();
        assertEq(numHolders, NUM);
    }

    function test__GetSharesOf() public {
        vm.startPrank(token.owner());
        token.transfer(USER, SEND_TOKENS);
        vm.stopPrank();

        assertEq(token.getSharesOf(USER), SEND_TOKENS);
    }

    function test__GetProcessedIndex() public withLP {
        uint256 newBalance = 100_000 ether;
        uint256 numAccounts = 10;
        uint256 amount = 15_000_000 * 10 ** 18;

        vm.startPrank(token.owner());
        for (uint256 index = 1; index <= numAccounts; index++) {
            token.transfer(
                makeAddr(vm.toString(index)),
                newBalance + index * 100_000 ether
            );
        }
        token.excludeFromFees(token.owner(), false);
        vm.stopPrank();

        sellTokens(token.owner(), amount);
        vm.startPrank(token.owner());
        token.transfer(makeAddr("any"), 100);
        vm.stopPrank();

        IERC20 dividendToken = IERC20(token.getDividendToken());
        for (
            uint256 index = 0;
            index < token.getNumberOfDividendAccounts();
            index++
        ) {
            address dividendAccount = token.getDividendAccountAtIndex(index);
            uint256 dividendBalance = dividendToken.balanceOf(dividendAccount);

            console.log(
                "Tokens: %s, Dividend Balance: %s",
                token.balanceOf(dividendAccount),
                dividendBalance
            );
        }

        assertEq(token.getNextIndexToProcess(), 5);
    }

    function test__GetDividendAccountInidex() public {
        uint256 NUM = 3;
        address[] memory userArray = new address[](NUM);
        vm.startPrank(token.owner());
        for (uint256 index = 0; index < NUM; index++) {
            address user = makeAddr(vm.toString(100 + index));
            userArray[index] = user;
            token.transfer(user, SEND_TOKENS);
        }
        vm.stopPrank();

        address holder = token.getDividendAccountAtIndex(1);
        assertEq(holder, userArray[1]);
    }

    function test__RevertsWhen_WrongDividendAccountInidex() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                DividendShares.DividendShares__InvalidIndex.selector,
                1,
                0
            )
        );
        token.getDividendAccountAtIndex(1);
    }
}
