// SPDX-License-Identifier: AGPL-3.0-or-later

/// dai.sol -- Dai Stablecoin ERC-20 Token

// Copyright (C) 2017, 2018, 2019 dbrock, rain, mrchico

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

pragma solidity ^0.8.0;

// FIXME: This contract was altered compared to the production version.
// It doesn't use LibNote anymore.
// New deployments of this contract will need to include custom events (TO DO).

/**
 * @title DAI_Contract
 * @author MakerDAO
 * @notice This contract was altered compared to the production version.
 * It doesn't use LibNote anymore.
 * New deployments of this contract will need to include custom events (TO DO).
 * @dev This contract upgrades compile version making for Gas Optimization
 */

contract Dai {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Dai__InsufficientBalance();
    error Dai__InsufficientAllowance();
    error Dai__InvalidAddress();
    error Dai__InvalidPermit();
    error Dai__PermitExpired();
    error Dai__InvalidNonce();
    error Dai__DaiNotAuthorized();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    string private constant name = "Dai Stablecoin";
    string private constant symbol = "DAI";
    string private constant version = "1";
    uint8 private constant decimals = 18;
    uint256 public totalSupply;
    uint256 internal constant MAX_UINT = type(uint256).max;

    /*//////////////////////////////////////////////////////////////
                            BYTES VARIABLES
    //////////////////////////////////////////////////////////////*/

    // --- EIP712 niceties ---
    bytes32 public DOMAIN_SEPARATOR;
    // bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)");
    bytes32 public constant PERMIT_TYPEHASH = 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 internal constant NAME_HASH = keccak256(abi.encodePacked(name));

    bytes32 internal constant VERSION_HASH = keccak256(abi.encodePacked(version));

    /*//////////////////////////////////////////////////////////////
                                MAPPINGS
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) public wards;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(uint256 chainId_) {
        wards[msg.sender] = 1;
        DOMAIN_SEPARATOR =
            keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, chainId_, address(this)));
    }
    /*//////////////////////////////////////////////////////////////
                                MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier auth() {
        if (wards[msg.sender] != 1) {
            revert Dai__DaiNotAuthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function rely(address guy) external auth {
        wards[guy] = 1;
    }

    function deny(address guy) external auth {
        wards[guy] = 0;
    }

    // --- Token ---
    function transfer(address dst, uint256 wad) external returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint256 wad) public returns (bool) {
        uint256 srcBalance = balanceOf[src];

        if (srcBalance < wad) {
            revert Dai__InsufficientBalance();
        }

        if (src != msg.sender) {
            uint256 allowed = allowance[src][msg.sender];

            if (allowed != MAX_UINT) {
                if (allowed < wad) {
                    revert Dai__InsufficientAllowance();
                }

                unchecked {
                    allowance[src][msg.sender] = allowed - wad;
                }
            }
        }

        uint256 dstBalance = balanceOf[dst];

        unchecked {
            balanceOf[src] = srcBalance - wad;
            balanceOf[dst] = dstBalance + wad;
        }

        emit Transfer(src, dst, wad);

        return true;
    }

    function mint(address usr, uint256 wad) external auth {
        balanceOf[usr] += wad;
        totalSupply += wad;

        emit Transfer(address(0), usr, wad);
    }

    function burn(address usr, uint256 wad) external {
        uint256 usrBalance = balanceOf[usr];

        if (usrBalance < wad) revert Dai__InsufficientBalance();

        if (usr != msg.sender) {
            uint256 allowed = allowance[usr][msg.sender];

            if (allowed != MAX_UINT) {
                if (allowed < wad) revert Dai__InsufficientAllowance();

                unchecked {
                    allowance[usr][msg.sender] = allowed - wad;
                }
            }
        }

        unchecked {
            balanceOf[usr] = usrBalance - wad;
            totalSupply -= wad;
        }

        emit Transfer(usr, address(0), wad);
    }

    function approve(address usr, uint256 wad) external returns (bool) {
        allowance[msg.sender][usr] = wad;
        emit Approval(msg.sender, usr, wad);
        return true;
    }

    // --- Alias ---
    function push(address usr, uint256 wad) external {
        transferFrom(msg.sender, usr, wad);
    }

    function pull(address usr, uint256 wad) external {
        transferFrom(usr, msg.sender, wad);
    }

    function move(address src, address dst, uint256 wad) external {
        transferFrom(src, dst, wad);
    }

    // --- Approve by signature ---
    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, holder, spender, nonce, expiry, allowed))
            )
        );
        if (holder == address(0)) {
            revert Dai__InvalidAddress();
        }
        if (holder != ecrecover(digest, v, r, s)) {
            revert Dai__InvalidPermit();
        }
        if (expiry != 0 && block.timestamp > expiry) {
            revert Dai__PermitExpired();
        }
        if (nonce != nonces[holder]++) {
            revert Dai__InvalidNonce();
        }
        uint256 wad = allowed ? MAX_UINT : 0;
        allowance[holder][spender] = wad;
        emit Approval(holder, spender, wad);
    }
}
