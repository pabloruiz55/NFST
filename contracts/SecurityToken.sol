pragma solidity ^0.4.23;

import 'openzeppelin-solidity/contracts/token/ERC721/ERC721Token.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';

contract SecurityToken is ERC721Token, Ownable {
  bytes32 public jurisdiction = "US";
  bytes32 public regType = "Reg S";
  uint256 public defaultHoldingPeriod = 365 days;
  bool public comformsToRule144 = true;

  struct SharesData {
    string legend;
    uint256 value;
    bool restricted;
    uint256 mintDate;
    uint256 lastTransferDate;
    uint256 holdingPeriodEnd;
    bytes32 jurisdiction;
  }

  SharesData[] public shares;

  mapping (address => uint256) public sharesBalance;

  // Whitelist
  // An address can only send / receive tokens once their corresponding uint256 > block.number
  mapping (address => Shareholder) public shareholders;

  //from and to timestamps that an investor can send / receive tokens respectively
  struct Shareholder {
      uint256 sellLockupEnd;
      uint256 buyLockupEnd;
      bytes32 jurisdiction;
      bool isAffiliate;
      uint8 status;
  }

  ////////////

  constructor(string _name, string _symbol) public
  ERC721Token(_name, _symbol) {

  }

  function mint(address _shareholder, string _legend, uint256 _value, bool _restricted) public onlyOwner {
    require(verifyTransferByShareholders(address(this), _shareholder), "Transfer is not valid");
    SharesData memory _share = SharesData({
      legend: _legend,
      value: _value,
      restricted: _restricted,
      mintDate: now,
      lastTransferDate: now,
      holdingPeriodEnd: now.add(defaultHoldingPeriod),
      jurisdiction: jurisdiction
      });

    uint256 _sharesId = shares.push(_share) - 1;

    sharesBalance[_shareholder] = sharesBalance[_shareholder].add(_value);

    _mint(_shareholder, _sharesId);
  }

  // Allows issuer(owner) to change/remove restrictive legend for the selected shares
  function scrubLegendBySharesId(uint256 _sharesId, string _newLegend ) onlyOwner public {
    SharesData storage _shares = shares[_sharesId];
    _shares.legend = _newLegend;
  }

  function safeTransferFrom(address _from, address _to, uint256 _tokenId) public {
    // Check restrictions pertaining to the shareholders
    require(verifyTransferByShareholders(_from, _to), "Transfer is not valid - Whitelist");
    // Check restrictions pertaining to the shares
    require(verifyTransferByShares(_from, _to, _tokenId), "Transfer is not valid - Shares");

    // Keep total shares balances up to date across shareholders
    transferSharesBalance(_from, _to, shares[_tokenId].value);

    // Modify the shares data if necessary
    modifySharesData(_from, _to, _tokenId);

    super.safeTransferFrom(_from, _to, _tokenId);
}

  function getSharesData( uint _sharesId ) public view returns(string, uint256, bool, uint256, uint256, uint256, bytes32){
    SharesData memory _shares = shares[_sharesId];
    return (_shares.legend, _shares.value, _shares.restricted, _shares.mintDate, _shares.lastTransferDate, _shares.holdingPeriodEnd, _shares.jurisdiction);
  }

  function transferSharesBalance(address _from, address _to, uint256 _value) internal {
    sharesBalance[_from] = sharesBalance[_from].sub(_value);
    sharesBalance[_to] = sharesBalance[_to].add(_value);
  }

  ///////////////////////
  // WHITELIST Methods
  ///////////////////////

  function modifyWhitelist(
    address _shareholder,
    uint256 _sellLockupEnd,
    uint256 _buyLockupEnd,
    bytes32 _jurisdiction,
    bool _isAffiliate,
    uint8 _status
    )
    public onlyOwner {

    shareholders[_shareholder] = Shareholder(_sellLockupEnd, _buyLockupEnd, _jurisdiction, _isAffiliate, _status);
  }

  function verifyTransferByShareholders(address _from, address _to) public view returns(bool) {
    if (_from == address(this)) {
        return onWhitelist(_to) ? true : false;
    }
    //Anyone on the whitelist can transfer provided the blocknumber is large enough
    return ((onWhitelist(_from) && shareholders[_from].sellLockupEnd <= now) &&
        (onWhitelist(_to) && shareholders[_to].buyLockupEnd <= now)) ? true : false;
  }

  function verifyTransferByShares(address _from, address _to, uint256 _sharesId) public view returns(bool) {
    SharesData memory _shares = shares[_sharesId];

    if(_shares.restricted){
      if(now < _shares.holdingPeriodEnd)
        return false;
    }
    return true;
  }

  function modifySharesData (address _from, address _to, uint256 _sharesId) internal {
    SharesData storage _shares = shares[_sharesId];
    Shareholder memory _shareholderFrom = shareholders[_from];
    Shareholder memory _shareholderTo = shareholders[_to];

    //If Rule144 is active
    if(comformsToRule144){
      // According to US regulation, Rule 144 if a non-Affiliate buys shares from an Affiliate,
      // the get restricted shares even if they were not restricted under the Affiliate
      if(_shareholderFrom.isAffiliate && !_shareholderTo.isAffiliate){
        _shares.restricted = true;
        _shares.holdingPeriodEnd = now.add(defaultHoldingPeriod);
      }
    }

    _shares.lastTransferDate = now;

  }



  function onWhitelist(address _shareholder) internal view returns(bool) {
    return (shareholders[_shareholder].status == 1);
  }


}
