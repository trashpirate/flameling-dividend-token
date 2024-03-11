// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {DeployFlamelingToken} from "../script/DeployFlamelingToken.s.sol";
import {FlamelingToken} from "../src/FlamelingToken.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import {HelperConfig} from "../script/HelperConfig.s.sol";

contract TestInitialized is Test {
    FlamelingToken token;

    // constructor arguments;
    DeployFlamelingToken deployment;

    // constants
    string constant NAME = "FlamelingToken";
    string constant SYMBOL = "0x77";
    uint8 constant DECIMALS = 18;
    uint256 constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** DECIMALS;
    uint256 constant OPERATIONS_FEE = 200;
    uint256 constant DIVIDEND_FEE = 200;
    uint256 constant MIN_SWAP_RETURN = 641822829098787115019; // 78 flameling tokens per dividend token

    address WBNB_FUNDER = 0x9ade1c17d25246c405604344f89E8F23F8c1c632;
    address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address USER1 = makeAddr("user1");
    address USER2 = makeAddr("user2");
    address USER3 = makeAddr("user3");
    address SPENDER = makeAddr("spender");
    address NEW_OWNER = makeAddr("new-owner");
    address BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 constant NEW_FEE = 300;
    uint256 constant STARTING_BALANCE = TOTAL_SUPPLY / 100;
    uint256 constant SEND_TOKENS = STARTING_BALANCE / 10;

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
            _;
        }
    }

    modifier fundedWithETH(address account) {
        // fund user with native coin
        vm.deal(account, 10 ether);

        _;
    }

    modifier fundedWithWBNB(address account) {
        // fund user with bnb
        vm.startPrank(WBNB_FUNDER);
        IERC20(WBNB).transfer(account, 10 ether);
        vm.stopPrank();

        _;
    }

    modifier fundedWithTokens(address account) {
        // fund user with tokens
        vm.startPrank(token.owner());
        token.transfer(account, STARTING_BALANCE);
        vm.stopPrank();
        _;
    }

    modifier withLP() {
        vm.deal(token.owner(), 100 ether);

        uint256 lpSupply = 800_000_000 * 10 ** 18;

        address routerAddress = token.getRouterV2Address();
        IUniswapV2Router02 uniswaprouter = IUniswapV2Router02(routerAddress);

        vm.startPrank(token.owner());

        token.approve(routerAddress, lpSupply);

        (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        ) = IUniswapV2Router02(routerAddress).addLiquidityETH{value: 10 ether}(
                address(token),
                lpSupply,
                0,
                0,
                token.owner(),
                block.timestamp
            );
        vm.stopPrank();

        // console.log(amountToken);
        // console.log(amountETH);
        // console.log(liquidity);

        _;
    }

    function setUp() external virtual {
        deployment = new DeployFlamelingToken();
        token = deployment.run();
    }

    function toDecimals(
        uint256 number,
        uint256 decimals
    ) public pure returns (string memory floatNumber) {
        string memory integer = vm.toString(number / 10 ** decimals);
        string memory floates = vm.toString(number % 10 ** decimals);
        string memory point = ".";
        floatNumber = string(abi.encodePacked(integer, point, floates));
    }

    function sellTokens(address account, uint256 amount) public {
        address routerAddress = token.getRouterV2Address();
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = router.WETH();

        vm.startPrank(account);
        token.approve(routerAddress, amount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            account,
            block.timestamp
        );
        vm.stopPrank();
    }

    function buyTokens(address account, uint256 amount) public {
        address routerAddress = token.getRouterV2Address();
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(token);

        uint256 ethAmount = router.getAmountsIn(amount, path)[0];

        vm.startPrank(account);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: ethAmount
        }(0, path, account, block.timestamp);
        vm.stopPrank();
    }
}
