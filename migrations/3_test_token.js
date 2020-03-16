const ERC20Token = artifacts.require("ERC20Token");

module.exports = function (deployer, network) {
  console.log('network ', network);
  if (network != 'development') {
    return;
  }
  deployer.deploy(ERC20Token);
};
