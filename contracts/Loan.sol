pragma solidity 0.8.4;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./utils/AccessProtected.sol";
import "./utils/BaseRelayRecipient.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/** @title Loaning NFT. */
contract Loan is AccessProtected, ReentrancyGuard, BaseRelayRecipient {
    using SafeMath for uint256;
    using Address for address;
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    Counters.Counter private _tokenIds;

    IERC20 public token;

    uint256 public maxLoanPeriod = 604800;

    uint256 public minLoanPeriod = 3600;

    mapping(address => mapping(uint256 => uint256)) private _nftToBundleId;

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

    event RewardsAdded(uint256[] nftIds, uint256[] amounts);

    event RewardsDisbursed(uint256 loanerRewards, uint256 loaneeRewards, uint256 loanId);

    constructor(address[] memory _nftAddresses, IERC20 _token) {
        require(address(_token) != address(0), "ZERO_ADDRESS");
        for (uint256 i = 0; i < _nftAddresses.length; i++) {
            require(_nftAddresses[i].isContract(), "Given NFT Address must be a contract");
            allowedNFT[_nftAddresses[i]] = true;
        }
        token = _token;
    }

    /**
     * Updates Maximum allowed time period
     *
     * @param _timePeriod - epoch time value
     */

    function updateMaxTimePeriod(uint256 _timePeriod) external onlyAdmin {
        require(_timePeriod > 0, "Incorrect time period");
        maxLoanPeriod = _timePeriod;
    }

    /**
     * Updates Minimum allowed time period
     *
     * @param _timePeriod - epoch time value
     */

    function updateMinTimePeriod(uint256 _timePeriod) external onlyAdmin {
        require(_timePeriod > 0, "Incorrect time period");
        minLoanPeriod = _timePeriod;
    }

    /**
     * Updates Allowed NFT contract addresses
     *
     * @param _nftAddress - ERC721 contract address
     * @param _enabled - Enable/Disable
     */

    function updateAllowedNFT(address _nftAddress, bool _enabled) external onlyAdmin {
        require(_nftAddress.isContract(), "Given NFT Address must be a contract");
        allowedNFT[_nftAddress] = _enabled;
    }

    /**
     * Checks whether NFT id is part of any bundle
     *
     * @param _nftAddress - ERC721 contract address
     * @param _nftId - NFT id
     */

    function _isBundled(address _nftAddress, uint256 _nftId) internal view returns (bool) {
        require(allowedNFT[_nftAddress], "NFT contract address is not allowed");
        return (_nftToBundleId[_nftAddress][_nftId] > 0);
    }

    /**
     * Checks whether sender has access to given NFT id
     *
     * @param _nftAddress - ERC721 contract address
     * @param _nftId - NFT id
     */

    function _hasAccess(address _nftAddress, uint256 _nftId) internal view returns (bool) {
        require(allowedNFT[_nftAddress], "NFT contract address is not allowed");
        require(_nftToBundleId[_nftAddress][_nftId] > 0, "NFT is not bundled as a Loanable Item");
        uint256 loanId = _nftToBundleId[_nftAddress][_nftId];
        if (loanItems[loanId].isActive) {
            return (_msgSender() == loanItems[loanId].loanee);
        } else {
            return (_msgSender() == loanItems[loanId].owner);
        }
    }

    /**
     * Listing a Loanable item
     *
     * @param _nftAddress - ERC721 contract address
     * @param _nftIds - List of NFT ids
     * @param _upfrontFee - Upfront fee to loan item
     * @param _percentageRewards - Percentage of earned rewards
     * @param _timePeriod - Duration of the loan
     */

    function createLoanableItem(
        address _nftAddress,
        uint256[] calldata _nftIds,
        uint256 _upfrontFee,
        uint8 _percentageRewards,
        uint256 _timePeriod
    ) external nonReentrant returns (uint256) {
        require(allowedNFT[_nftAddress], "NFT contract address is not allowed");
        require(_nftIds.length > 0, "Atleast one NFT should be part of loanable Item");
        require(_percentageRewards < 100, "Percentage cannot be more than 100");
        require(_timePeriod >= minLoanPeriod && _timePeriod <= maxLoanPeriod, "Incorrect loan time period specified");
        for (uint256 i = 0; i < _nftIds.length; i++) {
            require(_nftToBundleId[_nftAddress][_nftIds[i]] == 0, "Loan Bundle exits with the given NFT");
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
            _nftToBundleId[_nftAddress][_nftIds[i]] = newTokenId;
            IERC721(_nftAddress).transferFrom(_msgSender(), address(this), _nftIds[i]);
        }
        emit LoanableItemCreated(_msgSender(), _nftIds, newTokenId);
        return newTokenId;
    }

    // function updateLoanableItem(uint256 loanId) external {
    // }

    /**
     * Loanee can loan an Item
     *
     * @param _loanId - Id of the loanable item
     * @param _loanee - Whoever is willing to loa_loanIdn item
     * @param _upfrontFee - Upfront fee to loan item
     * @param _percentageRewards - Percentage of earned rewards
     * @param _timePeriod - Duration of the loan
     */

    function issueLoan(
        uint256 _loanId,
        address _loanee,
        uint256 _upfrontFee,
        uint8 _percentageRewards,
        uint256 _timePeriod
    ) external nonReentrant {
        require(loanItems[_loanId].owner == _msgSender(), "Only loan owner can issue loan");
        require(_msgSender() != _loanee, "loaner cannot be loanee");
        require(!loanItems[_loanId].isActive, "Loan Item is already loaned");
        loanItems[_loanId].upfrontFee = _upfrontFee;
        loanItems[_loanId].percentageRewards = _percentageRewards;
        loanItems[_loanId].timePeriod = _timePeriod;
        loanItems[_loanId].loanee = _loanee;
        loanItems[_loanId].isActive = true;
        loanItems[_loanId].startingTime = block.timestamp;
        if (loanItems[_loanId].upfrontFee != 0) {
            token.safeTransferFrom(_loanee, loanItems[_loanId].owner, loanItems[_loanId].upfrontFee);
        }
        emit LoanIssued(_msgSender(), _loanId);
    }

    /**
     * Loanee can loan an Item
     *
     * @param _loanId - Id of the loanable item
     */

    function loanItem(uint256 _loanId) external nonReentrant {
        require(loanItems[_loanId].owner != address(0), "Loanable Item Not Found");
        require(_msgSender() != loanItems[_loanId].owner, "loaner cannot be loanee");
        require(!loanItems[_loanId].isActive, "Loan Item is already loaned");
        loanItems[_loanId].loanee = _msgSender();
        loanItems[_loanId].isActive = true;
        loanItems[_loanId].startingTime = block.timestamp;
        if (loanItems[_loanId].upfrontFee != 0) {
            token.safeTransferFrom(_msgSender(), loanItems[_loanId].owner, loanItems[_loanId].upfrontFee);
        }
        emit LoanIssued(_msgSender(), _loanId);
    }

    /**
     * Admin can Add Rewards on NFTs
     *
     * @param _nftAddress - ERC721 contract address
     * @param _nftIds - List of NFT ids
     * @param _amounts - List of Amounts.
     */

    function addRewardsForNFT(
        address _nftAddress,
        uint256[] memory _nftIds,
        uint256[] memory _amounts
    ) external onlyAdmin nonReentrant {
        require(_nftIds.length > 0, "Invalid number of NFTs");
        require(_nftIds.length == _amounts.length, "winners.length != _amounts.length");
        require(allowedNFT[_nftAddress], "Cannot accept tokens from the given NFT contract address");
        for (uint256 i = 0; i < _nftIds.length; i++) {
            uint256 _loanId = _nftToBundleId[_nftAddress][_nftIds[i]];
            require(loanItems[_loanId].owner != address(0), "Loanable Item Not Found");
            if (loanItems[_loanId].isActive) {
                loanItems[_loanId].earnedRewards = loanItems[_loanId].earnedRewards.add(_amounts[i]);
                token.safeTransferFrom(_msgSender(), address(this), _amounts[i]);
            } else {
                token.safeTransferFrom(_msgSender(), loanItems[_loanId].owner, _amounts[i]);
            }
        }
        emit RewardsAdded(_nftIds, _amounts);
    }

    /**
     * Claim Rewards
     *
     * @param _loanId - Id of the loaned item
     *
     */
    function claimRewards(uint256 _loanId) public nonReentrant {
        require(_msgSender() == loanItems[_loanId].owner || _msgSender() == loanItems[_loanId].loanee);
        require(loanItems[_loanId].earnedRewards > 0, "No rewards found for given LoanId");
        uint256 loanerRewards = 0;
        uint256 loaneeRewards = 0;
        loanerRewards = loanItems[_loanId].earnedRewards.mul(loanItems[_loanId].percentageRewards).div(100);
        loaneeRewards = loanItems[_loanId].earnedRewards.sub(loanerRewards);
        loanItems[_loanId].earnedRewards = 0;
        token.safeTransfer(loanItems[_loanId].owner, loanerRewards);
        token.safeTransfer(loanItems[_loanId].loanee, loaneeRewards);
        emit RewardsDisbursed(loanerRewards, loaneeRewards, _loanId);
    }

    /**
     * Claim NFT
     *
     * @param _loanId - Id of the loaned item
     *
     */
    function claimNFTs(uint256 _loanId) external nonReentrant {
        require(_msgSender() == loanItems[_loanId].owner, "Sender is not the owner of NFTs");
        require(
            (block.timestamp - loanItems[_loanId].startingTime) >= loanItems[_loanId].timePeriod,
            "Loan period is still active "
        );
        for (uint256 i = 0; i < loanItems[_loanId].tokenIds.length; i++) {
            uint256 id = loanItems[_loanId].tokenIds[i];
            address nftAddress = loanItems[_loanId].nftAddress;
            _nftToBundleId[nftAddress][id] = 0;
        }
        if (loanItems[_loanId].earnedRewards > 0) claimRewards(_loanId);
        for (uint256 i = 0; i < loanItems[_loanId].tokenIds.length; i++) {
            uint256 id = loanItems[_loanId].tokenIds[i];
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

    function setTrustedForwarder(address _trustedForwarder) external onlyAdmin {
        trustedForwarder = _trustedForwarder;
    }

    function _msgSender() internal view override(Context, BaseRelayRecipient) returns (address) {
        return BaseRelayRecipient._msgSender();
    }
}
