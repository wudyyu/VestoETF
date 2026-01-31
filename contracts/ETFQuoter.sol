// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {IETFQuoter} from "./interfaces/IETFQuoter.sol";
import {IETFTrading} from "./interfaces/IETFTrading.sol";
import {IUniswapV3Quoter} from "./interfaces/IUniswapV3Quoter.sol";

contract ETFQuoter is IETFQuoter {
    function quoteInvestWithToken(
        address etf,
        address srcToken,
        uint256 mintAmount
    ) external view returns (uint256 srcAmount, bytes[] memory swapPaths) {
        address[] memory tokens = IETFTrading(etf).getTokens();
        uint256[] memory tokenAmounts = IETFTrading(etf).getInvestTokenAmounts(
            mintAmount
        );

        swapPaths = new bytes[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == srcToken) {
                srcAmount += tokenAmounts[i];
                swapPaths[i] = bytes.concat(
                    bytes20(srcToken),
                    bytes3(fees[0]), // Note: fees[0] needs to be defined in context
                    bytes20(srcToken)
                );
            } else {
                (bytes memory path, uint256 amountIn) = quoteExactOut(
                    srcToken,
                    tokens[i],
                    tokenAmounts[i]
                );
                srcAmount += amountIn;
                swapPaths[i] = path;
            }
        }
    }

    function quoteRedeemToToken(
        address etf,
        address dstToken,
        uint256 burnAmount
    ) external view returns (uint256 dstAmount, bytes[] memory swapPaths) {
        address[] memory tokens = IETFTrading(etf).getTokens();
        uint256[] memory tokenAmounts = IETFTrading(etf).getRedeemTokenAmounts(
            burnAmount
        );

        swapPaths = new bytes[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == dstToken) {
                dstAmount += tokenAmounts[i];
                swapPaths[i] = bytes.concat(
                    bytes20(dstToken),
                    bytes3(fees[0]),
                    bytes20(dstToken)
                );
            } else {
                (bytes memory path, uint256 amountout) = quoteExactIn(
                    tokens[i],
                    dstToken,
                    tokenAmounts[i]
                );
                dstAmount += amountout;
                swapPaths[i] = path;
            }
        }
    }

    function quoteExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (bytes memory path, uint256 amountOut) {
        // 获取所有可能得路径
        bytes[] memory paths = getAllPaths(tokenIn, tokenOut);
        // 遍历这些路径,找到最优解
        for (uint256 i = 0; i < paths.length; i++) {
            try uniswapV3Quoter.quoteExactInput(paths[i], amountIn) returns (
                uint256 amountOut_,
                uint160[] memory,
                uint32[] memory,
                uint256
            ) {
                if (
                    amountOut_ > 0 && (amountOut == 0 || amountOut_ > amountOut)
                ) {
                    amountOut = amountOut_;
                    path = paths[i];
                }
            } catch {}
        }
    }

    function quoteExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountOut
    ) external view returns (bytes memory path, uint256 amountIn) {
        // 获取所有可能得路径
        //遍历这些路径,找到最优解
    }

    function getAllPaths(address tokenA, address tokenB)
        external
        view
        returns (bytes[] memory paths)
    {
        paths = new bytes[](fees.length);
        // 生成直接路径
        for (uint256 i = 0; i < fees.length; i++) {
            paths[i] = bytes.concat(
                bytes20(tokenA),
                bytes32(fees[i]),
                bytes20(tokenB)
            );
        }
    }
}
