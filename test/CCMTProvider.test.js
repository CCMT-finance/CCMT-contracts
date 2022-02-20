const { expect } = require("chai");
const { ethers } = require("hardhat");

const { expectRevert, BN, time, constants } = require('@openzeppelin/test-helpers');

const {LimitOrderBuilder, Web3ProviderConnector} = require('@1inch/limit-order-protocol');

const CCMTProvider = artifacts.require('CCMTProvider');
const TokenMock = artifacts.require('TokenMock');
const CCMTToken = artifacts.require('CCMTToken');

const { addr1PrivateKey, toBN, cutLastArg } = require('./utils/utils');

const { buildOrderData } = require('./utils/orderUtils');

const LimitOrderProtocol = artifacts.require('LimitOrderProtocol');

const hre = require('hardhat');
const { getChainId } = hre;

const submitOrder = async (
    contractAddress,
    makerAddress,
    makerAssetAddress,
    takerAssetAddress,
    makerAmount,
    takerAmount,
    tradeToAddress,
    margin
) => {
    // @ts-ignore
    const connector = new Web3ProviderConnector(web3);

    const limitOrderBuilder = new LimitOrderBuilder(
        contractAddress,
        42, // web3State.netId,
        connector
    );

    console.log(web3.eth.abi.encodeParameter(
            'bytes32', tradeToAddress
        ));

    // address + margin
    let interactionHex = tradeToAddress + "02";

    const limitOrderStruct = {
        makerAssetAddress,
        takerAssetAddress,
        makerAddress: makerAddress,
        makerAmount: makerAmount,
        takerAmount: takerAmount,
        predicate: '0x',
        permit: '0x',
        interaction: web3.eth.abi.encodeParameter('bytes32', interactionHex)
    }

    const limitOrder = limitOrderBuilder.buildLimitOrder(limitOrderStruct);

    // remove cheks of balance
    limitOrder.getMakerAmount = '0x';
    limitOrder.getTakerAmount = '0x';

    return limitOrder;
}

const OrderSol = [
    {name: 'salt', type: 'uint256'},
    {name: 'makerAsset', type: 'address'},
    {name: 'takerAsset', type: 'address'},
    {name: 'makerAssetData', type: 'bytes'},
    {name: 'takerAssetData', type: 'bytes'},
    {name: 'getMakerAmount', type: 'bytes'},
    {name: 'getTakerAmount', type: 'bytes'},
    {name: 'predicate', type: 'bytes'},
    {name: 'permit', type: 'bytes'},
    {name: 'interaction', type: 'bytes'},
];

const ABIOrder = {
    'Order': OrderSol.reduce((obj, item) => {
        obj[item.name] = item.type;
        return obj;
    }, {}),
};

describe("CCMTProvider", function () {

    let addr1, wallet;

    let provider, dai, usdc, swap;

    before(async function () {
        [addr1, wallet] = await web3.eth.getAccounts();
    });

    beforeEach(async function () {

    });

    it("Check real transfer", async function () {
        console.log(await getChainId());

        if (await getChainId() == '42') {
            return;
        }

        const zeroAddress = "0x0000000000000000000000000000000000000000";

        swap = await LimitOrderProtocol.new();

        provider = await CCMTProvider.new(swap.address, zeroAddress);


        dai = await TokenMock.new('DAI', 'DAI');
        usdc = await TokenMock.new('USDC', 'USDC');

        await dai.mint(wallet, '1000000');
        await usdc.mint(wallet, '1000000');
        await dai.mint(addr1, '1000000');
        await usdc.mint(addr1, '1000000');

        //
        await dai.approve(swap.address, '1000000');
        await usdc.approve(swap.address, '1000000');
        await dai.approve(swap.address, '1000000', { from: wallet });
        await usdc.approve(swap.address, '1000000', { from: wallet });

        // up balance for provider
        await dai.transfer(provider.address, '1000', { from: wallet });

        //
        let nftToken = await provider.ccmtToken();
        let nftUniqId = Math.floor(Math.random() * 9999999);

        console.log("NFT", nftToken);
        console.log("usdc", usdc.address);

        const connector = new Web3ProviderConnector(web3);

        let limitOrder = await submitOrder(swap.address, provider.address, nftToken, dai.address, 1, 100, usdc.address, 2);

        const signature = web3.eth.abi.encodeParameter(ABIOrder, limitOrder);


        console.log("MY WALLET: " + wallet);
        await swap.fillOrder(limitOrder, signature, toBN("0"), toBN("100"), toBN('0'), {from: wallet});
    });

    it("Check real kovan", async function () {
        if (await getChainId() != '42') {
            return;
        }

        const zeroAddress = "0x0000000000000000000000000000000000000000";

        swap = await LimitOrderProtocol.at("0x94Bc2a1C732BcAd7343B25af48385Fe76E08734f");

        const unlockedAccount = "0x7Ee75d0931C62fc88D9887BD5516D8DF6B8b3A9e";
        provider = await CCMTProvider.new(swap.address, zeroAddress, {from: unlockedAccount});

        dai = await TokenMock.at("0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa");
        weth = await TokenMock.at("0xd0A1E359811322d97991E03f863a0C30C2cF029C");

        // get approve for DAI
        await dai.approve(swap.address, '10000000', {from: unlockedAccount});

        // up balance for provider
        await dai.transfer(provider.address, '46968769358', { from: unlockedAccount });

        // generate uniq nft token
        let nftTokenAddress = await provider.ccmtToken();
        let nftTokenContract = await CCMTToken.at(nftTokenAddress);

        let nftUniqId = Math.floor(Math.random() * 9999999);

        console.log("Before ", await weth.balanceOf(provider.address));

        let makerAmount = nftUniqId; // nft
        let takerAmount = 10000000;

        // generate special dict
        let limitOrder = await submitOrder(
            swap.address,
            provider.address,
            nftTokenAddress,
            dai.address,
            makerAmount,
            takerAmount,
            weth.address,
            2
        );

        const signature = web3.eth.abi.encodeParameter(ABIOrder, limitOrder);
        await swap.fillOrder(limitOrder, signature, toBN("0"), toBN(takerAmount), toBN('0'), {from: unlockedAccount});

        console.log("After ", await weth.balanceOf(provider.address));

        console.log("unlockedAccount: " + unlockedAccount);

        console.log("Trade Info: ", await provider.getTradeInfo(nftUniqId));

        console.log("BEFORE Owned NFT: ", await nftTokenContract.ownerOf(nftUniqId));
        console.log("BEFORE Owned DAI: ", await dai.balanceOf(unlockedAccount));
        console.log("BEFORE Owned USDC: ", await weth.balanceOf(unlockedAccount));

        await provider.closeTrade(nftUniqId, {from: unlockedAccount});

        await expectRevert(
            nftTokenContract.ownerOf(nftUniqId),
            'ERC721: owner query for nonexistent token',
        );

        console.log("AFTER Owned DAI: ", await await dai.balanceOf(unlockedAccount));
        console.log("AFTER Owned USDC: ", await await weth.balanceOf(unlockedAccount));
    });
});
