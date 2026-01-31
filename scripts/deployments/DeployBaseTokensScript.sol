// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockToken} from "../../src/mocks/MockToken.sol";

/**
 * @title 部署基础代币脚本
 * @notice 用于将 4 种基础代币 (LBTC, LETH, LINK, USDC) 部署到 Sepolia 测试网的脚本
 * @dev 运行方式:
 *
 * forge script script/deployments/DeployBaseTokens.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vv
 */
contract DeployBaseTokensScript is Script {
    // 代币精度
    uint8 public constant LBTC_DECIMALS = 8;
    uint8 public constant LETH_DECIMALS = 18;
    uint8 public constant LINK_DECIMALS = 18;
    uint8 public constant USDC_DECIMALS = 6;

    // 已部署的代币地址
    address public lbtcToken;
    address public lethToken;
    address public linkToken;
    address public usdcToken;

}