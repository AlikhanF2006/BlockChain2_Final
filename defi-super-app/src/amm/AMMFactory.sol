// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {AMMPool} from "./AMMPool.sol";
import {LPToken} from "../tokens/LPToken.sol";

/// @title AMM Factory
/// @notice Deploys UUPS AMM pool proxies at deterministic CREATE2 addresses.
contract AMMFactory {
    error IdenticalAddresses();
    error ZeroAddress();
    error PairExists();

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 pairCount);

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // CEI: checks, effects, interactions.
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        if (getPair[token0][token1] != address(0)) revert PairExists();

        AMMPool implementation = new AMMPool();
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        pair = address(new ERC1967Proxy{salt: salt}(address(implementation), ""));

        LPToken lpToken = new LPToken(pair);
        AMMPool(pair).initialize(token0, token1, address(lpToken));

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function predictPairAddress(address tokenA, address tokenB) external view returns (address predicted) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        address predictedImplementation = _computeCreateAddress(address(this), 1 + allPairs.length * 2);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        bytes32 initCodeHash = keccak256(
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(predictedImplementation), bytes("")))
        );
        predicted = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, initCodeHash)))));
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) revert IdenticalAddresses();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
    }

    function _computeCreateAddress(address deployer, uint256 nonce) internal pure returns (address) {
        bytes memory data;
        if (nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(0x80));
        } else if (nonce <= 0x7f) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, uint8(nonce));
        } else if (nonce <= 0xff) {
            data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), deployer, bytes1(0x81), uint8(nonce));
        } else if (nonce <= 0xffff) {
            data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), deployer, bytes1(0x82), uint16(nonce));
        } else if (nonce <= 0xffffff) {
            data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), deployer, bytes1(0x83), uint24(nonce));
        } else {
            data = abi.encodePacked(bytes1(0xda), bytes1(0x94), deployer, bytes1(0x84), uint32(nonce));
        }
        return address(uint160(uint256(keccak256(data))));
    }
}
