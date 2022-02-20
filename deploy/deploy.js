const hre = require('hardhat');
const { getChainId } = hre;

module.exports = async ({ getNamedAccounts, deployments }) => {
    console.log('running deploy script');
    console.log('network id ', await getChainId());

    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    // add kovan
    const provider = await deploy(
        'CCMTProvider',
        "0x94Bc2a1C732BcAd7343B25af48385Fe76E08734f",
        "0x0000000000000000000000000000000000000000",
        {from: deployer}
    );

    console.log('CCMTProvider deployed to:', provider.address);

    if (await getChainId() !== '31337') {
        await hre.run('verify:verify', {
            address: provider.address,
        });
    }
};

// module.exports.skip = async () => true;
