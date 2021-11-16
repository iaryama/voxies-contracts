pragma solidity 0.8.4;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./utils/AccessProtected.sol";
// import "./utils/BaseRelayRecipient.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/** @title Loaning NFT. */
contract Loan is AccessProtected {
    using SafeMath for uint256;
    using Address for address;
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    Counters.Counter private _tokenIds;

    mapping(address => mapping(uint256 => bool)) private _isBundled;

    IERC20 public token;

    struct LoanableItem {
        address nftAddress;
        address owner;
        address loanee;
        bool isActive;
        uint256[] tokenIds;
        uint256 upfrontFee;
        uint8 percentageRewards;
        uint256 timePeriod;
        uint256 earnedRewards;
        uint256 startingTime;
    }

    mapping(uint256 => LoanableItem) public loanItems;

    mapping(address => bool) public allowedNFT;

    event LoanableItemCreated(address, address to, uint256[] lockedNFT, uint256 itemId);

    event LoanIssued(address loanee);

    constructor(address[] memory nftAddresses, IERC20 _token) {
        require(address(_token) != address(0), "ZERO_ADDRESS");
        for (uint256 i = 0; i < nftAddresses.length; i++) {
            require(nftAddresses[i].isContract(), "Given NFT Address must be a contract");
            allowedNFT[nftAddresses[i]] = true;
        }
        token = _token;
    }

    function addAllowedNFT(address nftAddress, bool enabled) external onlyAdmin {
        allowedNFT[nftAddress] = enabled;
    }

    function createLoanableItem(
        address nftAddress,
        uint256[] calldata tokenIds,
        uint256 upfrontFee,
        uint8 percentageRewards,
        uint256 timePeriod
    ) external returns (uint256) {
        require(allowedNFT[nftAddress], "Can't accept tokens from the given NFT contract address");
        require(percentageRewards < 100, "Percentage cannot be more than 100");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(!_isBundled[nftAddress][tokenIds[i]], "Loan Bundle exits with the given NFT");
            address nftOwner = IERC721(nftAddress).ownerOf(tokenIds[i]);
            require(_msgSender() == nftOwner, "Sender is not the owner of given NFT");
            IERC721(nftAddress).transferFrom(nftOwner, address(this), tokenIds[i]);
        }
        LoanableItem memory loanItem = LoanableItem(
            nftAddress,
            _msgSender(),
            address(0),
            false,
            tokenIds,
            upfrontFee,
            percentageRewards,
            timePeriod,
            0,
            0
        );
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        loanItems[newTokenId] = loanItem;
        return newTokenId;
    }

    // function updateLoanableItem(uint256 loanId) external {
    // }

    function issueLoan(uint256 _loanId) external {
        require(loanItems[_loanId].timePeriod > 0, "Loanable Item Not Found");
        if (loanItems[_loanId].upfrontFee != 0) {
            token.safeTransferFrom(msg.sender, address(this), loanItems[_loanId].upfrontFee);
        }
        loanItems[_loanId].loanee = _msgSender();
        loanItems[_loanId].isActive = true;
        loanItems[_loanId].startingTime = block.timestamp;
    }

    function addRewardsForNFT(
        address _nftAddress,
        uint256[] memory _nftIds,
        uint256[] memory _amounts,
        uint256 loanId
    ) external onlyOwner {
        require(allowedNFT[_nftAddress], "Can't accept tokens from the given NFT contract address");
        require(_nftIds.length == _amounts.length, "winners.length != _amounts.length");
        for (uint256 i = 0; i < _nftIds.length; i++) {
            require(IERC721(_nftAddress).ownerOf(_nftIds[i]) != address(0), "Given NFT Id doesn't exits");
            token.safeTransferFrom(owner(), address(this), _amounts[i]);
            loanItems[loanId].earnedRewards.add(_amounts[i]);
        }
    }

    function claimRewards(uint256 _loanId) external {
        require(_msgSender() == loanItems[_loanId].owner || _msgSender() == loanItems[_loanId].loanee);
        uint256 rewards = 0;
        if (loanItems[_loanId].percentageRewards != 0) {
            if (_msgSender() == loanItems[_loanId].loanee) {
                uint256 percentage = uint256(100).sub(loanItems[_loanId].percentageRewards);
                rewards = loanItems[_loanId].earnedRewards.mul(percentage).div(100);
            } else {
                rewards = loanItems[_loanId].earnedRewards.mul(loanItems[_loanId].percentageRewards).div(100);
            }
        } else {
            rewards = loanItems[_loanId].earnedRewards;
        }
        loanItems[_loanId].earnedRewards.sub(rewards);
        token.safeTransfer(_msgSender(), rewards);
    }

    function claimNFTs(uint256 _loanId) external {
        require(_msgSender() == loanItems[_loanId].owner, "Sender is not the owner of NFTs");
        require(
            (block.timestamp - loanItems[_loanId].startingTime) > loanItems[_loanId].timePeriod,
            "Loan is still active"
        );
        for (uint256 i = 0; i < loanItems[_loanId].tokenIds.length; i++) {
            IERC721(loanItems[_loanId].nftAddress).safeTransferFrom(
                address(this),
                loanItems[_loanId].owner,
                loanItems[_loanId].tokenIds[i]
            );
        }
        delete loanItems[_loanId];
    }

    modifier isNFTOwner(address nftAddress, uint256[] calldata tokenIds) {
        require(allowedNFT[nftAddress], "Can't accept tokens from the given NFT contract");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(_msgSender() == IERC721(nftAddress).ownerOf(tokenIds[i]), "");
        }
        _;
    }

    // function setTrustedForwarder(address _trustedForwarder) external onlyAdmin {
    //     trustedForwarder = _trustedForwarder;
    // }

    // function _msgSender() internal view override(Context, BaseRelayRecipient) returns (address payable) {
    //     return BaseRelayRecipient._msgSender();
    // }
}
