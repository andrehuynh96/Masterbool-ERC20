const Locking = artifacts.require("Locking");

module.exports = function(deployer) {
  deployer.deploy(Locking);
};
