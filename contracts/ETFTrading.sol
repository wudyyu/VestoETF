// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IETFTrading} from "./interfaces/IETFTrading.sol";
import {FullMath} from "./libraries/FullMath.sol";
import {IETFSwapRouter} from "./interfaces/IETFSwapRouter.sol";

contract ETFTrading is IETFTrading, ERC20, Ownable {
    using Fullmath for uint256;
    using SafeERC20 for IERC20;
    using Path for bytes;

    // 常量定义
    uint24 public constant HUNDRED_PERCENT = 1000000; // 100% = 1,000,000,用于费用计算的基数
    uint24 public constant FEE_DENOMINATOR = 1000000; // 基数为1,000,000
    uint24 public constant DEFAULT_POOL_FEE = 3000; // 0.3%的默认交易池费率
    uint256 public constant SLIPPAGE_TOLERANCE = 50000; // 默认滑点容忍度5%

    // Fee相关
    address internal _feeTo;
    uint24 internal _investFee;
    uint24 internal _redeemFee;

    // ETF组成代币相关
    address public immutable swapRouter;
    uint256 internal _minMintAmount;
    address[] internal _tokens;
    mapping(address => bool) internal _isTokenExist;

    // 每个ETF份额对应的初始代币数量,用于首次投资时的计算
    uint256[] private _initTokenAmountPerShares;

    constructor(
        string memory name_,
        string memory symbol_,
        address[] memory tokens_,
        uint256[] memory initTokenAmountPerShare_,
        uint256 minMintAmount_,
        address swapRouter_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        require(tokens_.length > 0, "ETF: Empty tokens");
        require(
            tokens_.length == initTokenAmountPerShare_.length,
            "ETF: Length mismatch"
        );

        swapRouter = swapRouter_;
        _tokens = tokens_;
        _initTokenAmountPerShares = initTokenAmountPerShare_;
        _minMintAmount = minMintAmount_;

        // 设置代币存在标志
        for (uint256 i = 0; i < tokens_.length; i++) {
            require(tokens_[i] != address(0), "ETF: Zero address token");
            _isTokenExist[tokens_[i]] = true;
        }
    }

    function getRedeemTokenAmounts(uint256 burnAmount)
        public
        view
        returns (uint256[] memory tokenAmounts)
    {
        if (_redeemFee > 0) {
            uint256 fee = (burnAmount * _redeemFee) / HUNDRED_PERCENT;
            burnAmount -= fee;
        }

        uint256 totalSupply = totalSupply();
        tokenAmounts = new uint256[](_tokens.length); // Assuming _tokens.length is the correct length variable

        for (uint256 i = 0; i < _tokens.length; i++) {
            uint256 tokenReserve = IERC20(_tokens[i]).balanceOf(address(this));
            // tokenAmount / tokenReserve = burnAmount / totalSupply
            tokenAmounts[i] = tokenReserve.mulDiv(burnAmount, totalSupply);
        }
    }

    function setFee(
        address feeTo_,
        uint24 investFee_,
        uint24 redeemFee_
    ) external virtual override {
        _feeTo = feeTo_;
        _investFee = investFee_;
        _redeemFee = redeemFee_;
    }

    /*
        _redeem

        这是一个内部函数,负责销毁 ETF 份额并计算应返还的底层代币数量:

        1.销毁 ETF 份额:从调用者账户销毁指定数量的ETF 份額

        2.计算并收取费用:如果设置了赎回费用,计算费用并铸造给费用接收地址

        3.计算实际赎回数量:扣除费用后的实际赎回数量

        4.计算并转移底层代币:
        。 对于每种底层代币,按比例计算应返还的数量
        。 公式: tokenAmount tokenReserve actuallyBurnAmount / totalSupply
        。 如果接收者不是合约本身,将代币转移给接收者
    */
    function _redeem(address to, uint256 burnAmount)
        internal
        returns (uint256[] memory tokenAmounts)
    {
        uint256 totalSupply = totalSupply();
        tokenAmounts = new uint256[](_tokens.length);
        _burn(msg.sender, burnAmount);

        uint256 fee;
        if (_redeemFee > 0) {
            fee = (burnAmount * _redeemFee) / HUNDRED_PERCENT;
            _mint(_feeTo, fee);
            uint256 actuallyBurnAmount = burnAmount - fee;

            for (uint256 i = 0; i < _tokens.length; i++) {
                uint256 tokenReserve = IERC20(_tokens[i]).balanceOf(
                    address(this)
                );
                tokenAmounts[i] = tokenReserve.mulDiv(
                    actuallyBurnAmount,
                    totalSupply
                );

                if (to != address(this) && tokenAmounts[i] > 0)
                    IERC20(_tokens[i]).safeTransfer(to, tokenAmounts[i]);
            }
        }
    }

    function redeemToToken(
        address dstToken,
        address to,
        uint256 burnAmount,
        uint256 minDstTokenAmount,
        bytes[] memory swapPaths
    ) external {
        address[] memory tokens = this.getTokens();
        if (tokens.length != swapPaths.length) revert InvalidArrayLength();

        uint256[] memory tokenAmounts = _redeem(address(this), burnAmount);
        uint256 totalReceived;

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokenAmounts[i] == 0) continue;

            if (!_checkSwapPath(tokens[i], dstToken, swapPaths[i]))
                revert InvalidSwapPath(swapPaths[i]);

            if (tokens[i] == dstToken) {
                IERC20(tokens[i]).safeTransfer(to, tokenAmounts[i]);
                totalReceived += tokenAmounts[i];
            } else {
                _approveToSwapRouter(tokens[i]);
                totalReceived += IETFSwapRouter(swapRouter).exactInput(
                    IETFSwapRouter.ExactInputParams({
                        path: swapPaths[i],
                        recipient: to,
                        amountIn: tokenAmounts[i],
                        amountOutMinimum: 1
                    })
                );
            }
        }

        if (totalReceived < minDstTokenAmount) revert OverSlippage();

        emit RedeemedToToken(dstToken, to, burnAmount, totalReceived);
    }

    //接收ETH
    receive() external payable {}

    /*
        这个函数计算铸造指定数量 ETF 份额所需的各种代币数量,它有两种计算模式:
        1.首次投资模式 (totalSupply = 0):
         使用预设的初始代币比例计算
         公式: tokenAmount = mintAmount * initTokenAmountPerShare / 1e18
         这确保了ETF的初始组成符合预期设计
        2.非首次投资模式 (totalSupply > 0):
         基于当前资金池中的代币比例计算
         公式: tokenAmount = tokenReserve * mintAmount / totalSupply
         这确保了新投资者与现有投资者享有相同的资产比例
        两种模式都使用向上取整 (mulDivRoundingUp) 确保有足够的代币投入,避免因舍入误差导致资金池比例失衡
    */
    function getInvestTokenAmounts(uint256 mintAmount)
        public
        view
        returns (uint256[] memory tokenAmounts)
    {
        // 获取当前ETF代币的总供应量
        uint256 totalSupply = totalSupply();
        // 创建一个数组来存储每种代币需要的数量
        tokenAmounts = new uint256[](tokens_.length);

        //遍历每种代币进行计算
        for (uint256 i = 0; i < _tokens.length; i++) {
            if (totalSupply > 0) {
                //非首次投资:基于当前资金池中的代币比例计算
                // 获取当前合约中持有的该代币数量
                uint256 tokenReserve = IERC20(_tokens[i]).balanceOf(
                    address(this)
                );
                // 使用等比例公式:tokenAmount / tokenReserve = mintAmount / totalSupply
                // 即: tokenAmount = tokenReserve * mintAmount / totalSupply
                //使用向上取整确保有足够的代币投入
                tokenAmounts[i] = tokenReserve.mulDivRoundingUp(
                    mintAmount,
                    totalSupply
                );
            } else {
                // 首次投资:使用预设的初始代币比例
                //_initTokenAmountPerShares[i] 表示每个ETF份额对应的代币的数量(基于1e18精度)
                // 计算公式:tokenAmount = mintAmount * initTokenAmountPerShare / 1e18
                tokenAmounts[i] = mintAmount.mulDivRoundingUp(
                    _initTokenAmountPerShares[i],
                    1e18
                );
            }
        }
    }

    function getToken(uint256 index) public view returns (address) {
        require(index < _tokens.length, "ETF: Invalid token index");
        return _tokens[index];
    }

    function getTokenCount() public view returns (uint256) {
        return _tokens.length;
    }

    function updateMinMintAmount(uint256 newMinMintAmount) external virtual {
        _minMintAmount = newMinMintAmount;
    }

    function feeTo() public view returns (address) {
        return _feeTo;
    }

    function getInvestFee() public view returns (uint24) {
        return _investFee;
    }

    function getRedeemFee() public view returns (uint24) {
        return _redeemFee;
    }

    function getMinMintAmount() public view returns (uint256) {
        return _minMintAmount;
    }

    function getTokens() external view returns (address[] memory) {
        return _tokens;
    }
}
