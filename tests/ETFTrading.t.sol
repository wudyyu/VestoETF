// SPDX-License-Identifier: MIT
// SPDX 许可证标识符: MIT
pragma solidity ^0.8.19;
// Solidity 版本声明

import {Test, console} from "forge-std/Test.sol";
// 导入 Forge 测试标准库
import {ETFTrading} from "../src/ETFTrading.sol";
// 导入 ETFTrading 合约
import {ETFQuoter} from "../src/ETFQuoter.sol";
// 导入 ETFQuoter 合约
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// 导入 OpenZeppelin 的 ERC20 接口
import {IETFSwapRouter} from "../src/interfaces/IETFSwapRouter.sol";
// 导入 IETFSwapRouter 接口
import {IETFQuoter} from "../src/interfaces/IETFQuoter.sol";
// 导入 IETFQuoter 接口
import {IUniswapV3Quoter} from "../src/interfaces/IUniswapV3Quoter.sol";
// 导入 Uniswap V3 Quoter 接口
import {Path} from "../src/libraries/Path.sol";

// 导入 Path 库

/**
 * @title ETFTradingSepoliaTest
 * @notice Integration tests for ETFTrading contract on Sepolia testnet
 * @dev Run with: forge test --match-contract ETFTradingSepoliaTest -vvv
 */
// /**
//  * @标题 ETFTradingSepoliaTest
//  * @通知 Sepolia 测试网上 ETFTrading 合约的集成测试
//  * @开发人员说明 运行方式: forge test --match-contract ETFTradingSepoliaTest -vvv
//  */
contract ETFTradingSepoliaTest is Test {
    // 定义 ETFTradingSepoliaTest 合约，继承自 Test
    // Sepolia deployed token addresses from sepolia_tokens.json
    // 从 sepolia_tokens.json 获取的 Sepolia 已部署代币地址
    address public constant LBTC_TOKEN =
        0x22cf3D04CE2Ce407747f1d5d737aeb724462a258;
    address public constant LETH_TOKEN =
        0x6EaadA6E981579A473613a61f1631EC5bDe79041;
    address public constant LINK_TOKEN =
        0x3a6e90ceaeD7a4441853a289688A3939D29FCABf;
    address public constant USDC_TOKEN =
        0x2897A45Af477858Aaeb599c6dDC4Eb75dD7E917b;
    address public constant ETF_QUOTER =
        0xE92CCEdF85cA077F24d2C9fB50c4E5cfCFCd8Ce2;

    // Uniswap V3 SwapRouter on Sepolia
    // Sepolia 上的 Uniswap V3 兑换路由器
    address public constant UNISWAP_V3_SWAP_ROUTER =
        0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;

    // ETF parameters
    // ETF 参数
    string public constant ETF_NAME = "LeapETF";
    string public constant ETF_SYMBOL = "LETF";
    uint256 public constant MIN_MINT_AMOUNT = 1e18; // 1 ETF

    // Token decimals
    // 代币精度
    uint8 public constant LBTC_DECIMALS = 8;
    uint8 public constant LETH_DECIMALS = 18;
    uint8 public constant LINK_DECIMALS = 18;
    uint8 public constant USDC_DECIMALS = 6;

    // 合约实例
    ETFTrading public etfTrading;
    IETFQuoter public etfQuoter;

    // 测试地址
    address public deployer;
    address public testUser;
    address public feeTo;

    // 1个ETF份额对应的代币数量
    uint256 public constant LBTC_PER_SHARE = 0.000477 * 10**8; // LBTC (8 decimals)
    uint256 public constant LETH_PER_SHARE = 0.015 * 10**18; // LETH (18 decimals)
    uint256 public constant LINK_PER_SHARE = 1.43 * 10**18; // LINK (18 decimals)
    uint256 public constant USDC_PER_SHARE = 10 * 10**6; // USDC (6 decimals)

    // 用于日志记录，格式化带小数的辅助函数
    function formatAmount(uint256 amount, uint8 decimals)
        public
        pure
        returns (string memory)
    {}

    // 用于测试，向用户铸造代币的辅助函数
    function mintTokensToUser(address user, uint256 etfShareMultiplier) public {
        // 根据指定的倍数（factor）铸造基于ETF份额构成的代币
        deal(LBTC_TOKEN, user, LBTC_PER_SHARE * etfShareMultiplier);
        deal(LETH_TOKEN, user, LETH_PER_SHARE * etfShareMultiplier);
        deal(LINK_TOKEN, user, LINK_PER_SHARE * etfShareMultiplier);
        deal(USDC_TOKEN, user, USDC_PER_SHARE * etfShareMultiplier);
        // 记录铸造数量
        console.log("- Minted Tokens to User");
        console.log("User address:", user);
        console.log(
            "LBTC minted:",
            formatAmount(LBTC_PER_SHARE * etfShareMultiplier, LBTC_DECIMALS)
        );
        console.log(
            "LETH minted:",
            formatAmount(LETH_PER_SHARE * etfShareMultiplier, LETH_DECIMALS)
        );
        console.log(
            "LINK minted:",
            formatAmount(LINK_PER_SHARE * etfShareMultiplier, LINK_DECIMALS)
        );
        console.log(
            "USDC minted:",
            formatAmount(USDC_PER_SHARE * etfShareMultiplier, USDC_DECIMALS)
        );
    }

    // 帮助函数，用于批准代币给 ETFTrading 合约
    function approveTokensForETF(address user, uint256 etfShareMultiplier)
        public
    {
        // 启动模拟调用者为 user 的操作 (Foundry 作弊码)
        vm.startPrank(user);
        // 批准 LBTC 代币给 etfTrading 合约
        IERC20(LBTC_TOKEN).approve(
            address(etfTrading),
            LBTC_PER_SHARE * etfShareMultiplier
        );
        // 批准 LETH 代币给 etfTrading 合约
        IERC20(LETH_TOKEN).approve(
            address(etfTrading),
            LETH_PER_SHARE * etfShareMultiplier
        );
        // 批准 LINK 代币给 etfTrading 合约
        IERC20(LINK_TOKEN).approve(
            address(etfTrading),
            LINK_PER_SHARE * etfShareMultiplier
        );
        // 批准 USDC 代币给 etfTrading 合约
        IERC20(USDC_TOKEN).approve(
            address(etfTrading),
            USDC_PER_SHARE * etfShareMultiplier
        );
        // 停止模拟调用者操作
        vm.stopPrank();

        // 控制台日志输出
        console.log("- Approved Tokens for ETF Trading -");
        console.log("User address:", user);
    }

    function setUp() public {
        // 使用环境变量中的私钥进行测试
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(privateKey);
        testUser = makeAddr("testUser");
        feeTo = makeAddr("feeTo");

        // 为ETF设置代币数组
        address[] memory tokens = new address[](4);
        tokens[0] = LBTC_TOKEN;
        tokens[1] = LETH_TOKEN;
        tokens[2] = LINK_TOKEN;
        tokens[3] = USDC_TOKEN;

        // 为每个份额设置代币数量
        uint256[] memory initTokenAmountPerShares = new uint256[](4);
        initTokenAmountPerShares[0] = LBTC_PER_SHARE;
        initTokenAmountPerShares[1] = LETH_PER_SHARE;
        initTokenAmountPerShares[2] = LINK_PER_SHARE;
        initTokenAmountPerShares[3] = USDC_PER_SHARE;

        // Deploy ETFTrading contract
        // 部署 ETFTrading 合约
        vm.startPrank(deployer); // 启动作弊码，模拟 deployer 调用
        etfTrading = new ETFTrading(
            ETF_NAME,
            ETF_SYMBOL,
            tokens,
            initTokenAmountPerShares,
            MIN_MINT_AMOUNT,
            UNISWAP_V3_SWAP_ROUTER
        );

        // Set fees (0.1% invest fee, 0.2% redeem fee)
        // 设置费用 (0.1% 投资费率, 0.2% 赎回费率)
        etfTrading.setFee(feeTo, 1000, 2000); // 1000代表0.1% (基数为1,000,000), 2000代表0.2%
        vm.stopPrank(); // 停止模拟调用

        console.log("Test deployer address:", deployer);
        console.log("Test user address:", testUser);
        console.log("ETFTrading deployed at:", address(etfTrading));
    }

    function test_ETFTokens() public view {
        // 测试 getTokens 函数
        address[] memory etfTokens = etfTrading.getTokens();
        // T

        // 验证代币地址
        assertEq(etfTokens.length, 4, "应该有 4 个代币");
        assertEq(etfTokens[0], LBTC_TOKEN, "第一个代币应该是 LBTC");
        assertEq(etfTokens[1], LETH_TOKEN, "第二个代币应该是 LETH");
        assertEq(etfTokens[2], LINK_TOKEN, "第三个代币应该是 LINK");
        assertEq(etfTokens[3], USDC_TOKEN, "第四个代币应该是 USDC");

        // 记录代币地址日志
        console.log("--- ETF 代币组成 ---");
        for (uint256 i = 0; i < etfTokens.length; i++) {
            console.log("代币", i, ":", etfTokens[i]);
        }
    }

    function test_InvestTokenAmounts() public view {
        // 测试 getInvestTokenAmounts 函数
        uint256 testMintAmount = 1e18; // 1个ETF
        uint256[] memory investAmounts = etfTrading.getInvestTokenAmounts(
            testMintAmount
        );

        // 验证我们得到了正确数量的代币金额
        assertEq(investAmounts.length, 4, "应该有 4 个代币金额");

        // 记录代币金额日志
        console.log("--- 铸造 1 个 ETF 所需的代币金额 ---");
        console.log(
            "LBTC amount:",
            formatAmount(investAmounts[0], LBTC_DECIMALS)
        );
        console.log(
            "LETH amount:",
            formatAmount(investAmounts[1], LETH_DECIMALS)
        );
        console.log(
            "LINK amount:",
            formatAmount(investAmounts[2], LINK_DECIMALS)
        );
        console.log(
            "USDC amount:",
            formatAmount(investAmounts[3], USDC_DECIMALS)
        );

        // 因为这是第一次投资，金额应该与我们的初始配置匹配
        assertEq(investAmounts[0], LBTC_PER_SHARE, "LBTC 金额不匹配");
        assertEq(investAmounts[1], LETH_PER_SHARE, "LETH 金额不匹配");
        assertEq(investAmounts[2], LINK_PER_SHARE, "LINK 金额不匹配");
        assertEq(investAmounts[3], USDC_PER_SHARE, "USDC 金额不匹配");
    }

    function test_Invest() public {
        // 使用 LBTC 作为来源代币测试投资函数

        // 1. 为测试用户铸造代币 (所需数量的 10 倍，以确保足够的费用)
        uint256 shareMultiplier = 10;
        mintTokensToUser(testUser, shareMultiplier);

        // 2. 批准代币给 ETF 合约
        approveTokensForETF(testUser, shareMultiplier);

        // 3. 从 ETFQuoter 获取交换路径
        uint256 mintAmount = 1e18; // 1 个 ETF
        (uint256 srcAmount, bytes[] memory swapPaths) = etfQuoter
            .quoteInvestWithToken(address(etfTrading), LBTC_TOKEN, mintAmount);

        console.log("--- Investment Quote ---");
        console.log("Source token: LBTC");
        console.log("Mint amount: 1 ETF");
        console.log(
            "Required LBTC amount:",
            formatAmount(srcAmount, LBTC_DECIMALS)
        );

        // 4. Perform investment with LBTC as source token
        // 4. 使用 LBTC 作为来源代币执行投资
        // 将所需金额翻倍以应对滑点（Slippage）
        uint256 maxSrcTokenAmount = srcAmount * 2;

        vm.startPrank(testUser); // 模拟 testUser 调用
        etfTrading.investWithToken(
            LBTC_TOKEN, // 来源代币
            testUser, // 接收者
            mintAmount, // 铸造数量
            maxSrcTokenAmount, // 最大来源代币数量 (含滑点容忍)
            swapPaths // 来自报价器的交换路径
        );
        vm.stopPrank(); // 停止模拟调用

        // 5. 验证投资是否成功

        // 获取测试用户的 ETF 余额
        uint256 etfBalance = etfTrading.balanceOf(testUser);
        // 计算预期余额：铸造数量减去 0.1% 的费用
        uint256 expectedBalance = mintAmount - ((mintAmount * 1000) / 1000000); // 减去 0.1% 费用

        // 控制台日志输出
        console.log("--- 投资结果 ---");
        console.log("测试用户的 ETF 余额:", formatAmount(etfBalance, 18));
        console.log("扣除费用后的预期余额:", formatAmount(expectedBalance, 18));

        // 断言：验证实际余额是否等于预期余额
        assertEq(etfBalance, expectedBalance, "投资后的 ETF 余额不匹配");

        // 6. 验证费用接收者是否收到了他们的份额
        uint256 feeRecipientBalance = etfTrading.balanceOf(feeTo);
        uint256 expectedFeeAmount = (mintAmount * 1000) / 1000000; // 0.1% 费用

        console.log("费用接收者余额:", formatAmount(feeRecipientBalance, 18));
        console.log("预期费用金额:", formatAmount(expectedFeeAmount, 18));

        assertEq(
            feeRecipientBalance,
            expectedFeeAmount,
            "费用接收者余额不匹配"
        );
    }
}
