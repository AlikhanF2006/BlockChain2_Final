// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {PositionNFT} from "../../src/tokens/PositionNFT.sol";

contract PositionNFTTest is Test {
    PositionNFT internal nft;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal minter = makeAddr("minter");

    function setUp() public {
        nft = new PositionNFT("ipfs://positions/");
    }

    function test_MintPosition() public {
        uint256 tokenId = nft.mintPosition(alice);

        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.nextTokenId(), 2);
    }

    function test_MintOnlyAuthorized() public {
        vm.prank(minter);
        vm.expectRevert();
        nft.mintPosition(alice);

        uint256 tokenId = nft.mintPosition(alice);
        assertEq(nft.ownerOf(tokenId), alice);
    }

    function test_BurnByOwner() public {
        uint256 tokenId = nft.mintPosition(alice);

        vm.prank(alice);
        nft.burn(tokenId);

        assertEq(nft.balanceOf(alice), 0);
        vm.expectRevert();
        nft.ownerOf(tokenId);
    }

    function test_BurnRevertIfNotOwnerOrApproved() public {
        uint256 tokenId = nft.mintPosition(alice);

        vm.prank(bob);
        vm.expectRevert();
        nft.burn(tokenId);

        assertEq(nft.ownerOf(tokenId), alice);
    }

    function test_SetBaseURI() public {
        nft.setBaseURI("https://example.com/positions/");

        uint256 tokenId = nft.mintPosition(alice);
        assertEq(nft.tokenURI(tokenId), "https://example.com/positions/1");
    }

    function test_TokenURI() public {
        uint256 tokenId = nft.mintPosition(alice);

        assertEq(nft.tokenURI(tokenId), "ipfs://positions/1");
    }

    function test_TransferPositionNFT() public {
        uint256 tokenId = nft.mintPosition(alice);

        vm.prank(alice);
        nft.transferFrom(alice, bob, tokenId);

        assertEq(nft.ownerOf(tokenId), bob);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);
    }

    function testFuzz_MintToAddress(address user) public {
        vm.assume(user != address(0));
        vm.assume(user.code.length == 0);

        uint256 tokenId = nft.mintPosition(user);

        assertEq(nft.ownerOf(tokenId), user);
        assertEq(nft.balanceOf(user), 1);
    }
}
