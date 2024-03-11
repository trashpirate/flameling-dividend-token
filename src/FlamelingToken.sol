// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// import {console} from "forge-std/Test.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/// @title FlamelingToken token
/// @author Nadina Oates
/// @notice Contract implementing ERC20 token that pays out dividend rewards from transaction fee
contract FlamelingToken is ERC20, Ownable {
    /**
     * Types
     */
    struct DividendAccounts {
        address[] accounts;
        mapping(address => uint256) dividendsPerTokenCredited;
        mapping(address => uint256) shares;
        mapping(address => uint256) dividends;
        mapping(address => uint256) indexOf;
        mapping(address => bool) inserted;
    }

    /**
     * State Variables
     */
    uint256 constant MIN_THRESHOLD = 50_000 * 10 ** 18;
    uint256 constant PRECISION = 2 ** 64;

    IUniswapV2Router02 private s_routerV2;
    address private s_pairV2;

    DividendAccounts private s_dividendAccounts;
    uint256 private s_totalDividends;
    uint256 private s_dividendsPerToken;
    uint256 private s_totalShares;
    uint256 private s_dividendRemainder;
    uint256 private s_minSharesRequired = 100_000 * 10 ** 18;
    address[] private s_accountsExcludedFromDividends;

    IERC20 private s_dividendToken;
    uint256 private s_baseFee = 200;
    uint256 private s_dividendFee = 200;

    uint256 private s_baseFeesPending;
    uint256 private s_dividendFeesPending;
    uint256 private s_swapThreshold = 100_000 * 10 ** 18;

    uint256 private s_claimInterval = 0;
    uint256 private s_lastProcessedIndex = 0;
    uint256 private s_gasForProcessing = 300_000;
    address private s_baseFeeAddress;

    bool private s_swapping;

    mapping(address => bool) private s_ammPairs;
    mapping(address => bool) private s_isExcludedFromFees;
    mapping(address => bool) private s_isExcludedFromDividends;
    mapping(address => uint256) private s_lastClaimTime;

    /**
     * Events
     */
    event BaseFeeAddressUpdated(address indexed sender, address baseFeeAddress);
    event DividendTokenUpdated(address indexed sender, address dividendToken);
    event BaseFeeUpdated(address indexed sender, uint256 baseFee);
    event DividendFeeUpdated(address indexed sender, uint256 dividendFee);
    event ExcludedFromFees(address indexed account, bool isExcluded);
    event ExcludedFromDividends(address indexed account, bool isExcluded);
    event SwapThresholdUpdated(address indexed sender, uint256 swapThreshold);
    event DividendsDistributed(uint256 indexed amount);
    event ClaimedDividends(address indexed recipient, uint256 amount);
    event GasForProcessingUpdated(address indexed sender, uint256 gas);
    event AMMPairUpdated(address indexed ammpair, bool value);

    /**
     * Errors
     */
    error FlamelingToken__SwapThresholdTooSmall();
    error FlamelingToken__SendingBaseFeeFailed(address receiver, bytes data);
    error FlamelingToken__NoDividendsToClaim();
    error FlamelingToken__NotDividendEligible();
    error FlamelingToken__AMMPairAlreadySet();
    error DividendShares__InvalidIndex(
        uint256 requestedIndex,
        uint256 numberOfIndices
    );

    /**
     * Modifiers
     */

    /**
     * Functions
     */

    /// @notice Constructor
    /// @param initialOwner ownerhip is transfered to this address after creation
    /// @dev inherits from Openzeppelin ERC20 and Ownable
    constructor(
        address initialOwner,
        address baseFeeAddress,
        address dividendToken,
        address routerV2
    ) ERC20("FlamelingToken", "0x77") Ownable(msg.sender) {
        s_baseFeeAddress = baseFeeAddress;
        s_dividendToken = IERC20(dividendToken);
        s_routerV2 = IUniswapV2Router02(routerV2);
        s_pairV2 = IUniswapV2Factory(s_routerV2.factory()).createPair(
            address(this),
            s_routerV2.WETH()
        );
        updateAMMPair(s_pairV2, true);

        excludeFromFees(address(this), true);
        excludeFromFees(initialOwner, true);
        excludeFromFees(baseFeeAddress, true);
        excludeFromDividends(address(this), true);
        excludeFromDividends(initialOwner, true);
        excludeFromDividends(s_pairV2, true);

        // exclude dead address?

        _mint(initialOwner, 1_000_000_000 * 10 ** decimals());
        transferOwnership(initialOwner);
    }

    receive() external payable {}

    /// @notice Sets fee address
    /// @param baseFeeAddress fee address for operations fee
    function updateFeeAddress(address baseFeeAddress) external onlyOwner {
        s_baseFeeAddress = baseFeeAddress;
        emit BaseFeeAddressUpdated(msg.sender, baseFeeAddress);
    }

    /// @notice Sets rewards token
    /// @param dividendToken token rewarded to holders
    function updateDividendToken(address dividendToken) external onlyOwner {
        s_dividendToken = IERC20(dividendToken);
        emit DividendTokenUpdated(msg.sender, dividendToken);
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

    /// @notice Sets gas for processing dividends
    /// @param gas amount
    function updateGasForProcessing(uint256 gas) external onlyOwner {
        s_gasForProcessing = gas;
        emit GasForProcessingUpdated(msg.sender, gas);
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

    /// @notice Exludes/includes address from dividends
    /// @param account address to be excluded or included
    /// @param isExcluded flag for excluded (true) and includes (false)
    function excludeFromDividends(
        address account,
        bool isExcluded
    ) public onlyOwner {
        s_isExcludedFromDividends[account] = isExcluded;
        _updateDividends(account);
        if (isExcluded) {
            _removeDividendAccount(account);
        } else {
            _updateDividendAccount(account, balanceOf(account));
        }
        emit ExcludedFromDividends(account, isExcluded);
    }

    /// @notice Sets AMM Pairs
    /// @param pair pair address
    /// @param value flag if traded pair
    function updateAMMPair(address pair, bool value) public onlyOwner {
        if (s_ammPairs[pair] == value)
            revert FlamelingToken__AMMPairAlreadySet();
        s_ammPairs[pair] = value;
        excludeFromDividends(pair, true);
        emit AMMPairUpdated(pair, value);
    }

    /** PRIVATE FUNCTIONS */

    function _numberOfDividendAccounts() private view returns (uint256) {
        return s_dividendAccounts.accounts.length;
    }

    /// @notice Gets account (address) at specific index
    /// @param index Index of entry with the account
    function _dividendAccountAtIndex(
        uint256 index
    ) private view returns (address) {
        if (index >= _numberOfDividendAccounts()) {
            revert DividendShares__InvalidIndex(
                index,
                _numberOfDividendAccounts()
            );
        }
        return s_dividendAccounts.accounts[index];
    }

    /// @notice Updates dividend balance
    /// @param account address of account
    function _updateDividends(address account) private {
        uint256 owed = s_dividendsPerToken -
            s_dividendAccounts.dividendsPerTokenCredited[account];
        s_dividendAccounts.dividends[account] +=
            s_dividendAccounts.shares[account] *
            owed;
        s_dividendAccounts.dividendsPerTokenCredited[
            account
        ] = s_dividendsPerToken;
    }

    /// @notice Removes entry from map
    /// @param account Associated address of entry to be removed
    function _removeDividendAccount(address account) private {
        if (!s_dividendAccounts.inserted[account]) {
            return;
        }

        s_totalShares -= s_dividendAccounts.shares[account];
        delete s_dividendAccounts.inserted[account];
        delete s_dividendAccounts.shares[account];

        uint256 index = s_dividendAccounts.indexOf[account];
        address lastAccount = s_dividendAccounts.accounts[
            _numberOfDividendAccounts() - 1
        ];

        s_dividendAccounts.indexOf[lastAccount] = index;
        delete s_dividendAccounts.indexOf[account];

        s_dividendAccounts.accounts[index] = lastAccount;
        s_dividendAccounts.accounts.pop();
    }

    /// @notice Updates dividend account
    /// @param account Associated address of entry
    /// @param balance Value associated with address
    function _updateDividendAccount(address account, uint256 balance) private {
        if (
            balance >= s_minSharesRequired &&
            !s_isExcludedFromDividends[account]
        ) {
            if (s_dividendAccounts.inserted[account]) {
                uint256 currentShares = s_dividendAccounts.shares[account];
                s_totalShares = s_totalShares + balance - currentShares;
                s_dividendAccounts.shares[account] = balance;
            } else {
                s_dividendAccounts.inserted[account] = true;
                s_dividendAccounts.shares[account] = balance;
                s_dividendAccounts.indexOf[
                    account
                ] = _numberOfDividendAccounts();
                s_dividendAccounts.accounts.push(account);
                s_totalShares += balance;
            }
        } else {
            if (s_dividendAccounts.inserted[account]) {
                _removeDividendAccount(account);
            } else {
                return;
            }
        }
    }

    /// @notice Distributes dividend fee to shares based on
    /// @param amount Collected dividend fee
    function _distributeDividends(uint256 amount) private {
        s_totalDividends += amount;
        if (s_totalShares > 0) {
            uint256 available = (amount * PRECISION) + s_dividendRemainder;
            s_dividendsPerToken += available / s_totalShares;
            s_dividendRemainder = available % s_totalShares;
            emit DividendsDistributed(amount);
        }
    }

    function _processDividends(uint256 gasAllowed) private returns (bool) {
        uint256 lastProcessedIndex = s_lastProcessedIndex;
        if (_numberOfDividendAccounts() == 0) {
            return false;
        }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        uint256 iterations = 0;
        while (
            gasUsed < gasAllowed && iterations < _numberOfDividendAccounts()
        ) {
            if (lastProcessedIndex >= _numberOfDividendAccounts()) {
                lastProcessedIndex = 0;
            }

            address account = _dividendAccountAtIndex(lastProcessedIndex);
            if (
                (block.timestamp - s_lastClaimTime[account]) >= s_claimInterval
            ) {
                _withdrawDividends(account);
            }

            iterations++;
            lastProcessedIndex++;

            gasUsed = gasUsed + gasLeft - gasleft();
            gasLeft = gasleft();
        }

        s_lastProcessedIndex = lastProcessedIndex;
        return true;
    }

    /// @notice Claims claimable dividends for specified account
    /// @dev Account gets percentage share: totalDividends * accountBalance / totalBalance - claimedDividends - buffer (buffer to avoid rounding errors)
    /// @param account address
    function _withdrawDividends(address account) private returns (bool) {
        _updateDividends(account);

        // calculate withrdrawable dividend amount
        uint256 dividendAmount = s_dividendAccounts.dividends[account] /
            PRECISION;

        // transfer dividends to account
        if (
            dividendAmount > 0 &&
            dividendAmount <= s_dividendToken.balanceOf(address(this))
        ) {
            try s_dividendToken.transfer(account, dividendAmount) {
                s_dividendAccounts.dividends[msg.sender] %= PRECISION;
                emit ClaimedDividends(account, dividendAmount);
            } catch {
                revert();
                // return false;
            }
        } else {
            return false;
        }
        return true;
    }

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
            _processDividends(s_gasForProcessing);
        }
    }

    /// @notice Claims dividends manually for calling account
    function withdrawDividends() external {
        if (!s_dividendAccounts.inserted[msg.sender]) {
            revert FlamelingToken__NotDividendEligible();
        }
        bool success = _withdrawDividends(msg.sender);
        if (!success) revert FlamelingToken__NoDividendsToClaim();
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

    /// @notice Gets reward token address
    function getDividendToken() external view returns (address) {
        return address(s_dividendToken);
    }

    /// @notice Gets fee address
    function getFeeAddress() external view returns (address) {
        return s_baseFeeAddress;
    }

    /// @notice Returns whether address is excluded from fee
    function getExcludedFromFee(address account) external view returns (bool) {
        return s_isExcludedFromFees[account];
    }

    /// @notice Returns whether address is excluded from dividends
    function getExcludedFromDividends(
        address account
    ) external view returns (bool) {
        return s_isExcludedFromDividends[account];
    }

    /// @notice Returns total fees pending
    function getFeesPending() public view returns (uint256) {
        return balanceOf(address(this));
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

    /// @notice Returns minimum shares required for receiving dividends
    function getMinSharesRequired() external view returns (uint256) {
        return s_minSharesRequired;
    }

    /// @notice Returns number of token holders
    function getNumberOfDividendAccounts() external view returns (uint256) {
        return _numberOfDividendAccounts();
    }

    /// @notice Returns total accumulated dividends
    function getTotalDividends() external view returns (uint256) {
        return s_totalDividends;
    }

    /// @notice Returns dividends of account
    /// @param account address
    function getSharesOf(address account) external view returns (uint256) {
        return s_dividendAccounts.shares[account];
    }

    /// @notice Returns dividends of account
    /// @param index index of dividend holder
    function getDividendAccountAtIndex(
        uint256 index
    ) external view returns (address) {
        return _dividendAccountAtIndex(index);
    }

    /// @notice Returns gas for processing dividends
    function getGasForProcessing() external view returns (uint256) {
        return s_gasForProcessing;
    }

    /// @notice Returns last processed index
    function getLastProcessedIndex() external view returns (uint256) {
        return s_lastProcessedIndex;
    }

    /// @notice Returns total shares
    function getTotalShares() external view returns (uint256) {
        return s_totalShares;
    }

    /// @notice Returns remaining dividends
    function getRemainingDividends() external view returns (uint256) {
        return s_dividendRemainder / PRECISION;
    }
}
