const Migrations = artifacts.require("Migrations");
const OfferRegistry = artifacts.require("OfferRegistry");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(OfferRegistry);
};
