// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DividendShares} from "../../src/DividendShares.sol";

contract TestDividendShares is Test {
    using DividendShares for DividendShares.Map;

    DividendShares.Map private map;

    function test__Unit__DividendShares() public {
        map.setAccount(address(0), 0);
        map.setAccount(address(1), 100);
        map.setAccount(address(2), 200); // insert
        map.setAccount(address(2), 200); // update
        map.setAccount(address(3), 300);

        for (uint256 i = 0; i < map.getNumberOfAccounts(); i++) {
            address key = map.getAccountAtIndex(i);
            assert(map.sharesOf(key) == i * 100);
        }

        map.removeAccount(address(1));

        // accounts = [address(0), address(3), address(2)]
        assert(map.getNumberOfAccounts() == 3);
        assert(map.getAccountAtIndex(0) == address(0));
        assert(map.getAccountAtIndex(1) == address(3));
        assert(map.getAccountAtIndex(2) == address(2));
        assert(map.getTotalShares() == 500);
    }

    function test__Unit__DividendPayoutDecimals() public {

        uint256 amount = 123452342123 * 10 ** 18;
        map.setAccount(address(1), 100);
        map.setAccount(address(2), 200);
        map.setAccount(address(3), 300);

        map.distributeDividends(amount);

        map.setAccount(address(1), amount);
        map.setAccount(address(2), amount);
        map.setAccount(address(3), amount);

        map.setAccount(address(1), 100);
        map.setAccount(address(2), 200);
        map.setAccount(address(3), 300);

        map.distributeDividends(amount);

        map.setAccount(address(1), 100);
        map.setAccount(address(2), 200);
        map.setAccount(address(3), 300);

        console.log(map.dividendsOf(address(1)));
        console.log(map.dividendsOf(address(2)));
        console.log(map.dividendsOf(address(3)));

        map.distributeDividends(amount);

        map.removeAccount(address(1));
        map.removeAccount(address(2));
        map.removeAccount(address(3));

        console.log(map.dividendsOf(address(1)));
        console.log(map.dividendsOf(address(2)));
        console.log(map.dividendsOf(address(3)));


        assertEq((map.dividendsOf(address(1)) + map.dividendsOf(address(2)) + map.dividendsOf(address(3))) , 3 * amount);

    }

    function test__Unit__DividendPayout() public {

        map.setAccount(address(1), 100);
        map.setAccount(address(2), 200);
        map.setAccount(address(3), 300);
        map.setAccount(address(4), 400);

        map.distributeDividends(1000);
        
        map.setAccount(address(1), 400);
        map.setAccount(address(2), 300);
        map.setAccount(address(3), 200);
        map.setAccount(address(4), 100);

        map.distributeDividends(1000);

        map.removeAccount(address(1));
        map.removeAccount(address(2));
        map.removeAccount(address(3));
        map.removeAccount(address(4));

        assert(map.dividendsOf(address(1)) == 500);
        assert(map.dividendsOf(address(2)) == 500);
        assert(map.dividendsOf(address(3)) == 500);
        assert(map.dividendsOf(address(4)) == 500);

    }


    function test__Fuzz__SetDividendAccount(uint256 amount) public {
        map.setAccount(msg.sender, amount);
        assert(map.sharesOf(msg.sender) == amount);
    }

    function test__Fuzz__DividendPayout(uint256 shares1, uint256 shares2, uint256 shares3, uint256 dividends) public {

        shares1 = bound(shares1, 1, 1_000_000_000 ether);
        shares2 = bound(shares2, 1, 1_000_000_000 ether);
        shares3 = bound(shares3, 1, 1_000_000_000 ether);
        dividends = bound(dividends, 1, 1_000_000_000 ether);

        map.setAccount(address(1), shares1);
        map.setAccount(address(2), shares2);
        map.setAccount(address(3), shares3);

        map.distributeDividends(dividends);
        
        map.setAccount(address(1), 300);
        map.setAccount(address(2), 300);
        map.setAccount(address(3), 300);

        uint256 divisibleAmount = 5000 * 10 ** 18;
        map.distributeDividends(divisibleAmount);

        map.removeAccount(address(1));
        map.removeAccount(address(2));
        map.removeAccount(address(3));

        assertApproxEqAbs((map.dividendsOf(address(1)) + map.dividendsOf(address(2)) + map.dividendsOf(address(3))) , dividends + divisibleAmount, 3);
    }

}
