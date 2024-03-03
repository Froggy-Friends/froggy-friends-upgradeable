// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC721Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import {IERC721Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';
import {DefaultOperatorFiltererUpgradeable} from "operator-filter-registry/src/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import {ERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import {IERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {ONFT721Upgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC721/ONFT721Upgradeable.sol";
import {IONFT721Upgradeable} from "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC721/IONFT721Upgradeable.sol";

error InvalidSize();
error OverMaxSupply();

contract FroggyFriends is ONFT721Upgradeable, ERC2981Upgradeable, DefaultOperatorFiltererUpgradeable {
    using StringsUpgradeable for uint256;
    string public froggyUrl;
    uint256 public maxSupply;
    uint256 private _totalMinted;
    
    function initialize(uint256 _minGasToTransfer, address _lzEndpoint) initializer public {
        __ONFT721Upgradeable_init("Froggy Friends", "FROGGY", _minGasToTransfer, _lzEndpoint);
        __Ownable_init();
        __DefaultOperatorFilterer_init();
        __ERC2981_init();

        froggyUrl = "https://metadata.froggyfriendsnft.com/";
        maxSupply = 4444;
    }

    function airdrop(address[] calldata owners, uint16[] calldata tokenIds) external onlyOwner {
        if (owners.length != tokenIds.length) {
            revert InvalidSize();
        }
        if (_totalMinted + tokenIds.length > maxSupply) {
            revert OverMaxSupply();
        }
        for (uint16 i; i < tokenIds.length; ) {
            _mint(owners[i], tokenIds[i]);
            unchecked {
                ++i;
            }
        }
        _totalMinted = _totalMinted + tokenIds.length;
    }

    function tokensOfOwner(address account) external view returns (uint256[] memory) {
        unchecked {
            uint256 tokenIdsIdx;
            uint256 tokenIdsLength = balanceOf(account);
            uint256[] memory tokenIds = new uint256[](tokenIdsLength);
            for (uint256 i; tokenIdsIdx != tokenIdsLength; ++i) {
                if (!_exists(i)) {
                    continue;
                }
                if (ownerOf(i) == account) {
                    tokenIds[tokenIdsIdx++] = i;
                }
            }
            return tokenIds;
        }
    }

    function totalSupply() public view returns (uint256) {
        return _totalMinted;
    }

    function setFroggyUrl(string memory _froggyUrl) external onlyOwner {
        froggyUrl = _froggyUrl;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return bytes(froggyUrl).length > 0 ? string(abi.encodePacked(froggyUrl, tokenId.toString())) : "";
    }

    // =============================================================
    //                      ERC2981 OVERRIDES
    // =============================================================

    function approve(address operator, uint256 tokenId) public override(ERC721Upgradeable, IERC721Upgradeable) onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public override(ERC721Upgradeable, IERC721Upgradeable) onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721Upgradeable, IERC721Upgradeable) onlyAllowedOperator(from) ifNotLocked(tokenId){
        super.transferFrom(from, to, tokenId);
    }
       
    function safeTransferFrom(address from, address to, uint256 tokenId) public override(ERC721Upgradeable, IERC721Upgradeable) onlyAllowedOperator(from) ifNotLocked(tokenId){
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override(ERC721Upgradeable, IERC721Upgradeable) onlyAllowedOperator(from) ifNotLocked(tokenId){
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC2981Upgradeable,ONFT721Upgradeable) returns (bool) {
        return (
            interfaceId == type(IERC2981Upgradeable).interfaceId || 
            interfaceId == type(IONFT721Upgradeable).interfaceId || 
            super.supportsInterface(interfaceId)
        );
    // ellie.xyz1991@gmail.com/ : Changed
    
    // =============================================================
    //                     upgrade version 1
    // =============================================================

    ITadpole public tadpole;

    address public tadpoleSender;

    IRibbitItem public constant ribbitItem = IRibbitItem(0x1f6A5CF9366F968C205467BD7a9f382b3454dFB3);

    IFroggySoulbounds public constant froggySoulbounds = IFroggySoulbounds(0xFdFFd2208AA128A2F9dc520A2A4E93746B588209);

    // owner  => HibernationStatus
    mapping(address => HibernationStatus) public lockStatus;

    // owner => block.timestamp(now)
    mapping(address => uint256) public lockDate;

    // HibernationStatus => tadpole amount for HibernationStatus for hibernating one froggy
    mapping(HibernationStatus => uint256) public statusTadpoleAmount;

    // tokenAddress => tokrnId => rate
    mapping(address => mapping(uint256 => uint256)) public TokenBoostRate;

    // tokenAddress => BoostTokenInfo
    mapping(address => BoostTokenInfo) public boostTokenInfos;

    struct BoostTokenInfo {
        address tokenAddress;
        uint256 id;
        bytes32 symbol;
    }

    enum HibernationStatus {
        AWAKE,
        THIRTYDAY,
        SIXTYDAY,
        NINETYDAY
    }

    event LogHibernate(address indexed _owner, uint256 indexed _lockDate, HibernationStatus indexed _HibernationStatus);

    event LogAwake(address indexed _owner, uint256 indexed _lockDate, uint256 indexed _tadpoleAmount);

    modifier ifNotLocked(uint256 _tokenId) {
        require(lockStatus[ownerOf(_tokenId)] == HibernationStatus.AWAKE, "this token has been locked");
        _;
    }

    // considerations : gas cost should be small
    // onlyAllowedOperator modifier
    function lockAllMyTokens(HibernationStatus _hibernationStatus) public returns (bool) {
        uint256 _balances = balanceOf(msg.sender);

        require(_balances > 0, "you don't have any tokens");

        // might remove this check (gas cost wise)
        require(_hibernationStatus != HibernationStatus.AWAKE, "the token is awake by defult");

        lockStatus[msg.sender] = _hibernationStatus;

        lockDate[msg.sender] = block.timestamp;

        emit LogHibernate(msg.sender, block.timestamp, _hibernationStatus);

        return true;
    }

    function unlockMyTokens() public returns (bool) {
        require(lockDate[msg.sender] > 0, "your tokens have not been locked");

        require(block.timestamp > getUnlockTimestamp(), "awake time has'nt been reached");

        uint256 _tadpoleAmount = calculateTotalRewardAmount();

        // owner of tadpole is the tadpole sender?
        tadpole.transferFrom(tadpoleSender, msg.sender, _tadpoleAmount);

        // write test here

        lockStatus[msg.sender] = HibernationStatus.AWAKE;

        emit LogAwake(msg.sender, block.timestamp, _tadpoleAmount);

        return true;
    }

    // no froggy rarity tiers . all of them are flat
    //total rewards = base * total frogs * boosts
    function getRewardPerFroggy() public view returns (uint256) {
        return (statusTadpoleAmount[lockStatus[msg.sender]] * (1 + (calculateTotalBoost() / 100))) * 10 ** 18;
    }

    function calculateTotalRewardAmount() public view returns (uint256) {
        return getRewardPerFroggy() * balanceOf(msg.sender);
    }

    // should figure out a way to reduce gas cost
    function calculateTotalBoost() public view returns (uint256) {
        //Froggy Minter Token ID = 1
        //One Year Anniversary Holder Token ID = 2
        uint256 ribbitItemBoost = TokenBoostRate[address(ribbitItem)][1] * ribbitItem.balanceOf(msg.sender, 1);

        uint256 froggyMinterBoost =
            TokenBoostRate[address(froggySoulbounds)][1] * froggySoulbounds.balanceOf(msg.sender, 1);

        uint256 oneYearAnniversaryBoost =
            TokenBoostRate[address(froggySoulbounds)][2] * froggySoulbounds.balanceOf(msg.sender, 2);

        return ribbitItemBoost + froggyMinterBoost + oneYearAnniversaryBoost;
    }

    function getLockDuration() public view returns (uint256) {
        return (uint8(lockStatus[msg.sender]) * 30) * (24 * 60 * 60); // (number of hibernate days) * each day
    }

    function getUnlockTimestamp() public view returns (uint256) {
        return getLockDuration() + lockDate[msg.sender];
    }

    function setTadpoleForStatus(HibernationStatus _status, uint256 _amount) public onlyOwner {
        statusTadpoleAmount[_status] = _amount;
    }

    function setBoostRate(address _address, uint256 _tokenId, uint256 _rate) public onlyOwner {
        TokenBoostRate[_address][_tokenId] = _rate;
    }

    function setTadpole(address _tadpole) public onlyOwner {
        tadpole = ITadpole(_tadpole);
    }

    function setTadpoleSender(address _sender) public onlyOwner {
        tadpoleSender = _sender;
    }
}

interface ITadpole {
    function transferFrom(address from, address to, uint256 amountOrId) external;
}

// address : 0x1f6A5CF9366F968C205467BD7a9f382b3454dFB3
interface IRibbitItem {
    /// @notice returns the number of ribbit items an account owns
    /// @param account the address to check the balance of
    /// @param id the ribbit item id
    //note: Golden Lily Pad Token ID = 1
    function balanceOf(address account, uint256 id) external view returns (uint256);
}

// address : 0xfdffd2208aa128a2f9dc520a2a4e93746b588209
interface IFroggySoulbounds {
    //Froggy Minter Token ID = 1
    //One Year Anniversary Holder Token ID = 2
    function balanceOf(address account, uint256 id) external view returns (uint256);
}

// Tadpoles.sol Owner
// 0x7A405A70575714D74A1fA0B860730CF7456e6eBB
// FroggyFriends.sol Owner
// 0x6b01aD68aB6F53128B7A6Fe7E199B31179A4629a

// ellie.xyz1991@gmail.com\