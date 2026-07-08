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

pragma solidity ^0.6.12;

// FIXME: This contract was altered compared to the production version.
// It doesn't use LibNote anymore.
// New deployments of this contract will need to include custom events (TO DO).

contract Dai {
    /*//////////////////////////////////////////////////////////////
                                  AUTH
    //////////////////////////////////////////////////////////////*/

    mapping(address => uint256) public wards;

    function rely(address guy) external auth {
        wards[guy] = 1;
    }

    function deny(address guy) external auth {
        wards[guy] = 0;
    }
    modifier auth() {
        require(wards[msg.sender] == 1, "Dai/not-authorized");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 DATA
    //////////////////////////////////////////////////////////////*/

    string public constant name = "Dai Stablecoin";
    string public constant symbol = "DAI";
    string public constant version = "1";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public nonces;

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);

     /*//////////////////////////////////////////////////////////////
                                  MATH
    //////////////////////////////////////////////////////////////*/

    // Arithmetic Addition helper Function
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    // Arithmetic Subtraction Helper Function
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    /*//////////////////////////////////////////////////////////////
                            EIP712 NICETIES
    //////////////////////////////////////////////////////////////*/

    bytes32 public DOMAIN_SEPARATOR;
    // bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)");
    bytes32 public constant PERMIT_TYPEHASH = 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(uint256 chainId_) public {
        wards[msg.sender] = 1;   // makes the deloyer an admin
        DOMAIN_SEPARATOR = keccak256(   // creates the token's unique cryptrographic identitiy
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId_,
                address(this)
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 TOKEN
    //////////////////////////////////////////////////////////////*/

    /**
    * @dev Transfers DAI to destination address with amount
    * @param dst The destination address receiving DAI
    * @param wad The amount of DAI to transfer
    */
    function transfer(address dst, uint256 wad) external returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    /**
    * @dev Transfers DAI from source address to destination address with amount
    * @param src The source address sending DAI
    * @param dst The destination address receiving DAI
    * @param wad The amount of DAI to transfer
    */
    function transferFrom(address src, address dst, uint256 wad) public returns (bool) {
        require(balanceOf[src] >= wad, "Dai/insufficient-balance");
        if (src != msg.sender && allowance[src][msg.sender] != uint256(-1)) {
            require(allowance[src][msg.sender] >= wad, "Dai/insufficient-allowance");
            allowance[src][msg.sender] = sub(allowance[src][msg.sender], wad);
        }
        balanceOf[src] = sub(balanceOf[src], wad);
        balanceOf[dst] = add(balanceOf[dst], wad);
        emit Transfer(src, dst, wad);
        return true;
    }

    /**
    * @dev Mints new DAI tokens and assigns them to the specified address
    * @param usr The address to assign the new tokens to
    * @param wad The amount of DAI to mint
    */
    function mint(address usr, uint256 wad) external auth {
        balanceOf[usr] = add(balanceOf[usr], wad);
        totalSupply = add(totalSupply, wad);
        emit Transfer(address(0), usr, wad);
    }

    /**
    * @dev Burns already minted DAI in supply out of circulation when Debt is paid
    * @param usr The address burning the Dai
    * @param wad The amount of DAI being burned
    */
    function burn(address usr, uint256 wad) external {
        require(balanceOf[usr] >= wad, "Dai/insufficient-balance");
        if (usr != msg.sender && allowance[usr][msg.sender] != uint256(-1)) {
            require(allowance[usr][msg.sender] >= wad, "Dai/insufficient-allowance");
            allowance[usr][msg.sender] = sub(allowance[usr][msg.sender], wad);
        }
        balanceOf[usr] = sub(balanceOf[usr], wad);
        totalSupply = sub(totalSupply, wad);
        emit Transfer(usr, address(0), wad);
    }

    /**
    * @dev Gives approval to an address for using a certain amount of DAI
    * @param usr The address being approved
    * @param wad The amount of DAI approved
    */
    function approve(address usr, uint256 wad) external returns (bool) {
        allowance[msg.sender][usr] = wad;
        emit Approval(msg.sender, usr, wad);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                                 ALIAS
    //////////////////////////////////////////////////////////////*/

    // subtracts DAI from administrator address to destinated address
    function push(address usr, uint256 wad) external {
        transferFrom(msg.sender, usr, wad);
    }

    // adds DAI from external address to administrator address
    function pull(address usr, uint256 wad) external {
        transferFrom(usr, msg.sender, wad);
    }

    // transfers DAI from src address to dst address
    function move(address src, address dst, uint256 wad) external {
        transferFrom(src, dst, wad);
    }


    /*//////////////////////////////////////////////////////////////
                          APPROVE BY SIGNATURE
    //////////////////////////////////////////////////////////////*/
    
    /** 
    * @dev provides a gasless methodology for granting approval for DAI transfer
    * @param holder the address DAI is being transfered from
    * @param spender the address allowed to permited to spend DAI from holder
    * @param nonce unique number only once tagged to each transaction
    * @param expiry time frame permission will lasts
    * @param allowed returns true || false if spender is approved by holder 
     */
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
        bytes32 digest = keccak256(     // EIP-712 standard for building the exact message Alice should have signed
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, holder, spender, nonce, expiry, allowed))
            )
        );

        require(holder != address(0), "Dai/invalid-address-0");
        require(holder == ecrecover(digest, v, r, s), "Dai/invalid-permit");
        require(expiry == 0 || now <= expiry, "Dai/permit-expired");
        require(nonce == nonces[holder]++, "Dai/invalid-nonce");
        uint256 wad = allowed ? uint256(-1) : 0;
        allowance[holder][spender] = wad;
        emit Approval(holder, spender, wad);
    }
}
