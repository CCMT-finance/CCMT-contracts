// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./vault/CCMTVault.sol";
import "./token/CCMTToken.sol";
import "./interfaces/IUniswapV2Router.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CCMTTrade is CCMTVault {
    using SafeERC20 for IERC20;

    // kovan (hardcode)
    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    struct Trade {
        bool isActive;
        bool successed;
        address fromAsset;
        address toAsset;

        uint256 deposited;
        uint256 depositedWithMargin;

        uint256 depositedOut;

        uint createdTimestamp;
    }

    address public immutable limitOrderProtocol;

    CCMTToken public ccmtToken;

    address public feeManager;

    mapping(uint256 => Trade) public trades;

    constructor(address _limitOrderProtocol, address _feeManager) {
        limitOrderProtocol = _limitOrderProtocol;
        feeManager = _feeManager;
        ccmtToken = new CCMTToken();
    }

    function createTradeImpl(
        uint256 uniq_id,
        uint256 deposited,
        address fromAsset,
        address toAsset,
        uint256 margin
    ) internal returns(uint256) {
        // default margin x2
        uint256 amountWithMargin = deposited * margin;

        requestTokenAmountOrRevert(amountWithMargin, fromAsset, toAsset);

        // make trade (example: uniswap)

        uint256 amountOutMin = _getAmountOutMin(fromAsset, toAsset, amountWithMargin);
        uint256 realAmountOut = _swapTo(fromAsset, toAsset, amountWithMargin, amountOutMin, address(this));

        // save trade
        ccmtToken.addNewTrade(address(this), uniq_id);
        ccmtToken.approve(limitOrderProtocol, uniq_id);

        trades[uniq_id] = Trade({
            isActive: true,
            successed: true,
            fromAsset: fromAsset,
            toAsset: toAsset,

            deposited: deposited,
            depositedWithMargin: amountWithMargin,

            depositedOut: realAmountOut,
            createdTimestamp: block.timestamp
        });

        return uniq_id;
    }

    function closeTradeImpl(uint256 uniq_id) internal {
        // TODO work with deadlines
        require(ccmtToken.ownerOf(uniq_id) == msg.sender, "unauthorized");
        require(trades[uniq_id].isActive, "already non-active");

        // optional
        ccmtToken.burnToken(uniq_id);

        // active false
        trades[uniq_id].isActive = false;

        // start strategy
        address fromAsset = trades[uniq_id].fromAsset;
        address toAsset = trades[uniq_id].toAsset;
        uint256 depositedOut = trades[uniq_id].depositedOut;

        uint256 amountOutMin = _getAmountOutMin(toAsset, fromAsset, depositedOut);
        uint256 realAmountReturned = _swapTo(toAsset, fromAsset, depositedOut, amountOutMin, address(this));

        uint256 depositedEarlier = trades[uniq_id].deposited;
        uint256 depositedWithMarginEarlier = trades[uniq_id].depositedWithMargin;

        // disable fee for feeManager
        if (realAmountReturned > depositedWithMarginEarlier) {
            // profit condition
            trades[uniq_id].successed = true;

            // userProfit = realAmountReturned - depositedWithMarginEarlier;
            uint256 firstReturnForBank = depositedWithMarginEarlier - depositedEarlier;

            IERC20(fromAsset).safeTransfer(msg.sender, realAmountReturned - firstReturnForBank);
            // leave on contract depositedWithMarginEarlier - depositedEarlier
        } else {
            // unprofit condition
            trades[uniq_id].successed = false;

            // in first return to bank
            uint256 firstReturnForBank = depositedWithMarginEarlier - depositedEarlier;

            if (firstReturnForBank < realAmountReturned) {
                IERC20(fromAsset).safeTransfer(msg.sender, realAmountReturned - firstReturnForBank);
            }

            // leave others tokens
        }
    }

    function getTradeInfoImpl(uint256 uniq_id) internal view returns(Trade memory) {
        return trades[uniq_id];
    }

    function _swapTo(
        address _tokenIn,
        address _tokenOut,
        uint _amountIn,
        uint _amountOutMin,
        address _to
    ) internal returns(uint256) {
        IERC20(_tokenIn).approve(UNISWAP_V2_ROUTER, _amountIn);

        address[] memory path;
        path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;

        uint256 beforeBalance = balance(_tokenOut);
        IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            _amountIn,
            _amountOutMin,
            path,
            _to,
            block.timestamp
        );

        return balance(_tokenOut) - beforeBalance;
    }

    function _getAmountOutMin(address _tokenIn, address _tokenOut, uint256 _amountIn) internal view returns (uint256) {
        address[] memory path;

        path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;

        uint256[] memory amountOutMins = IUniswapV2Router(UNISWAP_V2_ROUTER).getAmountsOut(_amountIn, path);
        return amountOutMins[path.length - 1];
    }
}
