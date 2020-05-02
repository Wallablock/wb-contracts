const Migrations = artifacts.require("Migrations");
const OfferFactory = artifacts.require("OfferFactory");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(OfferFactory);
};
