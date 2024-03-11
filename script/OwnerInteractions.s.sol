// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {FlamelingToken} from "../src/FlamelingToken.sol";

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract TransferOwnership is Script {
    address public newOwner = makeAddr("new-owner");

    function transferOwnership(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));

        vm.startBroadcast();
        token.transferOwnership(newOwner);
        vm.stopBroadcast();
    }

    function run() external {
        address recentContractAddress = DevOpsTools.get_most_recent_deployment("FlamelingToken", block.chainid);
        transferOwnership(recentContractAddress);
    }
}

contract UpdateFeeAddress is Script {
    address public newFeeAddress = makeAddr("new-fee-address");

    function updateFeeAddress(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));

        vm.startBroadcast();
        token.updateFeeAddress(newFeeAddress);
        vm.stopBroadcast();
    }

    function run() external {
        address recentContractAddress = DevOpsTools.get_most_recent_deployment("FlamelingToken", block.chainid);
        updateFeeAddress(recentContractAddress);
    }
}

contract UpdateDividendToken is Script {
    address public newToken = makeAddr("token-address");

    function updateDividendToken(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));

        vm.startBroadcast();
        token.updateDividendToken(newToken);
        vm.stopBroadcast();
    }

    function run() external {
        address recentContractAddress = DevOpsTools.get_most_recent_deployment("FlamelingToken", block.chainid);
        updateDividendToken(recentContractAddress);
    }
}

contract UpdateDividendFee is Script {
    uint256 public newFee = 500;

    function updateDividendFee(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));

        vm.startBroadcast();
        token.updateDividendFee(newFee);
        vm.stopBroadcast();
    }

    function run() external {
        address recentContractAddress = DevOpsTools.get_most_recent_deployment("FlamelingToken", block.chainid);
        updateDividendFee(recentContractAddress);
    }
}

contract UpdateBaseFee is Script {
    uint256 public newFee = 500;

    function updateBaseFee(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));

        vm.startBroadcast();
        token.updateBaseFee(newFee);
        vm.stopBroadcast();
    }

    function run() external {
        address recentContractAddress = DevOpsTools.get_most_recent_deployment("FlamelingToken", block.chainid);
        updateBaseFee(recentContractAddress);
    }
}

contract UpdateSwapThreshold is Script {
    uint256 public newThreshold = 200_000 * 10 ** 18;

    function updateSwapThreshold(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));

        vm.startBroadcast();
        token.updateSwapThreshold(newThreshold);
        vm.stopBroadcast();
    }

    function run() external {
        address recentContractAddress = DevOpsTools.get_most_recent_deployment("FlamelingToken", block.chainid);
        updateSwapThreshold(recentContractAddress);
    }
}

contract UpdateGasForProcessing is Script {
    uint256 public newGasLimit = 20000;

    function updateGasForProcessing(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));

        vm.startBroadcast();
        token.updateGasForProcessing(newGasLimit);
        vm.stopBroadcast();
    }

    function run() external {
        address recentContractAddress = DevOpsTools.get_most_recent_deployment("FlamelingToken", block.chainid);
        updateGasForProcessing(recentContractAddress);
    }
}

contract ExcludeFromFees is Script {
    address public someAddress = makeAddr("some-address");

    function excludeFromFees(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));

        vm.startBroadcast();
        token.excludeFromFees(someAddress, true);
        vm.stopBroadcast();
    }

    function run() external {
        address recentContractAddress = DevOpsTools.get_most_recent_deployment("FlamelingToken", block.chainid);
        excludeFromFees(recentContractAddress);
    }
}

contract ExcludeFromDividends is Script {
    address public someAddress = makeAddr("some-address");

    function excludeFromDividends(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));

        vm.startBroadcast();
        token.excludeFromDividends(someAddress, true);
        vm.stopBroadcast();
    }

    function run() external {
        address recentContractAddress = DevOpsTools.get_most_recent_deployment("FlamelingToken", block.chainid);
        excludeFromDividends(recentContractAddress);
    }
}

contract UpdateAMMPair is Script {
    address public someAddress = makeAddr("some-address");

    function updateAMMPair(address recentContractAddress) public {
        FlamelingToken token = FlamelingToken(payable(recentContractAddress));

        vm.startBroadcast();
        token.updateAMMPair(someAddress, true);
        vm.stopBroadcast();
    }

    function run() external {
        address recentContractAddress = DevOpsTools.get_most_recent_deployment("FlamelingToken", block.chainid);
        updateAMMPair(recentContractAddress);
    }
}
