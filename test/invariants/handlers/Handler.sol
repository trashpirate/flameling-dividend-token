// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {FlamelingToken} from "../../../src/FlamelingToken.sol";
import {ERC20Token} from "../../../mock/ERC20Token.sol";

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

struct AddressSet {
    address[] addrs;
    mapping(address => bool) saved;
}

library LibAddressSet {
    function rand(
        AddressSet storage s,
        uint256 seed
    ) internal view returns (address) {
        if (s.addrs.length > 0) {
            return s.addrs[seed % s.addrs.length];
        } else {
            return address(0xc0ffee);
        }
    }

    function add(AddressSet storage s, address addr) internal {
        if (!s.saved[addr]) {
            s.addrs.push(addr);
            s.saved[addr] = true;
        }
    }

    function contains(
        AddressSet storage s,
        address addr
    ) internal view returns (bool) {
        return s.saved[addr];
    }

    function count(AddressSet storage s) internal view returns (uint256) {
        return s.addrs.length;
    }

    function getAddressAtIndex(
        AddressSet storage s,
        uint256 index
    ) public view returns (address) {
        return s.addrs[index];
    }
}

contract Handler is CommonBase, StdCheats, StdUtils, Test {
    using LibAddressSet for AddressSet;

    AddressSet internal _actors;
    address internal currentActor;

    FlamelingToken public token;
    ERC20Token public dividendToken;

    mapping(bytes32 => uint256) public calls;

    mapping(address => bool) public hasShares;
    mapping(address => uint256) public startingBalance;

    uint256 public ghost_noStateChangeForSellTokens;
    uint256 public ghost_noStateChangeForBuyTokens;
    uint256 public ghost_transferZeroTokens;
    uint256 public ghost_transferFromZeroTokens;
    uint256 public ghost_numberOfDividendAccounts;
    uint256 public ghost_totalDividendShares;

    IUniswapV2Router02 router;

    error GiveETHFailed(address sender, address receiver, uint256 amount);

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    modifier noAutoDividends() {
        address owner = token.owner();
        vm.prank(owner);
        token.updateGasForProcessing(0);
        _;
    }

    modifier createActor() {
        currentActor = msg.sender;
        _actors.add(msg.sender);
        _;
    }

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = _actors.rand(actorIndexSeed);
        _;
    }

    function checkIfShares(address account) public {
        hasShares[account] =
            token.balanceOf(account) >= token.getMinSharesRequired();
        if (hasShares[account]) {
            startingBalance[account] = token.balanceOf(account);
        }
    }

    function countAccounts(address account) public {
        if (hasShares[account]) {
            if (token.balanceOf(account) < token.getMinSharesRequired()) {
                ghost_numberOfDividendAccounts--;
                ghost_totalDividendShares -= startingBalance[account];
                hasShares[account] = false;
            } else {
                ghost_totalDividendShares =
                    ghost_totalDividendShares -
                    startingBalance[account] +
                    token.balanceOf(account);
            }
        }
        if (
            !hasShares[account] &&
            token.balanceOf(account) >= token.getMinSharesRequired()
        ) {
            ghost_numberOfDividendAccounts++;
            ghost_totalDividendShares += token.balanceOf(account);
            hasShares[account] = true;
        }
    }

    function _giveETH(address account, uint256 amount) internal {
        (bool success, ) = payable(account).call{value: amount}("");
        if (!success) {
            console.log("Contract balance: ", address(this).balance);
            revert GiveETHFailed(address(this), account, amount);
        }
    }

    function actorCount() external view returns (uint256) {
        return _actors.count();
    }

    function actorAtIndex(uint256 index) external view returns (address) {
        return _actors.getAddressAtIndex(index);
    }

    constructor(FlamelingToken _token) {
        token = _token;
        dividendToken = ERC20Token(token.getDividendToken());

        address routerAddress = token.getRouterV2Address();
        router = IUniswapV2Router02(routerAddress);

        deal(address(this), 5000 ether);

        address owner = token.owner();
        uint256 balance = token.balanceOf(owner);
        vm.prank(owner);
        token.transfer(address(this), balance);
    }

    receive() external payable {}

    fallback() external payable {}

    function buyTokens(
        uint256 amount
    ) public createActor countCall("buyTokens") {
        amount = bound(amount, 0, address(this).balance);

        checkIfShares(currentActor);
        deal(currentActor, amount);

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(token);

        vm.startPrank(currentActor);
        try
            router.swapExactETHForTokensSupportingFeeOnTransferTokens{
                value: amount
            }(0, path, payable(currentActor), block.timestamp)
        {
            console.log("swap succeeded: ", token.balanceOf(currentActor));
        } catch {
            console.log("swap failed: ", currentActor.balance);
            ghost_noStateChangeForBuyTokens++;
        }
        vm.stopPrank();
        countAccounts(currentActor);
    }

    function sellTokens(
        uint256 actorSeed,
        uint256 amount
    ) public useActor(actorSeed) countCall("sellTokens") {
        amount = bound(amount, 0, token.balanceOf(currentActor));

        checkIfShares(currentActor);

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = router.WETH();

        vm.startPrank(currentActor);
        token.approve(address(router), amount);
        try
            router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                amount,
                0,
                path,
                currentActor,
                block.timestamp
            )
        {} catch {
            ghost_noStateChangeForSellTokens++;
        }
        vm.stopPrank();
        countAccounts(currentActor);
    }

    function transferTokens(
        uint256 actorSeed,
        uint256 receiverSeed,
        uint256 amount
    ) public useActor(actorSeed) countCall("transferTokens") {
        _actors.add(msg.sender);
        address receiver = _actors.rand(receiverSeed);
        amount = bound(amount, 0, token.balanceOf(currentActor));

        checkIfShares(currentActor);
        checkIfShares(receiver);

        if (amount == 0) {
            ghost_transferZeroTokens++;
        }

        vm.prank(currentActor);
        token.transfer(receiver, amount);

        countAccounts(currentActor);
        countAccounts(receiver);
    }

    function approveTokens(
        uint256 actorSeed,
        uint256 spenderSeed,
        uint256 amount
    ) public useActor(actorSeed) countCall("approveTokens") {
        address spender = _actors.rand(spenderSeed);

        vm.prank(currentActor);
        token.approve(spender, amount);
    }

    function transferFromTokens(
        uint256 actorSeed,
        uint256 fromSeed,
        uint256 toSeed,
        uint256 amount,
        bool _approve
    ) public useActor(actorSeed) countCall("transferFromTokens") {
        address from = _actors.rand(fromSeed);
        address to = _actors.rand(toSeed);

        checkIfShares(from);
        checkIfShares(to);

        amount = bound(amount, 0, token.balanceOf(from));

        if (_approve) {
            vm.prank(from);
            token.approve(currentActor, amount);
        } else {
            amount = bound(amount, 0, token.allowance(from, currentActor));
        }

        if (amount == 0) {
            ghost_transferFromZeroTokens++;
        }

        vm.prank(currentActor);
        token.transferFrom(from, to, amount);
        countAccounts(from);
        countAccounts(to);
    }

    function callSummary() external view {
        console.log("\nCall summary:");
        console.log("-------------------");
        console.log("sellTokens", calls["sellTokens"]);
        console.log("buyTokens", calls["buyTokens"]);
        console.log("transferTokens", calls["transferTokens"]);
        console.log("approveTokens", calls["approveTokens"]);
        console.log("transferFromTokens", calls["transferFromTokens"]);

        console.log("-------------------");
        console.log(
            "sellToken without state changes: ",
            ghost_noStateChangeForSellTokens
        );
        console.log(
            "buyToken without state changes: ",
            ghost_noStateChangeForBuyTokens
        );
        console.log(
            "transferToken without state changes: ",
            ghost_transferZeroTokens
        );
        console.log(
            "transferFromToken without state changes: ",
            ghost_transferFromZeroTokens
        );
    }
}

// claimTokens
