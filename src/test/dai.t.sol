// SPDX-License-Identifier: AGPL-3.0-or-later

/// dai.t.sol -- tests for dai.sol

// Copyright (C) 2015-2019  DappHub, LLC

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.0;

/**
 * @title DAITest
 * @dev Test contract for the DAI token
 * @dev Implemented vm.expectRevert() into Revert test functions via the standard Vm interface address
 */

import "ds-test/test.sol";

import "../dai.sol";

contract TokenUser {
    Dai token;

    uint256 internal constant MAX_UINT = type(uint256).max;

    constructor(Dai token_) {
        token = token_;
    }

    function doTransferFrom(address from, address to, uint256 amount) public returns (bool) {
        return token.transferFrom(from, to, amount);
    }

    function doTransfer(address to, uint256 amount) public returns (bool) {
        return token.transfer(to, amount);
    }

    function doApprove(address recipient, uint256 amount) public returns (bool) {
        return token.approve(recipient, amount);
    }

    function doAllowance(address owner, address spender) public view returns (uint256) {
        return token.allowance(owner, spender);
    }

    function doBalanceOf(address who) public view returns (uint256) {
        return token.balanceOf(who);
    }

    function doApprove(address guy) public returns (bool) {
        return token.approve(guy, MAX_UINT);
    }

    function doMint(uint256 wad) public {
        token.mint(address(this), wad);
    }

    function doBurn(uint256 wad) public {
        token.burn(address(this), wad);
    }

    function doMint(address guy, uint256 wad) public {
        token.mint(guy, wad);
    }

    function doBurn(address guy, uint256 wad) public {
        token.burn(guy, wad);
    }
}

/*//////////////////////////////////////////////////////////////
                           INTERFACE
//////////////////////////////////////////////////////////////*/
interface Hevm {
    function warp(uint256) external;
}

interface Vm {
    function expectRevert() external;
    function addr(uint256 privateKey) external returns (address);
    function sign(uint256 privateKey, bytes32 digest) external returns (uint8, bytes32, bytes32);
}

contract DaiTest is DSTest {
    uint256 constant initialBalanceThis = 1000;
    uint256 constant initialBalanceCal = 100;
    uint256 constant calKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80; // any nonzero test key
    uint256 internal constant MAX_UINT = type(uint256).max;
    uint256 constant delKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    address cal;
    address del;

    Dai token;
    Hevm hevm;
    Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address user1;
    address user2;
    address self;

    uint256 amount = 2;
    uint256 fee = 1;
    uint256 nonce = 0;
    uint256 deadline = 0;
    bytes32 r = 0x8e30095d9e5439a4f4b8e4b5c94e7639756474d72aded20611464c8f002efb06;
    bytes32 s = 0x49a0ed09658bc768d6548689bcbaa430cefa57846ef83cb685673a9b9a575ff4;
    uint8 v = 27;
    bytes32 _r = 0x85da10f8af2cf512620c07d800f8e17a2a4cd2e91bf0835a34bf470abc6b66e5;
    bytes32 _s = 0x7e8e641e5e8bef932c3a55e7365e0201196fc6385d942c47d749bf76e73ee46f;
    uint8 _v = 27;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D); ///////
        hevm.warp(604411200);
        cal = vm.addr(calKey);
        del = vm.addr(delKey);
        token = createToken();
        token.mint(address(this), initialBalanceThis);
        token.mint(cal, initialBalanceCal);
        user1 = address(new TokenUser(token));
        user2 = address(new TokenUser(token));
        self = address(this);
    }

    function createToken() internal returns (Dai) {
        return new Dai(99);
    }

    function testSetupPrecondition() public {
        assertEq(token.balanceOf(self), initialBalanceThis);
    }

    function testTransferCost() public logs_gas {
        assertTrue(token.transfer(address(0), 10));
    }

    function testAllowanceStartsAtZero() public logs_gas {
        assertEq(token.allowance(user1, user2), 0);
    }

    function testValidTransfers() public logs_gas {
        uint256 sentAmount = 250;
        emit log_named_address("token11111", address(token));
        assertTrue(token.transfer(user2, sentAmount));
        assertEq(token.balanceOf(user2), sentAmount);
        assertEq(token.balanceOf(self), initialBalanceThis - sentAmount);
    }

    function testRevertIfWrongAccountTransfers() public logs_gas {
        uint256 sentAmount = 250;
        vm.expectRevert();
        assertTrue(token.transferFrom(user2, self, sentAmount));
    }

    function testRevertInsufficientFundsTransfers() public logs_gas {
        uint256 sentAmount = 250;
        assertTrue(token.transfer(user1, initialBalanceThis - sentAmount));
        vm.expectRevert();
        assertTrue(token.transfer(user2, sentAmount + 1));
    }

    function testApproveSetsAllowance() public logs_gas {
        emit log_named_address("Test", self);
        emit log_named_address("Token", address(token));
        emit log_named_address("Me", self);
        emit log_named_address("User 2", user2);
        token.approve(user2, 25);
        assertEq(token.allowance(self, user2), 25);
    }

    function testChargesAmountApproved() public logs_gas {
        uint256 amountApproved = 20;
        token.approve(user2, amountApproved);
        assertTrue(TokenUser(user2).doTransferFrom(self, user2, amountApproved));
        assertEq(token.balanceOf(self), initialBalanceThis - amountApproved);
    }

    function testRevertTransferWithoutApproval() public logs_gas {
        assertTrue(token.transfer(user1, 50));
        vm.expectRevert();
        assertTrue(token.transferFrom(user1, self, 1));
    }

    function testRevertChargeMoreThanApproved() public logs_gas {
        assertTrue(token.transfer(user1, 50));
        TokenUser(user1).doApprove(self, 20);
        vm.expectRevert();
        assertTrue(token.transferFrom(user1, self, 21));
    }

    function testTransferFromSelf() public {
        assertTrue(token.transferFrom(self, user1, 50));
        assertEq(token.balanceOf(user1), 50);
    }

    function testRevertTransferFromSelfNonArbitrarySize() public {
        uint256 _amount = token.balanceOf(self) + 1;

        vm.expectRevert();
        assertTrue(token.transferFrom(self, self, _amount));
    }

    function testMintself() public {
        uint256 mintAmount = 10;
        token.mint(address(this), mintAmount);
        assertEq(token.balanceOf(self), initialBalanceThis + mintAmount);
    }

    function testMintGuy() public {
        uint256 mintAmount = 10;
        token.mint(user1, mintAmount);
        assertEq(token.balanceOf(user1), mintAmount);
    }

    function testRevertMintGuyNoAuth() public {
        vm.expectRevert();
        TokenUser(user1).doMint(user2, 10);
    }

    function testMintGuyAuth() public {
        token.rely(user1);
        TokenUser(user1).doMint(user2, 10);
    }

    function testBurn() public {
        uint256 burnAmount = 10;
        token.burn(address(this), burnAmount);
        assertEq(token.totalSupply(), initialBalanceThis + initialBalanceCal - burnAmount);
    }

    function testBurnself() public {
        uint256 burnAmount = 10;
        token.burn(address(this), burnAmount);
        assertEq(token.balanceOf(self), initialBalanceThis - burnAmount);
    }

    function testBurnGuyWithTrust() public {
        uint256 burnAmount = 10;
        assertTrue(token.transfer(user1, burnAmount));
        assertEq(token.balanceOf(user1), burnAmount);

        TokenUser(user1).doApprove(self);
        token.burn(user1, burnAmount);
        assertEq(token.balanceOf(user1), 0);
    }

    function testBurnAuth() public {
        assertTrue(token.transfer(user1, 10));
        token.rely(user1);
        TokenUser(user1).doBurn(10);
    }

    function testBurnGuyAuth() public {
        assertTrue(token.transfer(user2, 10));
        //        token.rely(user1);
        TokenUser(user2).doApprove(user1);
        TokenUser(user1).doBurn(user2, 10);
    }

    function testRevertUntrustedTransferFrom() public {
        assertEq(token.allowance(self, user2), 0);
        vm.expectRevert();
        TokenUser(user1).doTransferFrom(self, user2, 200);
    }

    function testTrusting() public {
        assertEq(token.allowance(self, user2), 0);
        token.approve(user2, MAX_UINT);
        assertEq(token.allowance(self, user2), MAX_UINT);
        token.approve(user2, 0);
        assertEq(token.allowance(self, user2), 0);
    }

    function testTrustedTransferFrom() public {
        token.approve(user1, MAX_UINT);
        TokenUser(user1).doTransferFrom(self, user2, 200);
        assertEq(token.balanceOf(user2), 200);
    }

    function testApproveWillModifyAllowance() public {
        assertEq(token.allowance(self, user1), 0);
        assertEq(token.balanceOf(user1), 0);
        token.approve(user1, 1000);
        assertEq(token.allowance(self, user1), 1000);
        TokenUser(user1).doTransferFrom(self, user1, 500);
        assertEq(token.balanceOf(user1), 500);
        assertEq(token.allowance(self, user1), 500);
    }

    function testApproveWillNotModifyAllowance() public {
        assertEq(token.allowance(self, user1), 0);
        assertEq(token.balanceOf(user1), 0);
        token.approve(user1, MAX_UINT);
        assertEq(token.allowance(self, user1), MAX_UINT);
        TokenUser(user1).doTransferFrom(self, user1, 1000);
        assertEq(token.balanceOf(user1), 1000);
        assertEq(token.allowance(self, user1), MAX_UINT);
    }

    function testDaiAddress() public {
        //The dai address generated by hevm
        //used for signature generation testing
        assertEq(address(token), address(0x11Ee1eeF5D446D07Cf26941C7F2B4B1Dfb9D030B));
    }

    function testTypehash() public {
        assertEq(token.PERMIT_TYPEHASH(), 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb);
    }

    function testDomain_Separator() public {
        assertEq(token.DOMAIN_SEPARATOR(), 0x68a9504c1a7fba795f7730732abab11cb5fa5113edd2396392abd5c1bbda4043);
    }

    function testPermit() public {
        assertEq(token.nonces(cal), 0);
        assertEq(token.allowance(cal, del), 0);

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(token.PERMIT_TYPEHASH(), cal, del, 0, 0, true))
            )
        );

        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(calKey, digest);
        token.permit(cal, del, 0, 0, true, sigV, sigR, sigS);

        assertEq(token.allowance(cal, del), MAX_UINT);
        assertEq(token.nonces(cal), 1);
    }

    function testRevertPermitAddress0() public {
        v = 0;
        vm.expectRevert();
        token.permit(address(0), del, 0, 0, true, v, r, s);
    }

    function testPermitWithExpiry() public {
        assertEq(block.timestamp, 604411200);

        uint256 expiry = block.timestamp + 1 hours;

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(token.PERMIT_TYPEHASH(), cal, del, 0, expiry, true))
            )
        );

        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(calKey, digest);

        token.permit(cal, del, 0, expiry, true, sigV, sigR, sigS);

        assertEq(token.allowance(cal, del), MAX_UINT);
        assertEq(token.nonces(cal), 1);
    }

    function testRevertPermitWithExpiry() public {
        hevm.warp(block.timestamp + 2 hours);
        assertEq(block.timestamp, 604411200 + 2 hours);
        vm.expectRevert();
        token.permit(cal, del, 0, 1, true, _v, _r, _s);
    }

    function testRevertReplay() public {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(token.PERMIT_TYPEHASH(), cal, del, 0, 0, true))
            )
        );

        (uint8 sigV, bytes32 sigR, bytes32 sigS) = vm.sign(calKey, digest);

        // First permit should succeed
        token.permit(cal, del, 0, 0, true, sigV, sigR, sigS);

        // Second permit with same signature should revert (nonce has incremented)
        vm.expectRevert();
        token.permit(cal, del, 0, 0, true, sigV, sigR, sigS);
    }
}
