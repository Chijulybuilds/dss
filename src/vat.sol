// SPDX-License-Identifier: AGPL-3.0-or-later

/// vat.sol -- Dai CDP database

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.6.12;

// FIXME: This contract was altered compared to the production version.
// It doesn't use LibNote anymore.
// New deployments of this contract will need to include custom events (TO DO).

contract Vat {
    // --- Auth ---
    mapping(address => uint256) public wards;

    // called when governance agree to add a contract to the protocol
    function rely(address usr) external auth {
        require(live == 1, "Vat/not-live");
        wards[usr] = 1;
    }

    // called when a governance decide to remove or retire a contract from the protocol
    function deny(address usr) external auth {
        require(live == 1, "Vat/not-live");
        wards[usr] = 0;
    }
    // checks if the address is an authorized protocol contract
    modifier auth() {
        require(wards[msg.sender] == 1, "Vat/not-authorized");
        _;
    }

    mapping(address => mapping(address => uint256)) public can;

    // allows another address to manipulate vault or balances
    function hope(address usr) external {
        can[msg.sender][usr] = 1;
    }

    // revokes permissions granted by the hope() function
    function nope(address usr) external {
        can[msg.sender][usr] = 0;
    }

    // checks if bit has approved usr
    function wish(address bit, address usr) internal view returns (bool) {
        return either(bit == usr, can[bit][usr] == 1);
    }

    /*//////////////////////////////////////////////////////////////
                                  DATA
    //////////////////////////////////////////////////////////////*/

    struct Ilk {
        uint256 Art; // Total Normalised Debt     [wad]
        uint256 rate; // Accumulated Rates         [ray]
        uint256 spot; // Price with Safety Margin  [ray]
        uint256 line; // Debt Ceiling              [rad]
        uint256 dust; // Urn Debt Floor            [rad]
    }

    struct Urn {
        uint256 ink; // Locked Collateral  [wad]
        uint256 art; // Normalised Debt    [wad]
    }

    mapping(bytes32 => Ilk) public ilks;
    mapping(bytes32 => mapping(address => Urn)) public urns;
    mapping(bytes32 => mapping(address => uint256)) public gem; // [wad]
    mapping(address => uint256) public dai; // [rad]
    mapping(address => uint256) public sin; // [rad]

    uint256 public debt; // Total Dai Issued    [rad]
    uint256 public vice; // Total Unbacked Dai  [rad]
    uint256 public Line; // Total Debt Ceiling  [rad]
    uint256 public live; // Active Flag

     /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    constructor() public {
        wards[msg.sender] = 1;
        live = 1;
    }

    /*//////////////////////////////////////////////////////////////
                                  MATH
    //////////////////////////////////////////////////////////////*/

    function _add(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = x + uint256(y);
        require(y >= 0 || z <= x);
        require(y <= 0 || z >= x);
    }

    function _sub(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = x - uint256(y);
        require(y <= 0 || z <= x);
        require(y >= 0 || z >= x);
    }

    function _mul(uint256 x, int256 y) internal pure returns (int256 z) {
        z = int256(x) * y;
        require(int256(x) >= 0);
        require(y == 0 || z / y == int256(x));
    }

    function _add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    function _sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    function _mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    /*//////////////////////////////////////////////////////////////
                             ADMINISTRATION
    //////////////////////////////////////////////////////////////*/

    // creates a new collateral type before governance adds it to the Protocol
    function init(bytes32 ilk) external auth {
        require(ilks[ilk].rate == 0, "Vat/ilk-already-init");
        ilks[ilk].rate = 10 ** 27;
    }

    // changes system parameters and limits total DAI that can ever exist
    function file(bytes32 what, uint256 data) external auth {
        require(live == 1, "Vat/not-live");
        if (what == "Line") Line = data;
        else revert("Vat/file-unrecognized-param");
    }

    // changes settings for one collateral which can modify maximum borrowing power
    function file(bytes32 ilk, bytes32 what, uint256 data) external auth {
        require(live == 1, "Vat/not-live");
        if (what == "spot") ilks[ilk].spot = data;
        else if (what == "line") ilks[ilk].line = data; // debt ceiling for this collateral type
        else if (what == "dust") ilks[ilk].dust = data; // minimum vault debt for this collateral type
        else revert("Vat/file-unrecognized-param");
    }

    // called in cases of emergency shutdown
    function cage() external auth {
        live = 0;
    }

    /*//////////////////////////////////////////////////////////////
                              FUNGIBILITY
    //////////////////////////////////////////////////////////////*/

    // changes someone's internal collateral balance called by GemJoin
    function slip(bytes32 ilk, address usr, int256 wad) external auth {
        gem[ilk][usr] = _add(gem[ilk][usr], wad);
    }

    // Transfers collateral internally between users
    function flux(bytes32 ilk, address src, address dst, uint256 wad) external {
        require(wish(src, msg.sender), "Vat/not-allowed");
        gem[ilk][src] = _sub(gem[ilk][src], wad);
        gem[ilk][dst] = _add(gem[ilk][dst], wad);
    }

    // Transfers DAI from one user to another internally
    function move(address src, address dst, uint256 rad) external {
        require(wish(src, msg.sender), "Vat/not-allowed");
        dai[src] = _sub(dai[src], rad);
        dai[dst] = _add(dai[dst], rad);
    }

    // the OR logical operator
    function either(bool x, bool y) internal pure returns (bool z) {
        assembly { z := or(x, y) }
    }

    // the AND logical operator
    function both(bool x, bool y) internal pure returns (bool z) {
        assembly { z := and(x, y) }
    }

    /*//////////////////////////////////////////////////////////////
                            CDP MANIPULATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifies a CDP by adjusting its collateral and debt positions
     * @dev The main function where
     *  deposit col., withdrawal col., borrow DAI, and repay DAI occurs
     * @param i The ilk of the CDP
     * @param u The owner of the CDP
     * @param v The source address for collateral transfer
     * @param w The destination address for DAI transfer
     * @param dink The amount of collateral to add/subtract
     * @param dart The amount of debt to add/subtract
     */

    function frob(bytes32 i, address u, address v, address w, int256 dink, int256 dart) external {
        // system is live
        require(live == 1, "Vat/not-live");

        Urn memory urn = urns[i][u];
        Ilk memory ilk = ilks[i];
        // ilk has been initialised
        require(ilk.rate != 0, "Vat/ilk-not-init");

        urn.ink = _add(urn.ink, dink); // deposit collateral to already locked one
        urn.art = _add(urn.art, dart); // deposit debt(DAI) to already locked one
        ilk.Art = _add(ilk.Art, dart); // deposit debt(DAI) to Normalised Overall Debt

        int256 dtab = _mul(ilk.rate, dart);
        uint256 tab = _mul(ilk.rate, urn.art);
        debt = _add(debt, dtab);

        // either debt has decreased, or debt ceilings are not exceeded
        require(either(dart <= 0, both(_mul(ilk.Art, ilk.rate) <= ilk.line, debt <= Line)), "Vat/ceiling-exceeded");
        // urn is either less risky than before, or it is safe
        require(either(both(dart <= 0, dink >= 0), tab <= _mul(urn.ink, ilk.spot)), "Vat/not-safe");

        // urn is either more safe, or the owner consents
        require(either(both(dart <= 0, dink >= 0), wish(u, msg.sender)), "Vat/not-allowed-u");
        // collateral src consents
        require(either(dink <= 0, wish(v, msg.sender)), "Vat/not-allowed-v");
        // debt dst consents
        require(either(dart >= 0, wish(w, msg.sender)), "Vat/not-allowed-w");

        // urn has no debt, or a non-dusty amount
        require(either(urn.art == 0, tab >= ilk.dust), "Vat/dust");

        gem[i][v] = _sub(gem[i][v], dink);
        dai[w] = _add(dai[w], dtab);

        urns[i][u] = urn;
        ilks[i] = ilk;
    }

    /*//////////////////////////////////////////////////////////////
                             CDP FUNGIBILTY
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev used for spliting or transfering vaults
     * @param ilk The identifier for the type of collateral
     * @param src The address of the source vault
     * @param dst The address of the destination vault
     * @param dink The amount of collateral to transfer
     * @param dart The amount of debt to transfer
     */

    function fork(bytes32 ilk, address src, address dst, int256 dink, int256 dart) external {
        Urn storage u = urns[ilk][src];
        Urn storage v = urns[ilk][dst];
        Ilk storage i = ilks[ilk];

        u.ink = _sub(u.ink, dink);
        u.art = _sub(u.art, dart);
        v.ink = _add(v.ink, dink);
        v.art = _add(v.art, dart);

        uint256 utab = _mul(u.art, i.rate);
        uint256 vtab = _mul(v.art, i.rate);

        // both sides consent
        require(both(wish(src, msg.sender), wish(dst, msg.sender)), "Vat/not-allowed");

        // both sides safe
        require(utab <= _mul(u.ink, i.spot), "Vat/not-safe-src");
        require(vtab <= _mul(v.ink, i.spot), "Vat/not-safe-dst");

        // both sides non-dusty
        require(either(utab >= i.dust, u.art == 0), "Vat/dust-src");
        require(either(vtab >= i.dust, v.art == 0), "Vat/dust-dst");
    }

    /*//////////////////////////////////////////////////////////////
                            CDP CONFISCATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev used for confiscating collateral from a vault
     * @param i The identifier for the type of collateral
     * @param u The address of the source vault
     * @param v The address of the destination vault
     * @param w The address of the user
     * @param dink The amount of collateral to confiscate
     * @param dart The amount of debt to confiscate
     */

    function grab(bytes32 i, address u, address v, address w, int256 dink, int256 dart) external auth {
        Urn storage urn = urns[i][u];
        Ilk storage ilk = ilks[i];

        urn.ink = _add(urn.ink, dink);
        urn.art = _add(urn.art, dart);
        ilk.Art = _add(ilk.Art, dart);

        int256 dtab = _mul(ilk.rate, dart);

        gem[i][v] = _sub(gem[i][v], dink);
        sin[w] = _sub(sin[w], dtab);
        vice = _sub(vice, dtab);
    }

    /*//////////////////////////////////////////////////////////////
                               SETTLEMENT
    //////////////////////////////////////////////////////////////*/

    // Debt Cancellation
    function heal(uint256 rad) external {
        address u = msg.sender;
        sin[u] = _sub(sin[u], rad);
        dai[u] = _sub(dai[u], rad);
        vice = _sub(vice, rad);
        debt = _sub(debt, rad);
    }

    // Debt Accumulation
    function suck(address u, address v, uint256 rad) external auth {
        sin[u] = _add(sin[u], rad);
        dai[v] = _add(dai[v], rad);
        vice = _add(vice, rad);
        debt = _add(debt, rad);
    }

    /*//////////////////////////////////////////////////////////////
                                 RATES
    //////////////////////////////////////////////////////////////*/

    // Automatically updates all vaults on current stability fee rate without iteration
    function fold(bytes32 i, address u, int256 rate) external auth {
        require(live == 1, "Vat/not-live");
        Ilk storage ilk = ilks[i];
        ilk.rate = _add(ilk.rate, rate);
        int256 rad = _mul(ilk.Art, rate);
        dai[u] = _add(dai[u], rad);
        debt = _add(debt, rad);
    }
}
