const SecurityToken = artifacts.require("SecurityToken");

function latestTime () {
    return web3.eth.getBlock('latest').timestamp;
  }

let account_issuer;
let account_shareholder1;
let account_shareholder2;
let sharesMinted;

contract("SecurityToken", accounts => {

  before(async() => {
    // Accounts setup
    account_issuer = accounts[0];
    account_shareholder1 = accounts[1];
    account_shareholder2 = accounts[2];

    instance = await SecurityToken.deployed();

  });

  describe("add to whitelist", () => {
    it("it whitelists account_shareholders", async () => {

      let transaction = await instance.modifyWhitelist(account_shareholder1,latestTime(),latestTime(), "US", true,1);
      let transaction2 = await instance.modifyWhitelist(account_shareholder2,latestTime(),latestTime(), "US", true,1);
    });
  });

  describe("mint", () => {
    it("creates token with specified parameters", async () => {


      sharesMinted = await instance.mint(account_shareholder1,"Some legend with transfer restrictions", 1000, true);
      await instance.mint(account_shareholder1,"Some legend with transfer restrictions", 700, true);
      await instance.mint(account_shareholder1,"Some legend with transfer restrictions", 200, true);

      let shares = await instance.tokenOfOwnerByIndex(account_shareholder1,0);
      let sharesData = await instance.getSharesData(shares);

      let sharesBalance = await instance.sharesBalance(account_shareholder1);
      console.log("Shareholder 1 shares balance:", sharesBalance.toNumber());
      assert.equal(sharesData[0], "Some legend with transfer restrictions");
    });
  });

  describe("scrubLegendBySharesId", () => {
    it("removes restrictive legend", async () => {

      let scrubTransaction = await instance.scrubLegendBySharesId(0,"");

      let shares = await instance.tokenOfOwnerByIndex(account_shareholder1,0);
      let sharesData = await instance.getSharesData(shares);
      assert.equal(sharesData[0], "");
    });
  });

  describe("transfer shares", () => {
    it("it transfers the shares to another account", async () => {
      let shareholder = await instance.ownerOf(0);

      let transferTransaction = await instance.safeTransferFrom(shareholder, account_shareholder2, 0, {from:account_shareholder1});

      let shares = await instance.tokenOfOwnerByIndex(account_shareholder2,0);
      let sharesData = await instance.getSharesData(shares);

      let newShareholder = await instance.ownerOf(0);

      let sharesBalance = await instance.sharesBalance(account_shareholder1);
      console.log("Shareholder 1 shares balance:", sharesBalance.toNumber());

      assert.equal(newShareholder, account_shareholder2);
    });
  });
});
