// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC20Token} from "../src/ERC20Token.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {DeployUniswap} from "./DeployUniswap.s.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract HelperConfig is Script {
    // chain configurations
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        address initialOwner;
        address feeAddress;
        address tokenAddress;
        address routerAddress;
    }

    constructor(bool testing, uint256 _chainId) {
        if (testing) {
            vm.chainId(_chainId);
            console.log("Chain ID set to: ", _chainId);
        }
        if (
            block.chainid == 1 || block.chainid == 56 || block.chainid == 8453
        ) {
            activeNetworkConfig = getMainnetConfig();
        } else if (
            block.chainid == 11155111 ||
            block.chainid == 97 ||
            block.chainid == 84532 ||
            block.chainid == 84531
        ) {
            activeNetworkConfig = getTestnetConfig();
        } else if (block.chainid == 123) {
            activeNetworkConfig = getLocalConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    function getTestnetConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                initialOwner: 0xCbA52038BF0814bC586deE7C061D6cb8B203f8e1,
                feeAddress: 0xCbA52038BF0814bC586deE7C061D6cb8B203f8e1,
                tokenAddress: 0x09601E2bfA5b0101e0ba151541d95646B1eeE381,
                routerAddress: 0xD99D1c33F9fC3444f8101754aBC46c52416550D1
            });
    }

    function getMainnetConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                initialOwner: 0x4671a210C4CF44C43dC5E44DAf68e64D46cdc703,
                feeAddress: 0x0cf66382d52C2D6c1D095c536c16c203117E2B2f,
                tokenAddress: 0x2aC895fEba458B42884DCbCB47D57e44c3a303c8,
                routerAddress: 0x10ED43C718714eb63d5aA57B78B54704E256024E
            });
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        // fund contract with ETH
        vm.deal(tx.origin, 1000 ether);

        // deploy uniswap
        DeployUniswap deployment = new DeployUniswap();
        address router = deployment.run();
        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(router);

        // deploy reward token
        vm.broadcast();
        ERC20Token token = new ERC20Token();

        // add LP
        uint256 lpTokenAmount = token.balanceOf(tx.origin);
        uint256 lpETHAmount = 10 ether;

        vm.startBroadcast();
        token.approve(address(uniswapRouter), lpTokenAmount);
        (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        ) = uniswapRouter.addLiquidityETH{value: lpETHAmount}(
                address(token),
                lpTokenAmount,
                0,
                0,
                tx.origin,
                block.timestamp
            );
        vm.stopBroadcast();

        console.log("\nREWARD TOKEN");
        console.log("Token Amount: ", amountToken);
        console.log("ETH Amount: ", amountETH);
        console.log("Liquidity Amount: ", liquidity);

        return
            NetworkConfig({
                initialOwner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                feeAddress: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                tokenAddress: address(token),
                routerAddress: address(uniswapRouter)
            });
    }

    function getLocalConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                initialOwner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                feeAddress: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                tokenAddress: 0x2aC895fEba458B42884DCbCB47D57e44c3a303c8,
                routerAddress: 0x10ED43C718714eb63d5aA57B78B54704E256024E
            });
    }

    function getActiveNetworkConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        return activeNetworkConfig;
    }
}
