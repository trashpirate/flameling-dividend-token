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

    event BaseFeeUpdated(address indexed sender, uint256 baseFee);
    event DividendFeeUpdated(address indexed sender, uint256 rewardsFee);
    event ExcludedFromFees(address indexed account, bool isExcluded);
    event SwapThresholdUpdated(address indexed sender, uint256 swapThreshold);
    event AMMPairUpdated(address indexed ammpair, bool value);

    /** UDPATE AMM PAIR */
    function test__UpdateAmmPair() public {
        address newPair = makeAddr("some-pair");
        vm.prank(token.owner());
        token.updateAMMPair(newPair, true);

        assertEq(token.getAMMPair(newPair), true);
    }

    function test__EmitsEvent__UpdateAmmPair() public {
        address newPair = makeAddr("some-pair");

        vm.expectEmit(true, true, true, true);
        emit AMMPairUpdated(newPair, true);

        vm.prank(token.owner());
        token.updateAMMPair(newPair, true);
    }

    function test__RevertWhen__UniswapPairChanged() public {
        address newPair = token.getPairV2Address();

        vm.prank(token.owner());
        vm.expectRevert(
            FlamelingToken.FlamelingToken__AMMPairAlreadySet.selector
        );
        token.updateAMMPair(newPair, true);
    }

    /** EXCLUDE FROM FEE */
    function test__ExcludeFromFee() public {
        vm.prank(token.owner());
        token.excludeFromFees(USER, true);

        assertEq(token.getExcludedFromFee(USER), true);
    }

    function test__RevertWhen_NotOwnerExcludesFromFee() public {
        vm.expectRevert();
        vm.prank(USER);
        token.excludeFromFees(USER, true);
    }

    function test__EmitEvent_ExcludedFromFees() public {
        vm.expectEmit(true, true, true, true);
        emit ExcludedFromFees(USER, true);

        vm.prank(token.owner());
        token.excludeFromFees(USER, true);
    }

    /** UDPATE FEE ADDRESS */
    function test__UpdateFeeAddress() public {
        vm.prank(token.owner());
        token.updateFeeAddress(NEW_FEE_ADDRESS);

        assertEq(token.getFeeAddress(), NEW_FEE_ADDRESS);
    }

    function test__RevertWhen_NotOwnerUpdatesFeeAddress() public {
        vm.expectRevert();
        vm.prank(USER);
        token.updateFeeAddress(NEW_FEE_ADDRESS);
    }

    function test__EmitEvent_BaseFeeAddressUpdated() public {
        vm.expectEmit(true, true, true, true);
        emit BaseFeeAddressUpdated(token.owner(), NEW_FEE_ADDRESS);

        vm.prank(token.owner());
        token.updateFeeAddress(NEW_FEE_ADDRESS);
    }

    /** UPDATE BASE FEE */
    function test__UpdateBaseFee() public {
        vm.prank(token.owner());
        token.updateBaseFee(NEW_FEE);

        assertEq(token.getBaseFee(), NEW_FEE);
    }

    function test__RevertWhen_NotOwnerUpdatesBaseFee() public {
        vm.expectRevert();
        vm.prank(USER);
        token.updateBaseFee(NEW_FEE);
    }

    function test__EmitEvent_BaseFeeUpdated() public {
        vm.expectEmit(true, true, true, true);
        emit BaseFeeUpdated(token.owner(), NEW_FEE);

        vm.prank(token.owner());
        token.updateBaseFee(NEW_FEE);
    }

    /** UPDATE DIVIDEND FEE */
    function test__UpdateDividendFee() public {
        vm.prank(token.owner());
        token.updateDividendFee(NEW_FEE);

        assertEq(token.getDividendFee(), NEW_FEE);
    }

    function test__RevertWhen_NotOwnerUpdatesDividendFee() public {
        vm.expectRevert();
        vm.prank(USER);
        token.updateDividendFee(NEW_FEE);
    }

    function test__EmitEvent_DividendFeeUpdated() public {
        vm.expectEmit(true, true, true, true);
        emit DividendFeeUpdated(token.owner(), NEW_FEE);

        vm.prank(token.owner());
        token.updateDividendFee(NEW_FEE);
    }

    /** UDPATE SWAP THRESHOLD */
    function test__UpdateSwapThreshold() public {
        vm.prank(token.owner());
        token.updateSwapThreshold(NEW_THRESHOLD);

        assertEq(token.getSwapThreshold(), NEW_THRESHOLD);
    }

    function test__RevertWhen_SwapThresholdTooSmall() public {
        uint256 smallThreshold = 20_000 * 10 ** 18;

        vm.prank(token.owner());
        vm.expectRevert();
        token.updateSwapThreshold(smallThreshold);
    }

    function test__RevertWhen_NotOwnerUpdatesSwapThreshold() public {
        vm.expectRevert();
        vm.prank(USER);
        token.updateSwapThreshold(NEW_THRESHOLD);
    }

    function test__EmitEvent_SwapThresholdUpdated() public {
        vm.expectEmit(true, true, true, true);
        emit SwapThresholdUpdated(token.owner(), NEW_THRESHOLD);

        vm.prank(token.owner());
        token.updateSwapThreshold(NEW_THRESHOLD);
    }

    /** TRANSFER OWNERSHIP */
    function test__TransferOwnership() public {
        vm.prank(token.owner());
        token.transferOwnership(NEW_OWNER);

        assertEq(token.owner(), NEW_OWNER);
    }

    function test__RevertWhen_NotOwnerTransfersOwnership() public {
        vm.expectRevert();
        vm.prank(USER);
        token.transferOwnership(USER);
    }

    /** RENOUNCE OWNERSHIP */
    function test__RenounceOwnership() public {
        vm.prank(token.owner());
        token.renounceOwnership();

        assertEq(token.owner(), address(0));
    }

    function test__RevertWhen_NotOwnerRenouncesOwnership() public {
        vm.expectRevert();
        vm.prank(USER);
        token.renounceOwnership();
    }
}
