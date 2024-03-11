// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TestInitialized} from "../TestInitialized.t.sol";

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {DeployFlamelingToken} from "../../script/DeployFlamelingToken.s.sol";
import {FlamelingToken} from "../../src/FlamelingToken.sol";

contract TestOwnerFunctions is TestInitialized {
    address NEW_FEE_ADDRESS = makeAddr("new-fee-address");
    address NEW_TOKEN_ADDRESS = makeAddr("new-token-address");
    address USER = makeAddr("user1");

    uint256 constant NEW_THRESHOLD = 80_000 * 10 ** 18;

    event BaseFeeAddressUpdated(address indexed sender, address baseFeeAddress);
    event DividendTokenUpdated(address indexed sender, address dividendToken);
    event BaseFeeUpdated(address indexed sender, uint256 baseFee);
    event DividendFeeUpdated(address indexed sender, uint256 rewardsFee);
    event ExcludedFromFees(address indexed account, bool isExcluded);
    event SwapThresholdUpdated(address indexed sender, uint256 swapThreshold);

    function test__Unit__ExcludeFromFee() public {
        vm.prank(token.owner());
        token.excludeFromFees(USER, true);

        assertEq(token.getExcludedFromFee(USER), true);
    }

    function test__Unit__RevertWhen_NotOwnerExcludesFromFee() public {
        vm.expectRevert();
        vm.prank(USER);
        token.excludeFromFees(USER, true);
    }

    function test__Unit__EmitEvent_ExcludedFromFees() public {
        vm.expectEmit(true, true, true, true);
        emit ExcludedFromFees(USER, true);

        vm.prank(token.owner());
        token.excludeFromFees(USER, true);
    }

    function test__Unit__UpdateFeeAddress() public {
        vm.prank(token.owner());
        token.updateFeeAddress(NEW_FEE_ADDRESS);

        assertEq(token.getFeeAddress(), NEW_FEE_ADDRESS);
    }

    function test__Unit__RevertWhen_NotOwnerUpdatesFeeAddress() public {
        vm.expectRevert();
        vm.prank(USER);
        token.updateFeeAddress(NEW_FEE_ADDRESS);
    }

    function test__Unit__EmitEvent_BaseFeeAddressUpdated() public {
        vm.expectEmit(true, true, true, true);
        emit BaseFeeAddressUpdated(token.owner(), NEW_FEE_ADDRESS);

        vm.prank(token.owner());
        token.updateFeeAddress(NEW_FEE_ADDRESS);
    }

    function test__Unit__UpdateDividendToken() public {
        vm.prank(token.owner());
        token.updateDividendToken(NEW_TOKEN_ADDRESS);

        assertEq(token.getDividendToken(), NEW_TOKEN_ADDRESS);
    }

    function test__Unit__RevertWhen_NotOwnerUpdatesDividendToken() public {
        vm.expectRevert();
        vm.prank(USER);
        token.updateDividendToken(NEW_TOKEN_ADDRESS);
    }

    function test__Unit__EmitEvent_DividendTokenUpdated() public {
        vm.expectEmit(true, true, true, true);
        emit DividendTokenUpdated(token.owner(), NEW_TOKEN_ADDRESS);

        vm.prank(token.owner());
        token.updateDividendToken(NEW_TOKEN_ADDRESS);
    }

    function test__Unit__UpdateBaseFee() public {
        vm.prank(token.owner());
        token.updateBaseFee(NEW_FEE);

        assertEq(token.getBaseFee(), NEW_FEE);
    }

    function test__Unit__RevertWhen_NotOwnerUpdatesBaseFee() public {
        vm.expectRevert();
        vm.prank(USER);
        token.updateBaseFee(NEW_FEE);
    }

    function test__Unit__EmitEvent_BaseFeeUpdated() public {
        vm.expectEmit(true, true, true, true);
        emit BaseFeeUpdated(token.owner(), NEW_FEE);

        vm.prank(token.owner());
        token.updateBaseFee(NEW_FEE);
    }

    function test__Unit__UpdateDividendFee() public {
        vm.prank(token.owner());
        token.updateDividendFee(NEW_FEE);

        assertEq(token.getDividendFee(), NEW_FEE);
    }

    function test__Unit__RevertWhen_NotOwnerUpdatesDividendFee() public {
        vm.expectRevert();
        vm.prank(USER);
        token.updateDividendFee(NEW_FEE);
    }

    function test__Unit__EmitEvent_DividendFeeUpdated() public {
        vm.expectEmit(true, true, true, true);
        emit DividendFeeUpdated(token.owner(), NEW_FEE);

        vm.prank(token.owner());
        token.updateDividendFee(NEW_FEE);
    }

    function test__Unit__UpdateSwapThreshold() public {
        vm.prank(token.owner());
        token.updateSwapThreshold(NEW_THRESHOLD);

        assertEq(token.getSwapThreshold(), NEW_THRESHOLD);
    }

    function test__Unit__RevertWhen_SwapThresholdTooSmall() public {
        uint256 smallThreshold = 20_000 * 10 ** 18;

        vm.prank(token.owner());
        vm.expectRevert();
        token.updateSwapThreshold(smallThreshold);
    }

    function test__Unit__RevertWhen_NotOwnerUpdatesSwapThreshold() public {
        vm.expectRevert();
        vm.prank(USER);
        token.updateSwapThreshold(NEW_THRESHOLD);
    }

    function test__Unit__EmitEvent_SwapThresholdUpdated() public {
        vm.expectEmit(true, true, true, true);
        emit SwapThresholdUpdated(token.owner(), NEW_THRESHOLD);

        vm.prank(token.owner());
        token.updateSwapThreshold(NEW_THRESHOLD);
    }

    function test__Unit__TransferOwnership() public {
        vm.prank(token.owner());
        token.transferOwnership(NEW_OWNER);

        assertEq(token.owner(), NEW_OWNER);
    }

    function test__Unit__RevertWhen_NotOwnerTransfersOwnership() public {
        vm.expectRevert();
        vm.prank(USER);
        token.transferOwnership(USER);
    }

    function test__Unit__RenounceOwnership() public {
        vm.prank(token.owner());
        token.renounceOwnership();

        assertEq(token.owner(), address(0));
    }

    function test__Unit__RevertWhen_NotOwnerRenouncesOwnership() public {
        vm.expectRevert();
        vm.prank(USER);
        token.renounceOwnership();
    }
}
