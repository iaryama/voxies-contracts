pragma experimental ABIEncoderV2;

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

    enum NFTRewardsClaimer {
        loaner,
        loanee
    }

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
        NFTRewardsClaimer claimer;
        uint256 loanerClaimedRewards;
        uint256 loaneeClaimedRewards;
        address[] nftRewardContracts;
        uint256[] nftRewards;
        uint256 startingTime;
        address reservedTo;
    }

    mapping(uint256 => bool) public areNFTsClaimed;

    mapping(uint256 => bool) public areNFTRewardsClaimed;

    mapping(uint256 => LoanableItem) public loanItems;

    event LoanableItemCreated(
        address owner,
        address[] nftAddress,
        uint256[] lockedNFT,
        uint256 itemId,
        address reservedTo,
        NFTRewardsClaimer claimer
    );

    event LoanIssued(address loanee, uint256 loanId);

    event ERC20RewardsAdded(uint256 loanId, uint256 amount);

    event NFTRewardsAdded(uint256 loanId, address[] nftAddress, uint256[] nftIds);

    event ERC20RewardsClaimed(address claimer, uint256 rewards, uint256 loanId);

    event NFTRewardsClaimed(address claimer, uint256[] nftIds, uint256 loanId);

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
        require(
            (block.timestamp - loanItems[loanId].startingTime) <= loanItems[loanId].timePeriod,
            "Inactive loan item"
        );
        return (_owner == loanItems[loanId].loanee);
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
        uint256 _timePeriod,
        address _reservedTo,
        NFTRewardsClaimer _claimer
    ) external nonReentrant returns (uint256) {
        require(_nftAddresses.length == _nftIds.length, "_nftAddresses.length != _nftIds.length");
        require(_nftIds.length > 0, "Atleast one NFT should be part of loanable Item");
        require(_percentageRewards < 100, "Percentage cannot be more than 100");
        require(_timePeriod >= minLoanPeriod && _timePeriod <= maxLoanPeriod, "Incorrect loan time period specified");
        require(_reservedTo != _msgSender(), "Cannot reserve loan to owner");
        for (uint256 i = 0; i < _nftIds.length; i++) {
            require(allowedNFT[_nftAddresses[i]], "NFT contract address is not allowed");
            require(_nftToBundleId[_nftAddresses[i]][_nftIds[i]] == 0, "Loan Bundle exits with the given NFT");
            address nftOwner = IERC721(_nftAddresses[i]).ownerOf(_nftIds[i]);
            require(_msgSender() == nftOwner, "Sender is not the owner of given NFT");
        }
        _loanIds.increment();
        uint256 newLoanId = _loanIds.current();
        loanItems[newLoanId].owner = _msgSender();
        loanItems[newLoanId].upfrontFee = _upfrontFee;
        loanItems[newLoanId].percentageRewards = _percentageRewards;
        loanItems[newLoanId].timePeriod = _timePeriod;
        loanItems[newLoanId].claimer = _claimer;
        if (_reservedTo != address(0) && !_reservedTo.isContract()) {
            loanItems[newLoanId].reservedTo = _reservedTo;
        }
        for (uint256 i = 0; i < _nftIds.length; i++) {
            _nftToBundleId[_nftAddresses[i]][_nftIds[i]] = newLoanId;
            loanItems[newLoanId].nftAddresses.push(_nftAddresses[i]);
            loanItems[newLoanId].tokenIds.push(_nftIds[i]);
            IERC721(_nftAddresses[i]).safeTransferFrom(_msgSender(), address(this), _nftIds[i]);
        }
        emit LoanableItemCreated(_msgSender(), _nftAddresses, _nftIds, newLoanId, _reservedTo, _claimer);
        return newLoanId;
    }

    /**
     * Loaner can reserve the loan to a user.
     *
     * @param _loanId - Id of the loanable item
     * @param _reserveTo - Address of the user to reserve the loan
     */

    function reserveLoanItem(uint256 _loanId, address _reserveTo) external {
        require(_msgSender() == loanItems[_loanId].owner, "Only loan owner can reserve loan items");
        require(
            _reserveTo != address(0) && _msgSender() != _reserveTo && !_reserveTo.isContract(),
            "Invalid reserve address"
        );
        require(loanItems[_loanId].startingTime == 0, "Cannot reserve an active loan item");
        loanItems[_loanId].reservedTo = _reserveTo;
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
        require(!areNFTsClaimed[_loanId], "NFTs already claimed, cannot issue loan");
        if (loanItems[_loanId].reservedTo != address(0)) {
            require(loanItems[_loanId].reservedTo == _loanee, "Private loan can only be issued to reserved user");
        }
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
        require(!areNFTsClaimed[_loanId], "NFTs already claimed, cannot issue loan");
        if (loanItems[_loanId].reservedTo != address(0)) {
            require(loanItems[_loanId].reservedTo == _msgSender(), "Private loan can only be issued to reserved user");
        }
        loanItems[_loanId].loanee = _msgSender();
        loanItems[_loanId].isActive = true;
        loanItems[_loanId].startingTime = block.timestamp;
        if (loanItems[_loanId].upfrontFee != 0) {
            token.safeTransferFrom(_msgSender(), loanItems[_loanId].owner, loanItems[_loanId].upfrontFee);
        }
        emit LoanIssued(_msgSender(), _loanId);
    }

    /**
     * Admin can add ERC20 Rewards
     *
     * @param _loanId - loan id
     * @param _amount - Rewards Amount.
     */

    function addERC20Rewards(uint256 _loanId, uint256 _amount) external onlyAdmin nonReentrant {
        require(loanItems[_loanId].owner != address(0), "Loanable Item Not Found");
        require(_amount > 0, "Invalid amount");
        require(loanItems[_loanId].startingTime > 0, "Inactive loan item");
        require(
            (block.timestamp - loanItems[_loanId].startingTime) <= loanItems[_loanId].timePeriod,
            "Inactive loan item"
        );
        loanItems[_loanId].totalRewards = loanItems[_loanId].totalRewards + _amount;
        token.safeTransferFrom(_msgSender(), address(this), _amount);
        emit ERC20RewardsAdded(_loanId, _amount);
    }

    /**
     * Admin can add NFT Rewards
     *
     * @param _loanId - loan id
     * @param _nftAddresses - NFT Contract addresses.
     * @param _nftIds - NFT Rewards.
     */

    function addNFTRewards(
        uint256 _loanId,
        address[] calldata _nftAddresses,
        uint256[] calldata _nftIds
    ) external onlyAdmin {
        require(_nftIds.length > 0, "nftIds length == 0");
        require(_nftAddresses.length == _nftIds.length, "_nftAddresses.length != _nftIds.length");
        require(loanItems[_loanId].owner != address(0), "Loanable Item Not Found");
        require(loanItems[_loanId].startingTime > 0, "Inactive loan item");
        require(
            (block.timestamp - loanItems[_loanId].startingTime) <= loanItems[_loanId].timePeriod,
            "Inactive loan item"
        );
        for (uint256 i = 0; i < _nftIds.length; i++) {
            address nftAddress = _nftAddresses[i];
            uint256 nftId = _nftIds[i];
            require(_nftToBundleId[nftAddress][nftId] == 0, "Bundled NFT cannot be added as rewards");
            _nftToBundleId[nftAddress][nftId] = _loanId;
            loanItems[_loanId].nftRewardContracts.push(nftAddress);
            loanItems[_loanId].nftRewards.push(nftId);
            IERC721(nftAddress).safeTransferFrom(_msgSender(), address(this), nftId);
        }
        emit NFTRewardsAdded(_loanId, _nftAddresses, _nftIds);
    }

    /**
     * Get Bundled NFTs
     *
     * @param _loanId - Id of the loaned item
     *
     */
    function getBundledNFTs(uint256 _loanId) public view returns (address[] memory, uint256[] memory) {
        return (loanItems[_loanId].nftAddresses, loanItems[_loanId].tokenIds);
    }

    /**
     * Get NFT Rewards
     *
     * @param _loanId - Id of the loaned item
     *
     */
    function getNFTRewards(uint256 _loanId) public view returns (address[] memory, uint256[] memory) {
        return (loanItems[_loanId].nftRewardContracts, loanItems[_loanId].nftRewards);
    }

    /**
     * Get Loanee Rewards
     *
     * @param _loanId - Id of the loaned item
     *
     */

    function getLoaneeRewards(uint256 _loanId) public view returns (uint256) {
        uint256 loanerRewards = (loanItems[_loanId].totalRewards * loanItems[_loanId].percentageRewards) / 100;
        uint256 loaneeRewards = loanItems[_loanId].totalRewards - loanerRewards;
        return (loaneeRewards - loanItems[_loanId].loaneeClaimedRewards);
    }

    /**
     * Get Loanee Rewards
     *
     * @param _loanId - Id of the loaned item
     *
     */

    function getLoanerRewards(uint256 _loanId) public view returns (uint256) {
        uint256 loanerRewards = (loanItems[_loanId].totalRewards * loanItems[_loanId].percentageRewards) / 100;
        return (loanerRewards - loanItems[_loanId].loanerClaimedRewards);
    }

    /**
     * Claim ERC20 Rewards
     *
     * @param _loanId - Id of the loaned item
     *
     */

    function claimERC20Rewards(uint256 _loanId) public nonReentrant {
        require(
            _msgSender() == loanItems[_loanId].owner || _msgSender() == loanItems[_loanId].loanee,
            "Either loaner or loanee can claim rewards"
        );
        require(loanItems[_loanId].totalRewards > 0, "No rewards found for given LoanId");
        if (_msgSender() == loanItems[_loanId].owner) {
            uint256 loanerRewards = getLoanerRewards(_loanId);
            require(loanerRewards > 0, "No rewards found");
            loanItems[_loanId].loanerClaimedRewards = loanItems[_loanId].loanerClaimedRewards + loanerRewards;
            token.safeTransfer(loanItems[_loanId].owner, loanerRewards);
            emit ERC20RewardsClaimed(_msgSender(), loanerRewards, _loanId);
        } else {
            uint256 loaneeRewards = getLoaneeRewards(_loanId);
            require(loaneeRewards > 0, "No rewards found");
            loanItems[_loanId].loaneeClaimedRewards = loanItems[_loanId].loaneeClaimedRewards + loaneeRewards;
            token.safeTransfer(loanItems[_loanId].loanee, loaneeRewards);
            emit ERC20RewardsClaimed(_msgSender(), loaneeRewards, _loanId);
        }
    }

    /**
     * Claim NFT Rewards
     *
     * @param _loanId - Id of the loaned item
     *
     */

    function claimNFTRewards(uint256 _loanId) external nonReentrant {
        require(loanItems[_loanId].owner != address(0), "Loanable Item Not Found");
        require(!areNFTRewardsClaimed[_loanId], "Rewards already claimed");
        require(loanItems[_loanId].startingTime > 0, "Inactive loan item");
        require(
            _msgSender() == loanItems[_loanId].owner || _msgSender() == loanItems[_loanId].loanee,
            "Either loaner or loanee can claim nft rewards"
        );
        require(
            (block.timestamp - loanItems[_loanId].startingTime) >= loanItems[_loanId].timePeriod,
            "Loan period is still active "
        );
        areNFTRewardsClaimed[_loanId] = true;
        if (loanItems[_loanId].claimer == NFTRewardsClaimer.loaner) {
            require(_msgSender() == loanItems[_loanId].owner, "Only Loaner can claim NFT rewards");
            for (uint256 i = 0; i < loanItems[_loanId].nftRewards.length; i++) {
                uint256 id = loanItems[_loanId].nftRewards[i];
                address nftAddress = loanItems[_loanId].nftRewardContracts[i];
                _nftToBundleId[nftAddress][id] = 0;
                IERC721(nftAddress).safeTransferFrom(address(this), loanItems[_loanId].owner, id);
            }
            emit NFTRewardsClaimed(loanItems[_loanId].owner, loanItems[_loanId].nftRewards, _loanId);
        } else {
            require(_msgSender() == loanItems[_loanId].loanee, "Only Loanee can claim NFT rewards");
            for (uint256 i = 0; i < loanItems[_loanId].nftRewards.length; i++) {
                uint256 id = loanItems[_loanId].nftRewards[i];
                address nftAddress = loanItems[_loanId].nftRewardContracts[i];
                IERC721(nftAddress).safeTransferFrom(address(this), loanItems[_loanId].loanee, id);
            }
            emit NFTRewardsClaimed(loanItems[_loanId].loanee, loanItems[_loanId].nftRewards, _loanId);
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
        require(!areNFTsClaimed[_loanId], "NFTs already claimed");
        if (loanItems[_loanId].startingTime > 0) {
            require(
                (block.timestamp - loanItems[_loanId].startingTime) >= loanItems[_loanId].timePeriod,
                "Loan period is still active "
            );
        }
        areNFTsClaimed[_loanId] = true;
        loanItems[_loanId].isActive = false;
        for (uint256 i = 0; i < loanItems[_loanId].tokenIds.length; i++) {
            uint256 id = loanItems[_loanId].tokenIds[i];
            address nftAddress = loanItems[_loanId].nftAddresses[i];
            _nftToBundleId[nftAddress][id] = 0;
            IERC721(nftAddress).safeTransferFrom(address(this), loanItems[_loanId].owner, id);
        }
        emit NFTsClaimed(loanItems[_loanId].nftAddresses, loanItems[_loanId].tokenIds, loanItems[_loanId].owner);
    }

    function setTrustedForwarder(address _trustedForwarder) external onlyAdmin {
        trustedForwarder = _trustedForwarder;
    }

    function _msgSender() internal view override(Context, BaseRelayRecipient) returns (address) {
        return BaseRelayRecipient._msgSender();
    }

    /**
     * Withdraw ERC20 Rewards
     * @param _token - IERC20 Token
     */

    function withdrawERC20(IERC20 _token) external onlyAdmin {
        require(_token != token, " Cannot withdraw Voxel tokens");
        uint256 balance = _token.balanceOf(address(this));
        _token.safeTransfer(owner(), balance);
    }

    /**
     * Admin can add NFT Rewards
     *
     * @param _nftAddresses - NFT Contract addresses.
     * @param _tokenIds - NFT token ids.
     */

    function withdrawNFTs(address[] calldata _nftAddresses, uint256[] calldata _tokenIds) external onlyAdmin {
        require(_tokenIds.length > 0, "tokenIds length == 0");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            address nftAddress = _nftAddresses[i];
            uint256 tokenId = _tokenIds[i];
            require(_nftToBundleId[nftAddress][tokenId] == 0, "Cannot withdraw from loaned bundles");
            IERC721(nftAddress).safeTransferFrom(address(this), owner(), tokenId);
        }
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
