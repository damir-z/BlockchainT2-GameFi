// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title RentalVault
/// @notice Pull-payment rental vault for ERC-1155 game items. Rented items stay escrowed.
contract RentalVault is ERC1155Holder, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant FEE_SETTER_ROLE = keccak256("FEE_SETTER_ROLE");
    uint16 public constant MAX_FEE_BPS = 1_000;
    uint16 public constant BPS = 10_000;

    enum ListingState {
        None,
        Listed,
        Rented,
        Closed
    }

    struct Listing {
        address lender;
        uint256 tokenId;
        uint256 amount;
        uint256 priceWei;
        uint64 period;
        ListingState state;
        address renter;
        uint64 expiresAt;
    }

    IERC1155 public immutable itemToken;
    uint256 public nextListingId;
    uint16 public feeBps;
    address public feeRecipient;
    mapping(uint256 => Listing) public listings;
    mapping(address => uint256) public pendingWithdrawals;

    event Listed(uint256 indexed listingId, address indexed lender, uint256 indexed tokenId, uint256 amount, uint256 priceWei, uint64 period);
    event Rented(uint256 indexed listingId, address indexed renter, uint64 expiresAt);
    event RentalFinished(uint256 indexed listingId);
    event ListingWithdrawn(uint256 indexed listingId, address indexed lender);
    event EarningsClaimed(address indexed account, uint256 amount);
    event FeeConfigUpdated(address indexed feeRecipient, uint16 feeBps);

    constructor(address admin, IERC1155 itemToken_, address feeRecipient_, uint16 feeBps_) {
        require(admin != address(0), "RentalVault: zero admin");
        require(address(itemToken_) != address(0), "RentalVault: zero token");
        require(feeRecipient_ != address(0), "RentalVault: zero recipient");
        require(feeBps_ <= MAX_FEE_BPS, "RentalVault: fee too high");

        itemToken = itemToken_;
        feeRecipient = feeRecipient_;
        feeBps = feeBps_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(FEE_SETTER_ROLE, admin);
    }

    function list(uint256 tokenId, uint256 amount, uint256 priceWei, uint64 period)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 listingId)
    {
        require(amount != 0, "RentalVault: zero amount");
        require(priceWei != 0, "RentalVault: zero price");
        require(period >= 1 hours, "RentalVault: period too short");

        listingId = ++nextListingId;
        listings[listingId] = Listing({
            lender: msg.sender,
            tokenId: tokenId,
            amount: amount,
            priceWei: priceWei,
            period: period,
            state: ListingState.Listed,
            renter: address(0),
            expiresAt: 0
        });

        itemToken.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        emit Listed(listingId, msg.sender, tokenId, amount, priceWei, period);
    }

    function rent(uint256 listingId) external payable nonReentrant whenNotPaused {
        Listing storage listing = listings[listingId];
        require(listing.state == ListingState.Listed, "RentalVault: not listed");
        require(msg.value == listing.priceWei, "RentalVault: wrong payment");

        uint256 fee = (msg.value * feeBps) / BPS;
        uint256 lenderAmount = msg.value - fee;

        listing.state = ListingState.Rented;
        listing.renter = msg.sender;
        listing.expiresAt = uint64(block.timestamp + listing.period);

        pendingWithdrawals[listing.lender] += lenderAmount;
        pendingWithdrawals[feeRecipient] += fee;

        emit Rented(listingId, msg.sender, listing.expiresAt);
    }

    function finishRental(uint256 listingId) public whenNotPaused {
        Listing storage listing = listings[listingId];
        require(listing.state == ListingState.Rented, "RentalVault: not rented");
        require(block.timestamp >= listing.expiresAt, "RentalVault: rental active");
        listing.state = ListingState.Listed;
        listing.renter = address(0);
        listing.expiresAt = 0;
        emit RentalFinished(listingId);
    }

    function withdrawListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.lender == msg.sender, "RentalVault: not lender");
        if (listing.state == ListingState.Rented) {
            require(block.timestamp >= listing.expiresAt, "RentalVault: rental active");
            listing.state = ListingState.Listed;
            listing.renter = address(0);
            listing.expiresAt = 0;
        }
        require(listing.state == ListingState.Listed, "RentalVault: not withdrawable");
        listing.state = ListingState.Closed;
        itemToken.safeTransferFrom(address(this), msg.sender, listing.tokenId, listing.amount, "");
        emit ListingWithdrawn(listingId, msg.sender);
    }

    function claimEarnings() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount != 0, "RentalVault: nothing to claim");
        pendingWithdrawals[msg.sender] = 0;
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "RentalVault: ETH transfer failed");
        emit EarningsClaimed(msg.sender, amount);
    }

    function setFeeConfig(address newFeeRecipient, uint16 newFeeBps) external onlyRole(FEE_SETTER_ROLE) {
        require(newFeeRecipient != address(0), "RentalVault: zero recipient");
        require(newFeeBps <= MAX_FEE_BPS, "RentalVault: fee too high");
        feeRecipient = newFeeRecipient;
        feeBps = newFeeBps;
        emit FeeConfigUpdated(newFeeRecipient, newFeeBps);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    receive() external payable {
        pendingWithdrawals[feeRecipient] += msg.value;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Receiver, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
