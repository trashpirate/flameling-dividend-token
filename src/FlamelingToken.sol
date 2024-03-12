// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// import {console} from "forge-std/Test.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DividendShares} from "./DividendShares.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/// @title FlamelingToken token
/// @author Nadina Oates
/// @notice Contract implementing ERC20 token that pays out dividend rewards from transaction fee
contract FlamelingToken is ERC20, DividendShares {
    /**
     * State Variables
     */
    uint256 constant MIN_THRESHOLD = 50_000 * 10 ** 18;

    IUniswapV2Router02 private s_routerV2;
    address private s_pairV2;

    uint256 private s_baseFee = 200;
    uint256 private s_dividendFee = 200;

    uint256 private s_baseFeesPending;
    uint256 private s_dividendFeesPending;
    uint256 private s_swapThreshold = 100_000 * 10 ** 18;

    address private s_baseFeeAddress;

    bool private s_swapping;

    mapping(address => bool) private s_ammPairs;
    mapping(address => bool) private s_isExcludedFromFees;

    /**
     * Events
     */
    event BaseFeeAddressUpdated(address indexed sender, address baseFeeAddress);

    event BaseFeeUpdated(address indexed sender, uint256 baseFee);
    event DividendFeeUpdated(address indexed sender, uint256 dividendFee);
    event ExcludedFromFees(address indexed account, bool isExcluded);

    event SwapThresholdUpdated(address indexed sender, uint256 swapThreshold);
    event AMMPairUpdated(address indexed ammpair, bool value);

    /**
     * Errors
     */
    error FlamelingToken__SwapThresholdTooSmall();
    error FlamelingToken__SendingBaseFeeFailed(address receiver, bytes data);
    error FlamelingToken__AMMPairAlreadySet();

    /**
     * Functions
     */

    /// @notice Constructor
    /// @param initialOwner ownerhip is transfered to this address after creation
    /// @dev inherits from Openzeppelin ERC20 and Ownable
    constructor(
        string memory name,
        string memory symbol,
        address initialOwner,
        address baseFeeAddress,
        address dividendToken,
        address routerV2
    ) ERC20(name, symbol) DividendShares(msg.sender, dividendToken) {
        s_baseFeeAddress = baseFeeAddress;

        s_routerV2 = IUniswapV2Router02(routerV2);
        s_pairV2 = IUniswapV2Factory(s_routerV2.factory()).createPair(
            address(this),
            s_routerV2.WETH()
        );
        updateAMMPair(s_pairV2, true);

        excludeFromFees(address(this), true);
        excludeFromFees(initialOwner, true);
        excludeFromFees(baseFeeAddress, true);
        excludeFromDividends(address(this));
        excludeFromDividends(initialOwner);
        excludeFromDividends(s_pairV2);

        // exclude dead address?

        _mint(initialOwner, 1_000_000_000 * 10 ** decimals());
        transferOwnership(initialOwner);
    }

    /// @notice Sets fee address
    /// @param baseFeeAddress fee address for operations fee
    function updateFeeAddress(address baseFeeAddress) external onlyOwner {
        s_baseFeeAddress = baseFeeAddress;
        emit BaseFeeAddressUpdated(msg.sender, baseFeeAddress);
    }

    /// @notice Sets operations fee: 100 == 1%
    /// @param baseFee fee collected for operations
    function updateBaseFee(uint256 baseFee) external onlyOwner {
        s_baseFee = baseFee;
        emit BaseFeeUpdated(msg.sender, baseFee);
    }

    /// @notice Sets rewards fee: 100 == 1%
    /// @param dividendFee fee going back to holders
    function updateDividendFee(uint256 dividendFee) external onlyOwner {
        s_dividendFee = dividendFee;
        emit DividendFeeUpdated(msg.sender, dividendFee);
    }

    /// @notice Sets swap treshold for collected fees
    /// @param swapThreshold new swap threshold
    function updateSwapThreshold(uint256 swapThreshold) external onlyOwner {
        if (swapThreshold < MIN_THRESHOLD) {
            revert FlamelingToken__SwapThresholdTooSmall();
        }

        s_swapThreshold = swapThreshold;
        emit SwapThresholdUpdated(msg.sender, swapThreshold);
    }

    /// @notice Exludes/includes address from fee
    /// @param account address to be excluded or included
    /// @param isExcluded flag for excluded (true) and includes (false)
    function excludeFromFees(
        address account,
        bool isExcluded
    ) public onlyOwner {
        s_isExcludedFromFees[account] = isExcluded;

        emit ExcludedFromFees(account, isExcluded);
    }

    /// @notice Sets AMM Pairs
    /// @param pair pair address
    /// @param value flag if traded pair
    function updateAMMPair(address pair, bool value) public onlyOwner {
        if (s_ammPairs[pair] == value)
            revert FlamelingToken__AMMPairAlreadySet();
        s_ammPairs[pair] = value;
        excludeFromDividends(pair);
        emit AMMPairUpdated(pair, value);
    }

    /** PRIVATE FUNCTIONS */

    function _swapTokenForDividendToken(
        uint256 amount
    ) internal returns (bool success) {
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = s_routerV2.WETH();
        path[2] = address(s_dividendToken);

        _approve(address(this), address(s_routerV2), amount);

        try
            s_routerV2.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amount,
                0,
                path,
                address(this),
                block.timestamp
            )
        {
            success = true;
        } catch {
            success = false;
        }
    }

    function _swapAndSendBaseFee(
        uint256 feeAmount,
        address feeAccount
    ) internal returns (bool success) {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = s_routerV2.WETH();

        _approve(address(this), address(s_routerV2), feeAmount);
        try
            s_routerV2.swapExactTokensForETHSupportingFeeOnTransferTokens(
                feeAmount,
                0,
                path,
                feeAccount,
                block.timestamp
            )
        {
            success = true;
        } catch {
            success = false;
        }
    }

    /// @notice Takes fee and transfers tokens
    /// @param from sender address
    /// @param to receiver address
    /// @param amount token amount
    /// @dev updates transfer function of openzepplin library
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        _updateDividends(from);
        _updateDividends(to);

        if (
            balanceOf(address(this)) >= s_swapThreshold &&
            !s_swapping &&
            !s_ammPairs[from]
        ) {
            s_swapping = true;
            if (s_baseFeesPending > 0) {
                bool success = _swapAndSendBaseFee(
                    s_baseFeesPending,
                    s_baseFeeAddress
                );
                if (success) {
                    s_baseFeesPending = 0;
                }
            }

            if (s_dividendFeesPending > 0) {
                uint256 currentBalance = s_dividendToken.balanceOf(
                    address(this)
                );
                bool success = _swapTokenForDividendToken(
                    s_dividendFeesPending
                );
                if (success) {
                    uint256 newDividends = s_dividendToken.balanceOf(
                        address(this)
                    ) - currentBalance;
                    _distributeDividends(newDividends);
                    s_dividendFeesPending = 0;
                }
            }
            s_swapping = false;
        }

        uint256 transferAmount = amount;
        if (
            !s_isExcludedFromFees[from] &&
            !s_isExcludedFromFees[to] &&
            (s_ammPairs[from] || s_ammPairs[to]) &&
            !s_swapping
        ) {
            uint256 baseFee = (amount * s_baseFee) / 10000;
            uint256 dividendFee = (amount * s_dividendFee) / 10000;
            uint256 totalFees = baseFee + dividendFee;

            transferAmount = amount - baseFee - dividendFee;

            s_baseFeesPending += baseFee;
            s_dividendFeesPending += dividendFee;

            super._update(from, address(this), totalFees);
        }

        super._update(from, to, transferAmount);

        _updateDividendAccount(from, balanceOf(from));
        _updateDividendAccount(to, balanceOf(to));

        if (!s_swapping) {
            _processDividends();
        }
    }

    /**
     * Getter Functions
     */

    /// @notice Gets operations fee
    function getBaseFee() external view returns (uint256) {
        return s_baseFee;
    }

    /// @notice Gets rewards fee
    function getDividendFee() external view returns (uint256) {
        return s_dividendFee;
    }

    /// @notice Gets total transaction fee
    function getTotalTransactionFee() external view returns (uint256) {
        uint256 totalFees = s_baseFee + s_dividendFee;
        return totalFees;
    }

    /// @notice Gets fee address
    function getFeeAddress() external view returns (address) {
        return s_baseFeeAddress;
    }

    /// @notice Returns whether address is excluded from fee
    function isExcludedFromFee(address account) external view returns (bool) {
        return s_isExcludedFromFees[account];
    }

    /// @notice Returns base fees pending
    function getBaseFeesPending() public view returns (uint256) {
        return s_baseFeesPending;
    }

    /// @notice Returns rewards pending
    function getDividendFeesPending() public view returns (uint256) {
        return s_dividendFeesPending;
    }

    /// @notice Returns dex router
    function getRouterV2Address() public view returns (address) {
        return address(s_routerV2);
    }

    /// @notice Returns lp pair address
    function getPairV2Address() public view returns (address) {
        return s_pairV2;
    }

    /// @notice Returns whether amm pair is included or not
    function getAMMPair(address pair) public view returns (bool) {
        return s_ammPairs[pair];
    }

    /// @notice Returns swap treshold in ERC20 token amount
    function getSwapThreshold() public view returns (uint256) {
        return s_swapThreshold;
    }
}
