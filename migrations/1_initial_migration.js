const CoinStreamer = artifacts.require("CoinStreamer");

module.exports = async function (deployer) {

  await deployer.deploy(CoinStreamer, "0x02777053d6764996e594c3E88AF1D58D5363a2e6");

  const saleInstance = await CoinStreamer.deployed();

  console.log("CoinStreamer deployed at:", saleInstance.address);
};
