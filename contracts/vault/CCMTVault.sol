// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// use this contract to divide balances and trade logic
contract CCMTVault is Ownable {

    constructor() {}

    function requestTokenAmountOrRevert(uint256 requestAmount, address fromAsset, address toAsset) public returns(bool) {
        uint256 balanceOfAsset = IERC20(fromAsset).balanceOf(address(this));

        // validate request (stub)
        require(requestAmount <= balanceOfAsset, "insufficiently balance");

        return true;
    }

    function sweep(address assetToken) external {
        // unsecure
        sweepTo(assetToken, msg.sender);
    }

    function sweepTo(address assetToken, address _to) onlyOwner public {
        // unsecure
        IERC20(assetToken).transfer(_to, balance(assetToken));
    }

    function balance(address assetToken) public view returns(uint256) {
        return IERC20(assetToken).balanceOf(address(this));
    }
}
