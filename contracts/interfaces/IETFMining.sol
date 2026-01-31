// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IETFMining {
    error NothingClaimable();

    event SupplierIndexUpdated(address indexed supplier, uint256 deltaIndex, uint256 lastIndex);

    event RewardClaimed(address indexed supplier, uint256 claimedAmount);

    event Staked(address indexed user, uint256 amount);

    event Unstaked(address indexed user, uint256 amount);

    function updateMiningSpeedPerSecond(uint256 speed) external;

    function stake(uint256 amount) external;

    function unstake(uint256 amount) external;

    function claimReward() external;

    function getClaimableReward(
        address supplier
    ) external view returns (uint256);
}