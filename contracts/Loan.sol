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
contract Loan is AccessProtected, ReentrancyGuard, BaseRelayRecipient, IERC721Receiver {
    using SafeMath for uint256;
    using Address for address;
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    Counters.Counter public _loanIds;

    IERC20 public token;

    uint256 public maxLoanPeriod = 604800;

    uint256 public minLoanPeriod = 3600;

    // nftContract address to nftId to LoanableItemId
    mapping(address => mapping(uint256 => uint256)) public _nftToBundleId;

    mapping(address => bool) public allowedNFT;

    struct LoanableItem {
        address[] nftAddresses;
        address owner;
        address loanee;
        bool isActive;
        uint256[] tokenIds;
        uint256 upfrontFee;
        uint8 percentageRewards;
        uint256 timePeriod;
        uint256 totalRewards;
        uint256 loanerClaimedRewards;
        uint256 loaneeClaimedRewards;
        uint256 startingTime;
    }

    mapping(uint256 => LoanableItem) public loanItems;

    event LoanableItemCreated(address owner, address[] nftAddress, uint256[] lockedNFT, uint256 itemId);

    event LoanIssued(address loanee, uint256 loanId);

    event RewardsAdded(address[] nftAddress, uint256[] nftIds, uint256[] amounts);

    event RewardsClaimed(address claimer, uint256 rewards, uint256 loanId);

    event NFTsClaimed(address[] nftAddress, uint256[] nftIds, address owner);

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
        require(_timePeriod > minLoanPeriod);
        maxLoanPeriod = _timePeriod;
    }

    /**
     * Updates Minimum allowed time period
     *
     * @param _timePeriod - epoch time value
     */

    function updateMinTimePeriod(uint256 _timePeriod) external onlyAdmin {
        require(_timePeriod > 0, "Incorrect time period");
        require(_timePeriod < maxLoanPeriod);
        minLoanPeriod = _timePeriod;
    }

    /**
     * Sets whether NFT Contract is Allowed or Not
     *
     * @param _nftAddress - ERC721 contract address
     * @param _enabled - Enable/Disable
     */

    function allowNFTContract(address _nftAddress, bool _enabled) external onlyAdmin {
        require(_nftAddress.isContract(), "Given NFT Address must be a contract");
        allowedNFT[_nftAddress] = _enabled;
    }

    /**
     * Checks whether NFT id is part of any bundle
     *
     * @param _nftAddress - ERC721 contract address
     * @param _nftId - NFT id
     */

    function _isBundled(address _nftAddress, uint256 _nftId) external view returns (bool) {
        require(allowedNFT[_nftAddress], "NFT contract address is not allowed");
        return (_nftToBundleId[_nftAddress][_nftId] > 0);
    }

    /**
     * Checks whether a specific user has access to given NFT id
     *
     * @param _nftAddress - ERC721 contract address
     * @param _nftId - NFT id
     */
    function hasAccessToNFT(
        address _nftAddress,
        uint256 _nftId,
        address _owner
    ) external view returns (bool) {
        require(allowedNFT[_nftAddress], "NFT contract address is not allowed");
        require(_nftToBundleId[_nftAddress][_nftId] > 0, "NFT is not bundled as a Loanable Item");
        uint256 loanId = _nftToBundleId[_nftAddress][_nftId];
        require(loanItems[loanId].owner != address(0), "Loanable Item Not Found");
        if (block.timestamp.sub(loanItems[loanId].startingTime) <= loanItems[loanId].timePeriod) {
            return (_owner == loanItems[loanId].loanee);
        } else {
            return (_owner == loanItems[loanId].owner);
        }
    }

    /**
     * Listing a Loanable item
     *
     * @param _nftAddresses - ERC721 contract addresses
     * @param _nftIds - List of NFT ids
     * @param _upfrontFee - Upfront fee to loan item
     * @param _percentageRewards - Percentage of earned rewards
     * @param _timePeriod - Duration of the loan
     */

    function createLoanableItem(
        address[] calldata _nftAddresses,
        uint256[] calldata _nftIds,
        uint256 _upfrontFee,
        uint8 _percentageRewards,
        uint256 _timePeriod
    ) external nonReentrant returns (uint256) {
        require(_nftAddresses.length == _nftIds.length, "_nftAddresses.length != _nftIds.length");
        require(_nftIds.length > 0, "Atleast one NFT should be part of loanable Item");
        require(_percentageRewards < 100, "Percentage cannot be more than 100");
        require(_timePeriod >= minLoanPeriod && _timePeriod <= maxLoanPeriod, "Incorrect loan time period specified");
        for (uint256 i = 0; i < _nftIds.length; i++) {
            require(allowedNFT[_nftAddresses[i]], "NFT contract address is not allowed");
            require(_nftToBundleId[_nftAddresses[i]][_nftIds[i]] == 0, "Loan Bundle exits with the given NFT");
            address nftOwner = IERC721(_nftAddresses[i]).ownerOf(_nftIds[i]);
            require(_msgSender() == nftOwner, "Sender is not the owner of given NFT");
        }
        _loanIds.increment();
        uint256 newLoanId = _loanIds.current();
        loanItems[newLoanId].nftAddresses = _nftAddresses;
        loanItems[newLoanId].owner = _msgSender();
        loanItems[newLoanId].tokenIds = _nftIds;
        loanItems[newLoanId].upfrontFee = _upfrontFee;
        loanItems[newLoanId].percentageRewards = _percentageRewards;
        loanItems[newLoanId].timePeriod = _timePeriod;
        for (uint256 i = 0; i < _nftIds.length; i++) {
            _nftToBundleId[_nftAddresses[i]][_nftIds[i]] = newLoanId;
            IERC721(_nftAddresses[i]).safeTransferFrom(_msgSender(), address(this), _nftIds[i]);
        }
        emit LoanableItemCreated(_msgSender(), _nftAddresses, _nftIds, newLoanId);
        return newLoanId;
    }

    /**
     * Loaner can loan an Item to a loanee
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

    //Not needed for now.
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
     * @param _nftAddresses - ERC721 contract addresses
     * @param _nftIds - List of NFT ids
     * @param _amounts - List of Amounts.
     */

    function addRewardsForNFT(
        address[] calldata _nftAddresses,
        uint256[] calldata _nftIds,
        uint256[] calldata _amounts
    ) external onlyAdmin nonReentrant {
        require(_nftAddresses.length == _nftIds.length, "_nftAddresses.length != _nftIds.length");
        require(_nftIds.length > 0, "Invalid number of NFTs");
        require(_nftIds.length == _amounts.length, "winners.length != _amounts.length");
        for (uint256 i = 0; i < _nftIds.length; i++) {
            require(allowedNFT[_nftAddresses[i]], "Cannot accept tokens from the given NFT contract address");
            uint256 _loanId = _nftToBundleId[_nftAddresses[i]][_nftIds[i]];
            require(loanItems[_loanId].owner != address(0), "Loanable Item Not Found");
            if (block.timestamp.sub(loanItems[_loanId].startingTime) <= loanItems[_loanId].timePeriod) {
                loanItems[_loanId].totalRewards = loanItems[_loanId].totalRewards.add(_amounts[i]);
                token.safeTransferFrom(_msgSender(), address(this), _amounts[i]);
            } else {
                token.safeTransferFrom(_msgSender(), loanItems[_loanId].owner, _amounts[i]);
            }
        }
        emit RewardsAdded(_nftAddresses, _nftIds, _amounts);
    }

    function getLoaneeRewards(uint256 _loanId) public view returns (uint256) {
        uint256 loanerRewards = loanItems[_loanId].totalRewards.mul(loanItems[_loanId].percentageRewards).div(100);
        uint256 loaneeRewards = loanItems[_loanId].totalRewards.sub(loanerRewards);
        return loaneeRewards.sub(loanItems[_loanId].loaneeClaimedRewards);
    }

    function getLoanerRewards(uint256 _loanId) public view returns (uint256) {
        uint256 loanerRewards = loanItems[_loanId].totalRewards.mul(loanItems[_loanId].percentageRewards).div(100);
        return loanerRewards.sub(loanItems[_loanId].loanerClaimedRewards);
    }

    /**
     * Claim Rewards
     *
     * @param _loanId - Id of the loaned item
     *
     */

    function claimRewards(uint256 _loanId) public nonReentrant {
        require(_msgSender() == loanItems[_loanId].owner || _msgSender() == loanItems[_loanId].loanee);
        require(loanItems[_loanId].totalRewards > 0, "No rewards found for given LoanId");
        if (_msgSender() == loanItems[_loanId].owner) {
            uint256 loanerRewards = getLoanerRewards(_loanId);
            token.safeTransfer(loanItems[_loanId].owner, loanerRewards);
            emit RewardsClaimed(_msgSender(), loanerRewards, _loanId);
        } else {
            uint256 loaneeRewards = getLoaneeRewards(_loanId);
            token.safeTransfer(loanItems[_loanId].loanee, loaneeRewards);
            emit RewardsClaimed(_msgSender(), loaneeRewards, _loanId);
        }
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
            block.timestamp.sub(loanItems[_loanId].startingTime) >= loanItems[_loanId].timePeriod,
            "Loan period is still active "
        );
        for (uint256 i = 0; i < loanItems[_loanId].tokenIds.length; i++) {
            uint256 id = loanItems[_loanId].tokenIds[i];
            address nftAddress = loanItems[_loanId].nftAddresses[i];
            _nftToBundleId[nftAddress][id] = 0;
            IERC721(loanItems[_loanId].nftAddresses[i]).safeTransferFrom(address(this), loanItems[_loanId].owner, id);
        }
    }

    function setTrustedForwarder(address _trustedForwarder) external onlyAdmin {
        trustedForwarder = _trustedForwarder;
    }

    function _msgSender() internal view override(Context, BaseRelayRecipient) returns (address) {
        return BaseRelayRecipient._msgSender();
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
