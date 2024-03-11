// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {console} from "forge-std/Script.sol";

/// @title Iterable Mapping
/// @author
/// @dev iterable mapping derived from https://solidity-by-example.org
library DividendShares {
    // Iterable mapping from address to uint256;
    struct Map {
        uint256 totalShares;
        uint256 totalDividends;
        uint256 dividendsPerToken;
        uint256 remainder;
        address[] accounts;
        mapping(address => uint256) dividendsPerTokenCredited;
        mapping(address => uint256) shares;
        mapping(address => uint256) dividends;
        mapping(address => uint256) credit;
        mapping(address => uint256) indexOf;
        mapping(address => bool) inserted;
    }

    /** constants */
    uint256 constant PRECISION = 2 ** 64;

    /** errors */
    error DividendShares__InvalidIndex(uint256 requestedIndex, uint256 numberOfIndices);

    /** EXTERNAL FUNCTIONS */

    /// @notice Updates dividends per share
    /// @param map Iterable Map to be updated
    /// @param amount Dividend amount 
    function distributeDividends(Map storage map, uint256 amount) external {
        map.totalDividends += amount;
        uint256 available = (amount * PRECISION) + map.remainder;
        if (map.totalShares > 0) {
            map.dividendsPerToken += available / map.totalShares;
            map.remainder = available % map.totalShares;
            console.log("total remainder: ", map.remainder);
            // emit DividendsDistributed(amount);
        }
        
    }
    
    /// @notice Sets entry in map
    /// @param map Iterable Map to be updated
    /// @param account Associated address of entry
    /// @param balance Value associated with address
    function setAccount(Map storage map, address account, uint256 balance) external {

        if (map.inserted[account]) {
            _updateDividends(map, account);
            uint256 currentShares = map.shares[account];
            if (currentShares != balance) {
                map.totalShares = map.totalShares + balance - currentShares;
                map.shares[account] = balance;
            } else {
                return;
            }
        } else {
            map.inserted[account] = true;
            map.shares[account] = balance;
            map.indexOf[account] = map.accounts.length;
            map.accounts.push(account);
            map.totalShares += balance;
        }
    }

    /// @notice Removes entry from map
    /// @param map Iterable Map to be updated
    /// @param account Associated address of entry to be removed
    function removeAccount(Map storage map, address account) external {
        if (!map.inserted[account]) {
            return;
        }

        _updateDividends(map, account);

        map.totalShares -= map.shares[account];
        delete map.inserted[account];
        delete map.shares[account];

        uint256 index = map.indexOf[account];
        address lastKey = map.accounts[map.accounts.length - 1];

        map.indexOf[lastKey] = index;
        delete map.indexOf[account];

        map.accounts[index] = lastKey;
        map.accounts.pop();
    }
       
    /// @notice Gets the balance at specific address
    /// @param map Iterable Map
    /// @param account Address associated with entry
    function sharesOf(Map storage map, address account) external view returns (uint256) {
        return map.shares[account];
    }
    
    /// @notice Gets the dividends at specific address
    /// @param map Iterable Map
    /// @param account Address associated with entry
    function dividendsOf(Map storage map, address account) external returns (uint256) {
        _updateDividends(map, account);
        uint256 amount =  map.dividends[account] / PRECISION;
        map.dividends[msg.sender] %= PRECISION;
        // console.log("remainder: ", map.dividends[msg.sender]);
        return amount;
    }

    /// @notice Returns whether address is part of map
    /// @param map Iterable Map
    /// @param account Address
    function hasShares(Map storage map, address account) external view returns (bool) {
        return map.inserted[account];
    }

    /// @notice Gets total shares
    /// @param map Iterable Map
    function getTotalShares(Map storage map) external view returns (uint256) {
        return map.totalShares;
    }

    /// @notice Gets account (address) at specific index
    /// @param map Iterable Map
    /// @param index Index of entry with the account
    function getAccountAtIndex(Map storage map, uint256 index) external view returns (address) {
        if (index >= getNumberOfAccounts(map)) {
            revert DividendShares__InvalidIndex(index, getNumberOfAccounts(map));
        }
        return map.accounts[index];
    }
    
    /// @notice Gets remaining undestributed dividends
    /// @param map Iterable Map
    function getRemainingDividends(Map storage map) external view returns (uint256) {
        
        return map.remainder;
    }

    /** PUBLIC FUNCTIONS */  

    /// @notice Gets number of dividends accounts
    /// @param map Iterable Map
    function getNumberOfAccounts(Map storage map) public view returns (uint256) {
        return map.accounts.length;
    }

    /** PRIVATE FUNCTIONS */

    /// @notice Updates dividend balance
    /// @param map Iterable Map to be updated
    /// @param account address of account
    function _updateDividends(Map storage map, address account) private {
        uint256 owed = map.dividendsPerToken - map.dividendsPerTokenCredited[account];
        map.dividends[account] += map.shares[account] * owed;
        map.dividendsPerTokenCredited[account] = map.dividendsPerToken;
    }


}
