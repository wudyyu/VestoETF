// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IETFMining} from "./interfaces/IETFMining.sol";

contract ETFMining is IETFMining {
     // 指数计算的精度基数,用于避免小数计算
    uint256 public constant INDEX_SCALE = 1e36;
    // 挖矿奖励代币地址
    address public miningToken;
    address public etfAddress;
    // 每秒产出的挖矿奖励数量
    uint256 public miningSpeedPerSecond;
    // 当前全局累积指数
    uint256 public miningLastIndex;
    // 上次更新全局指数的时间戳
    uint256 public lastIndexUpdateTime;
    //用户的最后更新指数
    mapping(address => uint256) public supplierLastIndex;
    // 用户已累积但未领取的奖励
    mapping(address => uint256) public supplierRewardAccrued;
    // 用户质押的ETF数量
    mapping(address => uint256) public stakedBalances;
    // 总质押数量
    uint256 public totalStaked;

    constructor(address miningToken_, address etfAddress_, uint256 miningSpeedPerSecond_) {
        miningToken = miningToken_;
        etfAddress = etfAddress_;
        miningSpeedPerSecond = miningSpeedPerSecond_;
        miningLastIndex = 1e36;
        lastIndexUpdateTime = block.timestamp;
    }

    function updateMiningSpeedPerSecond(uint256 speed) external{
        miningSpeedPerSecond = speed;
    }

}