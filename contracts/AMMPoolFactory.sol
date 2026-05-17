// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {AMMPool} from "./AMMPool.sol";

/// @title AMMPoolFactory
/// @notice Uses both CREATE and CREATE2 to deploy resource AMM pools.
contract AMMPoolFactory is AccessControl {
    bytes32 public constant POOL_CREATOR_ROLE = keccak256("POOL_CREATOR_ROLE");

    mapping(address => mapping(address => address)) public getPool;
    address[] public allPools;

    event PoolCreated(address indexed token0, address indexed token1, address indexed pool, bool deterministic, bytes32 salt);

    constructor(address admin) {
        require(admin != address(0), "AMMPoolFactory: zero admin");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(POOL_CREATOR_ROLE, admin);
    }

    function allPoolsLength() external view returns (uint256) {
        return allPools.length;
    }

    function createPool(address tokenA, address tokenB) external onlyRole(POOL_CREATOR_ROLE) returns (address pool) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        require(getPool[token0][token1] == address(0), "AMMPoolFactory: pool exists");
        pool = address(new AMMPool(token0, token1, address(this)));
        _registerPool(token0, token1, pool, false, bytes32(0));
    }

    function createPoolDeterministic(address tokenA, address tokenB, bytes32 salt)
        external
        onlyRole(POOL_CREATOR_ROLE)
        returns (address pool)
    {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        require(getPool[token0][token1] == address(0), "AMMPoolFactory: pool exists");
        bytes32 finalSalt = keccak256(abi.encodePacked(token0, token1, salt));
        pool = address(new AMMPool{salt: finalSalt}(token0, token1, address(this)));
        _registerPool(token0, token1, pool, true, finalSalt);
    }

    function predictPoolAddress(address tokenA, address tokenB, bytes32 salt) external view returns (address predicted) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bytes32 finalSalt = keccak256(abi.encodePacked(token0, token1, salt));
        bytes memory bytecode = abi.encodePacked(type(AMMPool).creationCode, abi.encode(token0, token1, address(this)));
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), finalSalt, keccak256(bytecode)));
        predicted = address(uint160(uint256(hash)));
    }

    function pausePool(address pool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AMMPool(pool).pause();
    }

    function unpausePool(address pool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AMMPool(pool).unpause();
    }

    function _registerPool(address token0, address token1, address pool, bool deterministic, bytes32 salt) internal {
        getPool[token0][token1] = pool;
        getPool[token1][token0] = pool;
        allPools.push(pool);
        emit PoolCreated(token0, token1, pool, deterministic, salt);
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "AMMPoolFactory: identical tokens");
        require(tokenA != address(0) && tokenB != address(0), "AMMPoolFactory: zero token");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}
