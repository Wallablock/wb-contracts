pragma solidity >= 0.5.0 < 0.7.0;

/// Proxy contract to test Offers with a client which does not support
/// constructors with parameters. DO NOT USE IN PRODUCTION

import { Offer } from "./Offer.sol";
import { OfferRegistry } from "./OfferRegistry.sol";

contract OfferProxy {
    OfferRegistry public constant registry = OfferRegistry(0xBEdE95C1e94434cF2F2897Bbf67EFE91F636E6D1);

    address payable public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can execute this action");
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function() external payable {}

    function deploy(
        uint256 newPrice,
        string calldata newTitle,
        string calldata newCategory,
        bytes3 newShipsFrom,
        string calldata newAttachedFiles
    ) external payable onlyOwner returns(Offer) {
        return (new Offer).value(msg.value)(
            registry,
            newPrice,
            newTitle,
            newCategory,
            newShipsFrom,
            newAttachedFiles
        );
    }

    function getContactInfo(Offer offer) external view  onlyOwner returns (bytes memory) {
        return offer.getContactInfo();
    }

    function setPrice(Offer offer, uint256 newPrice) external payable onlyOwner {
        offer.setPrice.value(msg.value)(newPrice);
    }

    function setTitle(Offer offer, string calldata newTitle) external onlyOwner {
        offer.setTitle(newTitle);
    }

    function setCategory(Offer offer, string calldata newCategory) external onlyOwner {
        offer.setCategory(newCategory);
    }

    function setShipsFrom(Offer offer, bytes3 newShipsFrom) external onlyOwner {
        offer.setShipsFrom(newShipsFrom);
    }

    function setAttachedFiles(Offer offer, string calldata newAttachedFiles) external onlyOwner {
        offer.setAttachedFiles(newAttachedFiles);
    }

    function rejectBuyer(Offer offer) external onlyOwner {
        offer.rejectBuyer();
    }

    function cancel(Offer offer) external onlyOwner {
        offer.cancel();
    }

    function askWithdraw(Offer offer) external onlyOwner {
        if (offer.pendingWithdrawals(address(this)) > 0) {
            offer.withdraw();
        }
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            owner.transfer(balance);
        }
    }
}
