// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IETFTrading {
    /**
    * @dev 当投资金额小于最小铸造数量时抛出
    */
    error LessThanMinMintAmount();

    /**
    * @dev 当尝试移除不存在的代币时抛出
    */
    error TokenNotFound();

    /**
    * @dev 当尝试添加已存在的代币时抛出
    */
    error TokenExists();

    error InvalidSwapPath(bytes swapPath);

    error InvalidArrayLength();

    error OverSlippage();

    error SafeTransferETHFailed();

    event InvestedWithETH (address to, uint256 mintAmount, uint256 paidAmount);

    event InvestedWithToken ( address indexed srcToken, address to, uint256 mintAmount, uint256 totalPaid);

    event RedeemedToETH(address to, uint256 burnAmount, uint256 receivedAmount);

    event RedeemedToToken ( address indexed dstToken, address to, uint256 burnAmount,uint256 receivedAmount);

    function setFee(
        address feeTo_,
        uint24 investFee_,
        uint24 redeemFee_
    ) external;

    /*
      查询投资指定数量份额所需的基础代币数量
    */
    function getInvestTokenAmounts(
        uint256 mintAmount
    ) external view returns (uint256 [] memory tokenAmounts);

    /**
      查询赎回指定数量份额后能获得的基础代币数量
    */
    function getRedeemTokenAmounts(
        uint256 burnAmount
    ) external view returns (uint256 [] memory tokenAmounts);

    /**
     使用特定代币进行投资（申购基金份额）
    */
    function investWithToken(
        address srcToken, 
        address to,
        uint256 mintAmount,
        uint256 maxSrcTokenAmount,
        bytes [] memory swapPaths
    ) external;

    /*
        赎回基金份额并接收指定的目标代币
    */
    function redeemToToken(
        address dstToken,
        address to,
        uint256 burnAmount,
        uint256 minDstTokenAmount,
        bytes [] memory swapPaths
    ) external;


    function getTokens() external view returns (address [] memory);
}