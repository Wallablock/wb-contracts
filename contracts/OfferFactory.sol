pragma solidity >= 0.5.0 < 0.7.0;

import "./Offer.sol";

contract OfferFactory {
  constructor() public {
  }

  function createOffer(
    bytes calldata sellerKey,
    uint256 price,
    string calldata title,
    string calldata category,
    bytes3 shipsFrom
  ) external payable {
    (new Offer).value(msg.value)(
      msg.sender,
      sellerKey,
      price,
      title,
      category,
      shipsFrom
    );
  }
}
