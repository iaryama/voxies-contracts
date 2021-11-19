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
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/** @title Loaning NFT. */
contract Loan is AccessProtected, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    Counters.Counter private _tokenIds;

    IERC20 public token;

    uint256 public maxLoanPeriod = 604800;

    uint256 public minLoanPeriod = 3600;

    mapping(address => mapping(uint256 => bool)) private _isBundled;

    mapping(address => bool) public allowedNFT;

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

    event LoanableItemCreated(address owner, uint256[] lockedNFT, uint256 itemId);

    event LoanIssued(address loanee, uint256 loanId);

    event RewardsAdded(uint256[] nftIds, uint256[] amounts, uint256 loanId);

    constructor(address[] memory _nftAddresses, IERC20 _token) {
        require(address(_token) != address(0), "ZERO_ADDRESS");
        for (uint256 i = 0; i < _nftAddresses.length; i++) {
            require(_nftAddresses[i].isContract(), "Given NFT Address must be a contract");
            allowedNFT[_nftAddresses[i]] = true;
        }
        token = _token;
    }

    function updateMaxTimePeriod(uint256 _timePeriod) external onlyAdmin {
        require(_timePeriod > 0, "Incorrect time period");
        maxLoanPeriod = _timePeriod;
    }

    function updateMinTimePeriod(uint256 _timePeriod) external onlyAdmin {
        require(_timePeriod > 0, "Incorrect time period");
        minLoanPeriod = _timePeriod;
    }

    function updateAllowedNFT(address _nftAddress, bool _enabled) external onlyAdmin {
        require(_nftAddress.isContract(), "Given NFT Address must be a contract");
        allowedNFT[_nftAddress] = _enabled;
    }

    function createLoanableItem(
        address _nftAddress,
        uint256[] calldata _nftIds,
        uint256 _upfrontFee,
        uint8 _percentageRewards,
        uint256 _timePeriod
    ) external nonReentrant returns (uint256) {
        require(allowedNFT[_nftAddress], "NFT contract address is not allowed");
        require(_percentageRewards < 100, "Percentage cannot be more than 100");
        require(_timePeriod >= minLoanPeriod && _timePeriod <= maxLoanPeriod, "Incorrect loan time period specified");
        for (uint256 i = 0; i < _nftIds.length; i++) {
            require(!_isBundled[_nftAddress][_nftIds[i]], "Loan Bundle exits with the given NFT");
            address nftOwner = IERC721(_nftAddress).ownerOf(_nftIds[i]);
            require(_msgSender() == nftOwner, "Sender is not the owner of given NFT");
        }
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        loanItems[newTokenId].nftAddress = _nftAddress;
        loanItems[newTokenId].owner = _msgSender();
        loanItems[newTokenId].tokenIds = _nftIds;
        loanItems[newTokenId].upfrontFee = _upfrontFee;
        loanItems[newTokenId].percentageRewards = _percentageRewards;
        loanItems[newTokenId].timePeriod = _timePeriod;
        for (uint256 i = 0; i < _nftIds.length; i++) {
            _isBundled[_nftAddress][_nftIds[i]] = true;
            IERC721(_nftAddress).transferFrom(_msgSender(), address(this), _nftIds[i]);
        }
        emit LoanableItemCreated(_msgSender(), _nftIds, newTokenId);
        return newTokenId;
    }

    // function _lockNFT(
    //     address _nftAddress,
    //     uint256[] calldata _nftIds,
    //     uint256 _upfrontFee,
    //     uint8 _percentageRewards,
    //     uint256 _timePeriod
    // )

    // function updateLoanableItem(uint256 loanId) external {
    // }

    function issueLoan(
        uint256 _loanId,
        address _loanee,
        uint256 _upfrontFee,
        uint8 _percentageRewards,
        uint256 _timePeriod
    ) external nonReentrant {
        require(loanItems[_loanId].timePeriod > 0, "Loanable Item Not Found");
        require(!loanItems[_loanId].isActive, "Loan Item is already loaned");
        loanItems[_loanId].upfrontFee = _upfrontFee;
        loanItems[_loanId].percentageRewards = _percentageRewards;
        loanItems[_loanId].timePeriod = _timePeriod;
        loanItems[_loanId].loanee = _loanee;
        loanItems[_loanId].isActive = true;
        loanItems[_loanId].startingTime = block.timestamp;
        if (loanItems[_loanId].upfrontFee != 0) {
            token.safeTransferFrom(_loanee, address(this), loanItems[_loanId].upfrontFee);
        }
        emit LoanIssued(_msgSender(), _loanId);
    }

    function loanItem(uint256 _loanId) external nonReentrant {
        require(loanItems[_loanId].timePeriod > 0, "Loanable Item Not Found");
        require(!loanItems[_loanId].isActive, "Loan Item is already loaned");
        loanItems[_loanId].loanee = _msgSender();
        loanItems[_loanId].isActive = true;
        loanItems[_loanId].startingTime = block.timestamp;
        if (loanItems[_loanId].upfrontFee != 0) {
            token.safeTransferFrom(_msgSender(), address(this), loanItems[_loanId].upfrontFee);
        }
        emit LoanIssued(_msgSender(), _loanId);
    }

    function addRewardsForNFT(
        address _nftAddress,
        uint256[] memory _nftIds,
        uint256[] memory _amounts,
        uint256 _loanId
    ) external onlyAdmin {
        require(_nftIds.length == _amounts.length, "winners.length != _amounts.length");
        require(allowedNFT[_nftAddress], "Cannot accept tokens from the given NFT contract address");
        require(loanItems[_loanId].isActive, "Cannot Add rewards for NFTs within an Inactive loan");
        for (uint256 i = 0; i < _nftIds.length; i++) {
            token.safeTransferFrom(_msgSender(), address(this), _amounts[i]);
            loanItems[_loanId].earnedRewards.add(_amounts[i]);
        }
        emit RewardsAdded(_nftIds, _amounts, _loanId);
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
            uint256 id = loanItems[_loanId].tokenIds[i];
            address nftAddress = loanItems[_loanId].nftAddress;
            _isBundled[nftAddress][id] = false;
            IERC721(loanItems[_loanId].nftAddress).safeTransferFrom(address(this), loanItems[_loanId].owner, id);
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
