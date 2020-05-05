pragma solidity >= 0.5.0 < 0.7.0;

/**
 @title An offer to exchange goods or services for Ethers.
 @author The Wallablock team
 */
contract Offer {
    // Config:
    /// @notice Minimum price for any offer.
    uint256 public constant MIN_PRICE = 0 ether;

    /**
     @notice How many times the sale price the seller will be required to deposit.
             This money will be refunded to the seller upon completion or cancellation
             of the offer.
     */
    uint public constant SELLER_DEPOSIT_MULTIPLIER = 2;

    /**
     @notice How many times the sale price the buyer will be required to deposit.
             This is in addition of the price itself. The deposit will be
             refunded to the buyer upon completion. The payment is to be refunded
             only in certain circumstances detailed on the relevant functions.
     */
    uint public constant BUYER_DEPOSIT_MULTIPLIER = 1;
    // End of config


    /**
     @notice Possible states of the current offer.
     */
    enum State {
        /// @notice The offer has been made and is awaiting a buyer to proceed.
        WAITING_BUYER,
        /// @notice The buyer has purchased this offer, and is waiting
        ///         fulfillment confirmation from the buyer.
        PENDING_CONFIRMATION,
        /// @notice The contract has been successfully completed. No further actions are possible,
        ///         other than money withdrawal.
        COMPLETED,
        /// @notice The contract has been cancelled. No further actions are possible,
        ///         other than money withdrawal.
        CANCELLED
    }


    /// @notice The current status of the contract.
    ///         This limits the operations available for this offer.
    State public currentStatus;

    uint64 public creationDate;
    uint64 public purchaseDate;
    uint64 public confirmationDate;

    /// @notice The code of the country the offer is shipping from, or "XXX" if
    ///         this does not apply. The code is the ISO 3166-1 alpha-3 code
    ///         (e.g. ESP...).
    bytes3 public shipsFrom;

    /// @notice The seller of the contract.
    address payable public seller;

    /// @notice The buyer (if any) of the contract.
    /// @dev The null address (0x0) if no buyer makes sense in the current status.
    address payable public buyer;

    /// @notice The advertised price for the offer.
    /// @dev Must be bigger or equal to the minimum price.
    uint256 public price;

    /// @notice A brief description of the offer. May not be empty.
    string public title;

    /// @notice A string identifying the category of the offer. This string should match
    ///         one of the application-defined known strings.
    string public category;


    /**
     @notice An optional IPFS CID to a directory with files (usually photos) related
             to the offer. Relevant pictures should be displayed alongside the offer.
     @dev If no files are attached, the string will be empty. Users must take into account
          that the CID may:
            a) point to an empty directory,
            b) point to an inexistent file (possibly because it has been deleted), or
            c) not be a valid CID at all.
          For (a), it should be treated the same way as the empty string: no files attached;
          for (b), an error should be shown. If the requesting user is the seller,
          they might be prompted to optionally upload the files again;
          for (c), the buyer might be shown an error and requested to correct it,
          but other viewers should silently ignore it and behave as if no files had been attached.
     */
    string public attachedFiles;

    /**
     @notice The contact information of the buyer, encrypted with the public key
             of the seller.
             *NOTE:* Due to current limitations in available libraries, it is not
             possible to encrypt and decrypt information with Ethereum key pairs.
             This limitation is expected to be lifted soon, but until then,
             information will be stored in plain text.
     @dev To decrypt it, you need the private key of the seller.
          Beyond that, the format is unspecified.
          Despite being private, anyone with access to the blockchain can read it,
          that's why it must be encrypted. The visibility is just to make it less
          convenient.
          See NOTE on notice
     */
    bytes private contactInfo;

    /// @notice A mapping of the outstanding amounts due to the accounts.
    /// @dev This is part of the Withdrawal Pattern used to avoid reentrancy attacks.
    mapping(address => uint256) public pendingWithdrawals;


    /// @notice An offer has been created.
    event Created(
        address indexed seller,
        string title,
        uint256 price,
        string category,
        bytes3 shipsFrom
    );

    /// @notice The title of the offer has been updated
    event TitleChanged(string newTitle);

    /// @notice The files attached to the offer have been updated.
    /// @dev Unlike other changes, the old CID is provided
    ///      in case it is needed to e.g. unpin old CIDs.
    event AttachedFilesChanged(string indexed newCID, string oldCID);

    /// @notice The advertised price of the offer has been changed.
    event PriceChanged(uint256 newPrice);

    /// @notice The category of the offer has been changed.
    event CategoryChanged(string newCategory);

    /// @notice This shipping country of the offer has been changed.
    event ShipsFromChanged(bytes3 newShipsFrom);

    /// @notice A buyer has purchased this offer.
    event Bought(address indexed buyer);

    /// @notice The seller has rejected a buyer.
    event BuyerRejected(address oldBuyer);

    /// @notice The offer has been completed successfully.
    event Completed();

    /// @notice The offer has been cancelled.
    event Cancelled();


    /**
     @notice Create the offer with price `newPrice` and title `newTitle`.
             The relevant deposit must be made at the same time or the creation will fail.
     @dev The ethers for the deposit must be sent with the call to the constructor.
          The value of the deposit is the proposed price times the seller multiplier.
     @param newPrice The price of the offer. Must be bigger than or equal to the minimum
                     price `MIN_PRICE`.
                     Too big of a price may cause an overflow, which will result in a failure.
     @param newTitle The title of the offer. May not be empty.
     @param newCategory The category of the offer. See: setCategory()
     @param newShipsFrom The origin shipping country for the offer. See: setShipsFrom()
     */
    constructor(
        uint256 newPrice,
        string memory newTitle,
        string memory newCategory,
        bytes3 newShipsFrom
    ) public payable {
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
        category = newCategory;
        shipsFrom = newShipsFrom;
        creationDate = uint64(now);
        currentStatus = State.WAITING_BUYER;
        emit Created(seller, newTitle, newPrice, newCategory, newShipsFrom);
    }

    /**
     @notice Call this to settle any outstanding debts has with the calling account.
     @dev Check first the pending withdrawals to avoid wasting gas. This is part of the
          Withdrawal Pattern used to avoid reentrancy attacks.
     */
    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No pending withdrawals for this address");
        pendingWithdrawals[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    /**
     @notice Get the (encrypted) buyer's contact information.
             This function may only be used by the sender or the buyer, and
             only in those states where the contact information is available
             (pending confirmation and completed).
     @dev Don't rely on these checks to protect the contact information,
          they can be bypassed by anyone with access to the blockchain;
          that's why the information must be encrypted.
     @dev While the buyer can't recover the original information, because
          that requires the seller's private key, they can compare the encrypted
          contact information.
     @return Contact information, encrypted with the sellers public key.
     */
    function getContactInfo() external view returns (bytes memory) {
        // Important note: These checks can't be enforced for nodes,
        // they only prevent contracts from actively querying the variable.
        // Reading this without passing the checks is always possible for a node
        // since it is contained within the blockchain.
        require(
            currentStatus == State.PENDING_CONFIRMATION || currentStatus == State.COMPLETED,
            "Contact information is not available for the current status"
        );
        require(
            msg.sender == seller || msg.sender == buyer,
            "Only the sender or the buyer should check the contact information"
        );
        return contactInfo;
    }

    /**
     @notice Change the attached files of the contract to point to the `newCID` directory.
     @dev The function will not check the validity of the CID in any way;
          the caller is resposible for the appropriate checks.
     @param newCID Content Identifier of the directory containing the updated files.
     */
    function setAttachedFiles(string memory newCID) public {
        require(msg.sender == seller, "Only sender can modify attached files");
        string memory oldCID = attachedFiles;
        attachedFiles = newCID;
        emit AttachedFilesChanged(newCID, oldCID);
    }

    /**
     @notice Changes the price of the offer to `newPrice`. This is only possible while the
             contract is awaiting a buyer. If the new price is greater than the current price
             (`price`), the difference in the deposit must be paid when calling this function.
             If the new price is lower, the difference in the deposit will be made
             available for withdrawal.
     @param newPrice New price to set. Must fulfill the usual conditions of the price.
     */
    function setPrice(uint256 newPrice) public payable {
        require(currentStatus == State.WAITING_BUYER, "Can't change price in current status");
        require(msg.sender == seller, "Only seller can change price");
        require(newPrice >= MIN_PRICE, "Price too small");
        uint256 newDeposit = 2 * newPrice;
        require(newDeposit >= newPrice, "Price too big");
        uint256 oldPrice = price;
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
        emit PriceChanged(newPrice);
    }

    /**
     @notice Change the title of the offer to `newTitle`.
             This is only available while the contract is awaiting a buyer.
     @param newTitle New title to be set. May not be empty.
     */
    function setTitle(string memory newTitle) public {
        require(msg.sender == seller, "Only seller can modify title");
        require(
            currentStatus == State.WAITING_BUYER,
            "Title can only be modified before a purchase"
        );
        require(bytes(newTitle).length > 0, "A title is required");
        title = newTitle;
        emit TitleChanged(newTitle);
    }

    /**
     @notice Change the category of the offer to `newCategory`.
             This is only available while the contract is awaiting a buyer.
     @param newCategory New category to be set. Should be one of the categories
                        defined by the application. Should not be empty.
     @dev Offers with an empty or unrecognised category should be classified as "Others"
          or "Uncategorised".
     */
    function setCategory(string memory newCategory) public {
        require(msg.sender == seller, "Only seller can change category");
        require(
            currentStatus == State.WAITING_BUYER,
            "Category can only be changed before a purchase"
        );
        category = newCategory;
        emit CategoryChanged(newCategory);
    }

    /**
     @notice Change the origin shipping country of the offer.
     @param newShipsFrom ISO 3166-1 alpha-3 code of the shipping country.
                         "XXX" is "Not applicable" (e.g. digital goods).
                         Other XX codes may be used by the application.
     */
    function setShipsFrom(bytes3 newShipsFrom) public {
        require(msg.sender == seller, "Only seller can change shipping country");
        require(
            currentStatus == State.WAITING_BUYER,
            "Shipping country can only be changed before a purchase"
        );
        shipsFrom = newShipsFrom;
        emit ShipsFromChanged(newShipsFrom);
    }

    /**
     @notice Buy this offer. When calling this function, the buyer must provide
             the currency to pay the deposit as well as the price of the offer.
     @dev You can use the provided views to establish the correct amount to be sent.
     @param newContactInfo The contact information that will be provided to the seller.
                           It must be encrypted with the seller's public key.
                           Beyond that, the format of the plaintext is left unspecified for now.
     */
    function buy(bytes memory newContactInfo) public payable {
        require(currentStatus == State.WAITING_BUYER, "Can't buy in current status");
        require(msg.sender != seller, "Seller can't self-buy");
        require(msg.value == buyerDepositWithPayment(), "Invalid deposit");
        buyer = msg.sender;
        contactInfo = newContactInfo;
        purchaseDate = uint64(now);
        currentStatus = State.PENDING_CONFIRMATION;
        emit Bought(buyer);
    }

    /**
     @notice Confirm that the transaction has finished satisfactorily. This will return
             their deposits to both parties and transfer the payment to the seller.
             This can only be called by the buyer, and only when the offer is pending confirmation.
     */
    function confirm() public {
        require(currentStatus == State.PENDING_CONFIRMATION, "Can't confirm in current status");
        require(msg.sender == buyer, "Only buyer can confirm");
        payTo(seller, sellerDepositWithPayment());
        payTo(buyer, buyerDeposit());
        confirmationDate = uint64(now);
        currentStatus = State.COMPLETED;
        emit Completed();
    }

    /**
     @notice Reject the buyer. This will refund them their deposit and payment, and revert
             the offer to the "awaiting buyer" state. This can only be called by the seller,
             and only when the offer is pending confirmation. If the buyer needs to withdraw
             their purchase, they may contact the seller and request their rejection, or the
             cancellation of the offer.
     */
    function rejectBuyer() public {
        require(currentStatus == State.PENDING_CONFIRMATION, "Can't reject buyer in current status");
        require(msg.sender == seller, "Only seller can reject buyer");
        payTo(buyer, buyerDepositWithPayment());
        address oldBuyer = buyer;
        delete buyer;
        delete contactInfo;
        delete purchaseDate;
        currentStatus = State.WAITING_BUYER;
        emit BuyerRejected(oldBuyer);
    }

    /**
     @notice Cancel the offer. This refunds their deposits to all parties and, should a
             buyer had been found, also refunds them the payment.
             This can only be called by the seller, on the "awaiting buyer" and
             "pending confirmation" states.
     */
    function cancel() public {
        require(
            currentStatus == State.WAITING_BUYER || currentStatus == State.PENDING_CONFIRMATION,
            "Can't cancel in current status"
        );
        require(msg.sender == seller, "Only seller can cancel");
        payTo(seller, sellerDeposit());
        if (currentStatus == State.PENDING_CONFIRMATION) {
            rejectBuyer();
        }
        currentStatus = State.CANCELLED;
        emit Cancelled();
    }

    /**
     @notice Calculate the buyer deposit. This does not depend on whether it has been
             paid, it's just a calculation function for convenience.
     @return The amount of the buyer deposit (`price * BUYER_DEPOSIT_MULTIPLIER`)
     */
    function buyerDeposit() public view returns (uint256) {
        return price * BUYER_DEPOSIT_MULTIPLIER;
    }

    /**
     @notice Calculate the seller deposit. This does not depend on whether it has been
             paid, it's just a calculation function for convenience.
     @return The amount of the seller deposit (`price * SELLER_DEPOSIT_MULTIPLIER`)
     */
    function sellerDeposit() public view returns (uint256) {
        return price * SELLER_DEPOSIT_MULTIPLIER;
    }

    /**
     @notice Calculate the (buyer deposit + payment). This is a convenience function
             to know the exact amount to be sent to the functions that require it.
     @return The amount of the buyer deposit plus the playment (`buyerDeposit() + price`)
     */
    function buyerDepositWithPayment() public view returns (uint256) {
        return price * (BUYER_DEPOSIT_MULTIPLIER + 1);
    }

    /**
     @notice Calculate the (buyer deposit + payment). This is a convenience function
             to know the exact amount to be sent to the functions that require it.
     @return The amount of the buyer deposit plus the playment (`sellerDeposit() + price`)
     */
    function sellerDepositWithPayment() public view returns (uint256) {
        return price * (SELLER_DEPOSIT_MULTIPLIER + 1);
    }

    /**
     @notice Add to the pending withdrawals of `to` an ether debt of `amount`,
             to be collected with the function withdraw().
     @dev This is part of the Withdrawal Pattern used to avoid reentrancy attacks.
     */
    function payTo(address to, uint256 amount) private {
        pendingWithdrawals[to] += amount;
    }
}
