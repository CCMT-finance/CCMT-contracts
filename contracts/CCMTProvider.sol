// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ILimitOrderProtocol.sol";
import "./token/CCMTToken.sol";
import "./vault/CCMTVault.sol";
import "./CCMTTrade.sol";
import "./EIP712Alien.sol";
import "./utils/ArgumentsDecoder.sol";
import "./interfaces/ILimitOrderProtocol.sol";

contract CCMTProvider is EIP712Alien, CCMTTrade {
    using SafeERC20 for IERC20;
    using ArgumentsDecoder for bytes;

    event TradeCreated(uint256 uniq_id);
    event TradeClosed(uint256 uniq_id);

    bytes32 constant public LIMIT_ORDER_TYPEHASH = keccak256(
        "Order(uint256 salt,address makerAsset,address takerAsset,bytes makerAssetData,bytes takerAssetData,bytes getMakerAmount,bytes getTakerAmount,bytes predicate,bytes permit,bytes interaction)"
    );

//    uint256 constant private _FROM_INDEX = 0;
//    uint256 constant private _TO_INDEX = 1;
//    uint256 constant private _AMOUNT_INDEX = 2;

    constructor(address _limitOrderProtocol, address _feeManager)
        CCMTTrade(_limitOrderProtocol, _feeManager)
        EIP712Alien(_limitOrderProtocol, "1inch Limit Order Protocol", "1") {}
    
    /// @notice callback from limit order protocol, executes on order fill
    function notifyFillOrder(
        address makerAsset,           // nft assert
        address takerAsset,           // fromAddress (input asset)
        uint256 makingAmount,         // margin
        uint256 takingAmount,         // uniq_id NFT
        bytes memory interactiveData  // toAddress
    ) external {
        require(msg.sender == limitOrderProtocol, "only limitOrderProtocol can exec callback");
        require(makerAsset == address(ccmtToken), "makerAsset is not ERC721");

        // fetch address
        address toAddress;
        uint8 margin;

        assembly {  // solhint-disable-line no-inline-assembly
            toAddress := mload(add(interactiveData, 20))
            margin := 2 // PoC
        }

        require(toAddress != address(0x0), "invalid toAddressAsset");

        // create trade for NFT
        uint256 nftToken = createTradeImpl(makingAmount, takingAmount, takerAsset, toAddress, 2);

        // give maker possibility to transfer new NFT
        ccmtToken.approve(limitOrderProtocol, nftToken);

        emit TradeCreated(nftToken);
    }

    /// @notice
    function closeTrade(uint256 uniq_id) external {
        closeTradeImpl(uniq_id);

        emit TradeClosed(uniq_id);
    }

    /// @notice
    function getTradeInfo(uint256 uniq_id) external view returns(Trade memory) {
        return getTradeInfoImpl(uniq_id);
    }

    /// @notice validate signature from Limit Order Protocol, checks also asset and amount consistency
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns(bytes4) {
//        LimitOrderProtocol.LOPOrder memory order = abi.decode(signature, (LimitOrderProtocol.LOPOrder));
//
//        uint256 salt;
//        address makerAsset;
//        address takerAsset;
//        bytes memory makerAssetData;
//        bytes memory takerAssetData;
//        bytes memory getMakerAmount;
//        bytes memory getTakerAmount;
//        bytes memory predicate;
//        bytes memory permit;
//        bytes memory interaction;
//
//        assembly {  // solhint-disable-line no-inline-assembly
//            salt := mload(add(signature, 0x40))
//            makerAsset := mload(add(signature, 0x60))
//            takerAsset := mload(add(signature, 0x80))
//            makerAssetData := add(add(signature, 0x40), mload(add(signature, 0xA0)))
//            takerAssetData := add(add(signature, 0x40), mload(add(signature, 0xC0)))
//            getMakerAmount := add(add(signature, 0x40), mload(add(signature, 0xE0)))
//            getTakerAmount := add(add(signature, 0x40), mload(add(signature, 0x100)))
//            predicate := add(add(signature, 0x40), mload(add(signature, 0x120)))
//            permit := add(add(signature, 0x40), mload(add(signature, 0x140)))
//            interaction := add(add(signature, 0x40), mload(add(signature, 0x160)))
//        }
//        bytes32 orderHash;
//        assembly {  // solhint-disable-line no-inline-assembly
//            orderHash := mload(add(interaction, 32))
//        }
//        Order storage _order = orders[orderHash];
//        require( // validate maker amount, address, asset address
//            makerAsset == _order.asset && makerAssetData.decodeUint256(_AMOUNT_INDEX) == _order.remaining &&
//            makerAssetData.decodeAddress(_FROM_INDEX) == address(this) &&
//            _hash(salt, makerAsset, takerAsset, makerAssetData, takerAssetData, getMakerAmount, getTakerAmount, predicate, permit, interaction) == hash,
//            "bad order"
//        );


        return this.isValidSignature.selector;
    }

    function _hash(
        uint256 salt,
        address makerAsset,
        address takerAsset,
        bytes memory makerAssetData,
        bytes memory takerAssetData,
        bytes memory getMakerAmount,
        bytes memory getTakerAmount,
        bytes memory predicate,
        bytes memory permit,
        bytes memory interaction
    ) internal view returns(bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    LIMIT_ORDER_TYPEHASH,
                    salt,
                    makerAsset,
                    takerAsset,
                    keccak256(makerAssetData),
                    keccak256(takerAssetData),
                    keccak256(getMakerAmount),
                    keccak256(getTakerAmount),
                    keccak256(predicate),
                    keccak256(permit),
                    keccak256(interaction)
                )
            )
        );
    }
}