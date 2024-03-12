// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestHelperConfig is Test {
    function test__MainnetConfig() public {
        HelperConfig config = new HelperConfig(true, 1);
        HelperConfig.NetworkConfig memory networkConfig = config
            .getMainnetConfig();

        (
            ,
            ,
            address initialOwner,
            address feeAddress,
            address tokenAddress,
            address routerAddress
        ) = config.activeNetworkConfig();

        assertEq(initialOwner, networkConfig.initialOwner);
        assertEq(feeAddress, networkConfig.feeAddress);
        assertEq(tokenAddress, networkConfig.tokenAddress);
        assertEq(routerAddress, networkConfig.routerAddress);
    }

    function test__TestnetConfig() public {
        HelperConfig config = new HelperConfig(true, 97);
        HelperConfig.NetworkConfig memory networkConfig = config
            .getTestnetConfig();

        (
            ,
            ,
            address initialOwner,
            address feeAddress,
            address tokenAddress,
            address routerAddress
        ) = config.activeNetworkConfig();

        assertEq(initialOwner, networkConfig.initialOwner);
        assertEq(feeAddress, networkConfig.feeAddress);
        assertEq(tokenAddress, networkConfig.tokenAddress);
        assertEq(routerAddress, networkConfig.routerAddress);
    }

    function test__LocalConfig() public {
        HelperConfig config = new HelperConfig(true, 123);
        HelperConfig.NetworkConfig memory networkConfig = config
            .getLocalConfig();

        (
            ,
            ,
            address initialOwner,
            address feeAddress,
            address tokenAddress,
            address routerAddress
        ) = config.activeNetworkConfig();

        assertEq(initialOwner, networkConfig.initialOwner);
        assertEq(feeAddress, networkConfig.feeAddress);
        assertEq(tokenAddress, networkConfig.tokenAddress);
        assertEq(routerAddress, networkConfig.routerAddress);
    }

    function test__AnvilConfig() public {
        HelperConfig config = new HelperConfig(true, 31337);
        HelperConfig.NetworkConfig memory networkConfig = config
            .getAnvilConfig();

        (
            ,
            ,
            address initialOwner,
            address feeAddress,
            address tokenAddress,
            address routerAddress
        ) = config.activeNetworkConfig();

        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(tokenAddress);

        uint256 amount = 625_000 * 10 ** 18;
        uint256 ethAmount = router.getAmountsIn(amount, path)[0];

        deal(address(this), ethAmount);

        assertEq(IERC20(tokenAddress).balanceOf(address(this)), 0);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: ethAmount
        }(0, path, address(this), block.timestamp);

        assertGt(IERC20(tokenAddress).balanceOf(address(this)), 0);
        assertEq(initialOwner, networkConfig.initialOwner);
        assertEq(feeAddress, networkConfig.feeAddress);
    }
}
