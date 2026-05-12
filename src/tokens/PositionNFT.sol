// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title Position NFT
/// @notice ERC721 receipt for user positions in the DeFi Super-App.
contract PositionNFT is ERC721, Ownable {
    event PositionMinted(address indexed to, uint256 indexed tokenId);
    event PositionBurned(uint256 indexed tokenId);
    event BaseURIUpdated(string newBaseURI);

    uint256 public nextTokenId = 1;
    string private _positionBaseURI;

    constructor(string memory initialBaseURI) ERC721("DeFi Position NFT", "DPN") Ownable(msg.sender) {
        _positionBaseURI = initialBaseURI;
    }

    function mintPosition(address to) external onlyOwner returns (uint256 tokenId) {
        tokenId = nextTokenId++;
        _safeMint(to, tokenId);
        emit PositionMinted(to, tokenId);
    }

    function burn(uint256 tokenId) external {
        address tokenOwner = _requireOwned(tokenId);
        _checkAuthorized(tokenOwner, msg.sender, tokenId);
        _burn(tokenId);
        emit PositionBurned(tokenId);
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _positionBaseURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return _positionBaseURI;
    }
}
