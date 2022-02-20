// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CCMTToken is ERC721, Ownable {

    constructor() ERC721("CCMTToken", "CCMT") {}

    function addNewTrade(address tradeHolder, uint256 uniq_id) onlyOwner external {
        _mint(tradeHolder, uniq_id);
    }

    function burnToken(uint256 tokenId) onlyOwner external {
        _burn(tokenId);
    }
}
