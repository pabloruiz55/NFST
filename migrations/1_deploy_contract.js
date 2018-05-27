var SecurityToken = artifacts.require("SecurityToken");

module.exports = async (deployer, network) => {
    deployer.deploy(SecurityToken,"NFSecurityToken","NFST");
};
