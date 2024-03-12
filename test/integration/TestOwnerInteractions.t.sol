// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TestInitialized} from "../TestInitialized.t.sol";

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {DeployFlamelingToken} from "../../script/DeployFlamelingToken.s.sol";
import {FlamelingToken} from "../../src/FlamelingToken.sol";
import {UpdateFeeAddress, UpdateDividendFee, UpdateBaseFee, UpdateDividendToken, UpdateSwapThreshold, UpdateGasForProcessing, ExcludeFromFees, ExcludeFromDividends, UpdateAMMPair} from "../../script/OwnerInteractions.s.sol";

contract TestOwnerInteractions is TestInitialized {
    function setUp() external virtual override {
        deployment = new DeployFlamelingToken();
        token = deployment.run();

        vm.prank(token.owner());
        token.transferOwnership(msg.sender);
    }

    function test__Integration__UpdateFeeAddress() public {
        UpdateFeeAddress updateFeeAddress = new UpdateFeeAddress();
        updateFeeAddress.updateFeeAddress(address(token));

        assertEq(token.getFeeAddress(), updateFeeAddress.newFeeAddress());
    }

    function test__Integration__UpdateDividendFee() public {
        UpdateDividendFee updateDividendFee = new UpdateDividendFee();
        updateDividendFee.updateDividendFee(address(token));

        assertEq(token.getDividendFee(), updateDividendFee.newFee());
    }

    function test__Integration__UpdateBaseFee() public {
        UpdateBaseFee updateBaseFee = new UpdateBaseFee();
        updateBaseFee.updateBaseFee(address(token));

        assertEq(token.getBaseFee(), updateBaseFee.newFee());
    }

    function test__Integration__UpdateDividendToken() public {
        UpdateDividendToken updateDividendToken = new UpdateDividendToken();
        updateDividendToken.updateDividendToken(address(token));

        assertEq(token.getDividendToken(), updateDividendToken.newToken());
    }

    function test__Integration__UpdateSwapThreshold() public {
        UpdateSwapThreshold updateSwapThreshold = new UpdateSwapThreshold();
        updateSwapThreshold.updateSwapThreshold(address(token));

        assertEq(token.getSwapThreshold(), updateSwapThreshold.newThreshold());
    }

    function test__Integration__UpdateGasForProcessing() public {
        UpdateGasForProcessing updateGasForProcessing = new UpdateGasForProcessing();
        updateGasForProcessing.updateGasForProcessing(address(token));

        assertEq(
            token.getGasForProcessing(),
            updateGasForProcessing.newGasLimit()
        );
    }

    function test__Integration__ExcludeFromFees() public {
        ExcludeFromFees excludeFromFees = new ExcludeFromFees();

        assertEq(token.isExcludedFromFee(excludeFromFees.someAddress()), false);
        excludeFromFees.excludeFromFees(address(token));
        assertEq(token.isExcludedFromFee(excludeFromFees.someAddress()), true);
    }

    function test__Integration__ExcludeFromDividends() public {
        ExcludeFromDividends excludeFromDividends = new ExcludeFromDividends();

        assertEq(
            token.getExcludedFromDividends(excludeFromDividends.someAddress()),
            false
        );
        excludeFromDividends.excludeFromDividends(address(token));
        assertEq(
            token.getExcludedFromDividends(excludeFromDividends.someAddress()),
            true
        );
    }

    function test__Integration__UpdateAMMPair() public {
        UpdateAMMPair updateAMMPair = new UpdateAMMPair();

        assertEq(token.getAMMPair(updateAMMPair.someAddress()), false);
        updateAMMPair.updateAMMPair(address(token));
        assertEq(token.getAMMPair(updateAMMPair.someAddress()), true);
    }
}
