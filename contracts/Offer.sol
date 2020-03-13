pragma solidity >=0.4.21 <0.7.0;

contract Offer {
    // Config:
    uint256 public constant MIN_PRICE = 0 ether; // price >= MIN_PRICE
    uint public constant SELLER_DEPOSIT_MULTIPLIER = 2;
    uint public constant BUYER_DEPOSIT_MULTIPLIER = 1;

    enum State {
        WAITING_BUYER,
        PENDING_CONFIRMATION,
        COMPLETED,
        CANCELLED
    }

    State public currentStatus;
    address payable public seller;
    address payable public buyer;
    uint256 public price;
    string public title;
    string public attachedFiles;
    bytes public contactInfo;
    mapping(address => uint256) public pendingWithdrawals;

    event Created(address indexed seller, string title, uint256 price);
    event TitleUpdated(string oldTitle, string newTitle);
    event Bought(address indexed buyer);
    event BuyerRejected(address oldBuyer);
    event ChangedIPFSFiles(string oldCID, string newCID);
    event ChangedPrice(uint256 oldPrice, uint256 newPrice);
    event Completed();
    event Cancelled();

    constructor(uint256 newPrice, string memory newTitle) public payable {
        assert(BUYER_DEPOSIT_MULTIPLIER > 0);
        assert(SELLER_DEPOSIT_MULTIPLIER > 0);
        require(newPrice >= MIN_PRICE, "Price too small");
        uint256 deposit = SELLER_DEPOSIT_MULTIPLIER * newPrice;
        require(deposit >= newPrice, "Price too big");
        require(msg.value == deposit, "Invalid deposit");
        require(bytes(newTitle).length > 0, "A title is required");
        seller = msg.sender;
        price = newPrice;
        title = newTitle;
        currentStatus = State.WAITING_BUYER;
        emit Created(seller, newTitle, newPrice);
    }

    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        pendingWithdrawals[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    function setIpfsCid(string memory newCID) public {
        require(msg.sender == seller, "Only sender can modify attached files");
        string memory oldCID = attachedFiles;
        attachedFiles = newCID;
        emit ChangedIPFSFiles(oldCID, newCID);
    }

    function setPrice(uint256 newPrice) public payable {
        require(currentStatus == State.WAITING_BUYER, "Can't change price in current status");
        uint256 oldPrice = price;
        require(msg.sender == seller, "Only seller can change price");
        require(newPrice >= MIN_PRICE, "Price too small");
        uint256 newDeposit = 2 * newPrice;
        require(newDeposit >= newPrice, "Price too big");
        uint256 oldDeposit = 2 * oldPrice;
        assert(newDeposit != oldDeposit);
        if (newDeposit > oldDeposit) {
            require(msg.value == newDeposit - oldDeposit, "Invalid deposit");
        } else if (newDeposit < oldDeposit) {
            require(msg.value == 0, "Invalid deposit");
            payTo(seller, oldDeposit - newDeposit);
        } else {
            assert(newPrice == oldPrice);
            return; // Avoid emmiting event
        }
        price = newPrice;
        emit ChangedPrice(oldPrice, newPrice);
    }

    function setTitle(string memory newTitle) public {
        require(msg.sender == seller, "Only seller can modify title");
        require(
            currentStatus == State.WAITING_BUYER,
            "Title can only be modified before a purchase"
        );
        require(bytes(newTitle).length > 0, "A title is required");
        string memory oldTitle = title;
        title = newTitle;
        emit TitleUpdated(oldTitle, newTitle);
    }

    function buy(bytes memory newContactInfo) public payable {
        require(currentStatus == State.WAITING_BUYER, "Can't buy in current status");
        require(msg.sender != seller, "Seller can't self-buy");
        require(msg.value == buyerDepositWithPayment(), "Invalid deposit");
        buyer = msg.sender;
        currentStatus = State.PENDING_CONFIRMATION;
        contactInfo = newContactInfo;
        emit Bought(buyer);
    }

    function confirm() public {
        require(currentStatus == State.PENDING_CONFIRMATION, "Can't confirm in current status");
        require(msg.sender == buyer, "Only buyer can confirm");
        payTo(seller, sellerDepositWithPayment());
        payTo(buyer, buyerDeposit());
        currentStatus = State.COMPLETED;
        emit Completed();
    }

    function rejectBuyer() public {
        require(currentStatus == State.PENDING_CONFIRMATION, "Can't reject buyer in current status");
        require(msg.sender == seller, "Only seller can reject buyer");
        payTo(buyer, buyerDepositWithPayment());
        address oldBuyer = buyer;
        delete buyer;
        delete contactInfo;
        currentStatus = State.WAITING_BUYER;
        emit BuyerRejected(oldBuyer);
    }

    function cancel() public {
        require(currentStatus == State.WAITING_BUYER || currentStatus == State.PENDING_CONFIRMATION, "Can't cancel in current status");
        require(msg.sender == seller, "Only seller can cancel");
        payTo(seller, sellerDeposit());
        if (currentStatus == State.PENDING_CONFIRMATION) {
            rejectBuyer();
        }
        currentStatus = State.CANCELLED;
        emit Cancelled();
    }

    function buyerDeposit() public view returns (uint256) {
        return price * BUYER_DEPOSIT_MULTIPLIER;
    }

    function sellerDeposit() public view returns (uint256) {
        return price * SELLER_DEPOSIT_MULTIPLIER;
    }

    function buyerDepositWithPayment() public view returns (uint256) {
        return price * (BUYER_DEPOSIT_MULTIPLIER + 1);
    }

    function sellerDepositWithPayment() public view returns (uint256) {
        return price * (SELLER_DEPOSIT_MULTIPLIER + 1);
    }

    function payTo(address to, uint256 amount) private {
        pendingWithdrawals[to] += amount;
    }
}
