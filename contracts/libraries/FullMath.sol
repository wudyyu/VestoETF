// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

contract FullMath {
      // 假设这是未完全展示的 mulDiv 函数，用于向下取整（Floor division）
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // ... 此处省略了图片中未完全展示的牛顿迭代高精度实现 ...
    }

    /**
     * @notice 计算 ceil(a * b / denominator), 具有完整精度
     * @dev 首先使用 mulDiv 计算向下取整的结果, 然后在有余数的情况下加1
     * @param a 被乘数
     * @param b 乘数
     * @param denominator 除数
     * @return result 256位结果 (向上取整)
     */
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        // mulmod(a, b, denominator) 用于检查 a * b 除以 denominator 是否有余数
        if (mulmod(a, b, denominator) > 0) {
            // 如果有余数，且结果未溢出 uint256 最大值，则将结果加 1 实现向上取整
            require(result < type(uint256).max, "FullMath: overflow");
            result++;
        }
    }
}