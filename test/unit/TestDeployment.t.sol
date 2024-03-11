// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TestInitialized} from "../TestInitialized.t.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {DeployFlamelingToken} from "../../script/DeployFlamelingToken.s.sol";
import {FlamelingToken} from "../../src/FlamelingToken.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract TestDeployment is TestInitialized {
    function test__Unit__Initialization() public {
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.decimals(), DECIMALS);
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
        assertEq(token.balanceOf(token.owner()), TOTAL_SUPPLY);

        assertEq(token.getBaseFee(), OPERATIONS_FEE);
        assertEq(token.getDividendFee(), DIVIDEND_FEE);
        assertEq(token.getTotalTransactionFee(), DIVIDEND_FEE + OPERATIONS_FEE);
    }

    function test__Unit__ConstructorArguments() public {
        HelperConfig config = deployment.helperConfig();
        (address initialOwner, address feeAddress, address tokenAddress, address routerAddress) =
            config.activeNetworkConfig();
        assertEq(token.owner(), initialOwner);
        assertEq(token.getFeeAddress(), feeAddress);
        assertEq(token.getDividendToken(), tokenAddress);
        assertEq(token.getRouterV2Address(), routerAddress);
    }

    function test__Unit__CreateV2Pair() public {
        IUniswapV2Pair pair = IUniswapV2Pair(token.getPairV2Address());
        assertEq(pair.token1(), address(token));
    }

    function test__Unit__OwnerIsExcludedFromFees() public {
        assertEq(token.getExcludedFromFee(token.owner()), true);
    }

    function test__Unit__ContractIsExcludedFromFees() public {
        assertEq(token.getExcludedFromFee(address(token)), true);
    }

    function test__Unit__OwnerIsExcludedFromDividends() public {
        assertEq(token.getExcludedFromDividends(token.owner()), true);
    }

    function test__Unit__ContractIsExcludedFromDividends() public {
        assertEq(token.getExcludedFromDividends(address(token)), true);
    }

    function test__Unit__LPPairIsExcludedFromDividends() public {
        assertEq(token.getExcludedFromDividends(token.getPairV2Address()), true);
    }
}
