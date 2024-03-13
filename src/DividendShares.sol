// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title DividendShares
/// @author Nadina Oates
/// @notice Contract implementing dividend share logic for ERC20 token
contract DividendShares is Ownable {
    /** TYPES */
    struct DividendAccounts {
        address[] accounts;
        mapping(address => uint256) dividendsPerTokenCredited;
        mapping(address => uint256) shares;
        mapping(address => uint256) dividends;
        mapping(address => uint256) indexOf;
        mapping(address => bool) inserted;
    }

    /** CONSTANTS */
    uint256 constant PRECISION = 2 ** 64;

    /** STATE VARIABLES */
    IERC20 internal s_dividendToken;

    DividendAccounts private s_dividendAccounts;
    uint256 private s_totalDividends;
    uint256 private s_dividendsPerToken;
    uint256 private s_totalShares;
    uint256 private s_dividendRemainder;
    uint256 private s_minSharesRequired = 100_000 * 10 ** 18;
    mapping(address => bool) private s_isExcludedFromDividends;

    uint256 private s_lastIndexProcessed = 0;
    uint256 private s_gasForProcessing = 300_000;

    /** EVENTS */
    event DividendTokenUpdated(address indexed sender, address dividendToken);
    event DividendsDistributed(uint256 indexed amount);
    event DividendsWithdrawn(address indexed recipient, uint256 amount);
    event GasForProcessingUpdated(address indexed sender, uint256 gas);
    event MinSharesRequiredUpdated(address indexed sender, uint256 minRequired);
    event ExcludedFromDividends(address indexed account, bool isExcluded);

    /** ERRORS */
    error DividendShares__InvalidIndex(uint256 index, uint256 numOfIndices);
    error DividendShares__NoDividendsToClaim();
    error DividendShares__NotDividendEligible();

    /// @notice Constructor
    /// @param initialOwner ownerhip is transfered to this address after creation
    /// @param dividendToken token to be distributed in dividends
    /// @dev inherits from Openzeppelin Ownable
    constructor(
        address initialOwner,
        address dividendToken
    ) Ownable(initialOwner) {
        s_dividendToken = IERC20(dividendToken);
    }

    /** EXTERNAL FUNCTIONS */
    /// @notice Claims dividends manually for calling account
    function withdrawDividends() external {
        if (!s_dividendAccounts.inserted[msg.sender]) {
            revert DividendShares__NotDividendEligible();
        }
        bool success = _withdrawDividends(msg.sender);
        if (!success) revert DividendShares__NoDividendsToClaim();
    }

    /** Setter Functions */

    /// @notice Sets dividend rewards token
    /// @param dividendToken token rewarded to holders
    function updateDividendToken(address dividendToken) external onlyOwner {
        s_dividendToken = IERC20(dividendToken);
        emit DividendTokenUpdated(msg.sender, dividendToken);
    }

    /// @notice Sets gas for processing dividends
    /// @param gas amount
    function updateGasForProcessing(uint256 gas) external onlyOwner {
        s_gasForProcessing = gas;
        emit GasForProcessingUpdated(msg.sender, gas);
    }

    /// @notice Sets minimum shares required to receive dividends
    /// @param minShares amount
    function updateMinSharesRequired(uint256 minShares) external onlyOwner {
        s_minSharesRequired = minShares;
        emit MinSharesRequiredUpdated(msg.sender, minShares);
    }

    /** Getter Functions */

    /// @notice Gets reward token address
    function getDividendToken() external view returns (address) {
        return address(s_dividendToken);
    }

    /// @notice Returns minimum shares required for receiving dividends
    function getMinSharesRequired() external view returns (uint256) {
        return s_minSharesRequired;
    }

    /// @notice Returns number of token holders
    function getNumberOfDividendAccounts() external view returns (uint256) {
        return s_dividendAccounts.accounts.length;
    }

    /// @notice Returns total accumulated dividends
    function getTotalDividends() external view returns (uint256) {
        return s_totalDividends;
    }

    /// @notice Returns dividend sahres of account
    /// @param account address
    function getSharesOf(address account) external view returns (uint256) {
        return s_dividendAccounts.shares[account];
    }

    /// @notice Returns dividend account at index
    /// @param index index of dividend holder
    function getDividendAccountAtIndex(
        uint256 index
    ) external view returns (address) {
        if (index >= s_dividendAccounts.accounts.length) {
            revert DividendShares__InvalidIndex(
                index,
                s_dividendAccounts.accounts.length
            );
        }
        return s_dividendAccounts.accounts[index];
    }

    /// @notice Returns whether address is excluded from dividends
    function getExcludedFromDividends(
        address account
    ) external view returns (bool) {
        return s_isExcludedFromDividends[account];
    }

    /// @notice Returns gas for processing dividends
    function getGasForProcessing() external view returns (uint256) {
        return s_gasForProcessing;
    }

    /// @notice Returns last processed index
    function getLastIndexProcessed() external view returns (uint256) {
        return s_lastIndexProcessed;
    }

    /// @notice Returns total shares
    function getTotalShares() external view returns (uint256) {
        return s_totalShares;
    }

    /// @notice Returns remaining dividends
    function getRemainingDividends() external view returns (uint256) {
        return s_dividendRemainder / PRECISION;
    }

    /** PUBLIC FUNCTIONS */
    /// @notice Exludes/includes address from dividends
    /// @param account address to be excluded
    function excludeFromDividends(address account) public onlyOwner {
        s_isExcludedFromDividends[account] = true;
        _updateDividends(account);
        _removeDividendAccount(account);
        emit ExcludedFromDividends(account, true);
    }

    /// @notice Exludes/includes address from dividends
    /// @param account address to be included
    /// @param balance current token shares
    function includeInDividends(
        address account,
        uint256 balance
    ) public onlyOwner {
        s_isExcludedFromDividends[account] = false;
        _updateDividends(account);
        _updateDividendAccount(account, balance);
        emit ExcludedFromDividends(account, false);
    }

    /** INTERNAL FUNCTIONS */
    /// @notice Updates dividend balance
    /// @param account address of account
    function _updateDividends(address account) internal {
        uint256 dividendsPerToken = s_dividendsPerToken;
        unchecked {
            s_dividendAccounts.dividends[account] +=
                s_dividendAccounts.shares[account] *
                (dividendsPerToken -
                    s_dividendAccounts.dividendsPerTokenCredited[account]);
        }

        s_dividendAccounts.dividendsPerTokenCredited[
            account
        ] = dividendsPerToken;
    }

    /// @notice Distributes dividend fee to shares
    /// @param amount Collected dividend fee
    function _distributeDividends(uint256 amount) internal virtual {
        s_totalDividends += amount;
        uint256 totalShares = s_totalShares;
        if (totalShares > 0) {
            uint256 available = (amount * PRECISION) + s_dividendRemainder;
            s_dividendsPerToken += available / totalShares;
            unchecked {
                s_dividendRemainder = available % totalShares;
            }
            emit DividendsDistributed(amount);
        }
    }

    /// @notice Processes all dividend accounts
    function _processDividends() internal returns (bool) {
        uint256 gasAllowed = s_gasForProcessing;
        uint256 numberOfAccounts = s_dividendAccounts.accounts.length;

        if (numberOfAccounts == 0) {
            return false;
        }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        uint256 iterations = 0;
        while (gasUsed < gasAllowed && iterations < numberOfAccounts) {
            unchecked {
                iterations++;
                s_lastIndexProcessed++;
            }

            if (s_lastIndexProcessed >= numberOfAccounts) {
                s_lastIndexProcessed = 0;
            }

            address account = s_dividendAccounts.accounts[s_lastIndexProcessed];
            _withdrawDividends(account);

            unchecked {
                gasUsed = gasUsed + gasLeft - gasleft();
            }

            gasLeft = gasleft();
        }

        return true;
    }

    /// @notice Updates dividend account
    /// @param account Associated address of entry
    /// @param balance Value associated with address
    function _updateDividendAccount(address account, uint256 balance) internal {
        if (
            balance >= s_minSharesRequired &&
            !s_isExcludedFromDividends[account]
        ) {
            if (s_dividendAccounts.inserted[account]) {
                s_totalShares =
                    s_totalShares +
                    balance -
                    s_dividendAccounts.shares[account];
                s_dividendAccounts.shares[account] = balance;
            } else {
                s_dividendAccounts.inserted[account] = true;
                s_dividendAccounts.shares[account] = balance;
                s_dividendAccounts.indexOf[account] = s_dividendAccounts
                    .accounts
                    .length;
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

    /** PRIVATE FUNCTIONS */
    /// @notice Removes entry from dividend accounts map
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
            s_dividendAccounts.accounts.length - 1
        ];

        s_dividendAccounts.indexOf[lastAccount] = index;
        delete s_dividendAccounts.indexOf[account];

        s_dividendAccounts.accounts[index] = lastAccount;
        s_dividendAccounts.accounts.pop();
    }

    /// @notice Withdraws dividends for specified account
    /// @dev Account gets dividends based on percentage share
    /// @param account address
    function _withdrawDividends(address account) private returns (bool) {
        _updateDividends(account);

        // calculate withrdrawable dividend amount
        uint256 dividends = s_dividendAccounts.dividends[account];
        uint256 dividendAmount = dividends / PRECISION;

        // transfer dividends to account
        if (dividendAmount > 0) {
            unchecked {
                s_dividendAccounts.dividends[account] =
                    dividends -
                    (dividendAmount * PRECISION);
            }

            try s_dividendToken.transfer(account, dividendAmount) returns (
                bool success
            ) {
                if (success) {
                    emit DividendsWithdrawn(account, dividendAmount);
                } else {
                    s_dividendAccounts.dividends[account] = dividends;
                    return false;
                }
            } catch {
                s_dividendAccounts.dividends[account] = dividends;
                return false;
            }
        } else {
            return false;
        }
        return true;
    }
}
