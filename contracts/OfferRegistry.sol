pragma solidity >= 0.5.0 < 0.7.0;

contract OfferRegistry {
    event Created(
        address indexed offer,
        address indexed seller,
        string title,
        uint256 price,
        string category,
        bytes3 shipsFrom,
        string attachedFiles
    );

    event TitleChanged(
        address indexed offer,
        string newTitle
    );

    event PriceChanged(
        address indexed offer,
        uint256 newPrice
    );

    event CategoryChanged(
        address indexed offer,
        string newCategory
    );

    event ShipsFromChanged(
        address indexed offer,
        bytes3 newShipsFrom
    );

    event AttachedFilesChanged(
        address indexed offer,
        string indexed newCID,
        string indexed oldCID
    );

    event Bought(
        address indexed offer,
        address indexed buyer
    );

    event BuyerRejected(address indexed offer);

    event Completed(address indexed offer);

    event Cancelled(address indexed offer);

    function notifyCreation(
        address seller,
        string calldata title,
        uint256 price,
        string calldata category,
        bytes3 shipsFrom,
        string calldata attachedFiles
    ) external {
        emit Created(
            msg.sender,
            seller,
            title,
            price,
            category,
            shipsFrom,
            attachedFiles
        );
    }

    function notifyTitleChange(string calldata newTitle) external {
        emit TitleChanged(msg.sender, newTitle);
    }

    function notifyPriceChange(uint256 newPrice) external {
        emit PriceChanged(msg.sender, newPrice);
    }

    function notifyCategoryChange(string calldata newCategory) external {
        emit CategoryChanged(msg.sender, newCategory);
    }

    function notifyShipsFromChange(bytes3 newShipsFrom) external {
        emit ShipsFromChanged(msg.sender, newShipsFrom);
    }

    function notifyAttachedFilesChange(string calldata newCID, string calldata oldCID) external {
        emit AttachedFilesChanged(msg.sender, newCID, oldCID);
    }

    function notifyPurchase(address buyer) external {
        emit Bought(msg.sender, buyer);
    }

    function notifyBuyerRejection() external {
        emit BuyerRejected(msg.sender);
    }

    function notifyCompletion() external {
        emit Completed(msg.sender);
    }

    function notifyCancellation() external {
        emit Cancelled(msg.sender);
    }
}
