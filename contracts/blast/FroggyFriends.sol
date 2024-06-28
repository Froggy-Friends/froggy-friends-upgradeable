// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {DefaultOperatorFiltererUpgradeable} from "operator-filter-registry/src/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import {ERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ONFT721} from "@layerzerolabs/solidity-examples/contracts/token/onft721/ONFT721.sol";
import {IONFT721} from "@layerzerolabs/solidity-examples/contracts/token/onft721/interfaces/IONFT721.sol";

contract FroggyFriends is
    DefaultOperatorFiltererUpgradeable,
    ERC2981Upgradeable,
    ONFT721Upgradeable
{
    string public froggyUrl;
    uint256 private _totalMinted;

    function initialize(
        uint256 _minGasToTransfer,
        address _lzEndpoint
    ) public initializer {
        __ONFT721Upgradeable_init(
            "Froggy Friends",
            "FROGGY",
            _minGasToTransfer,
            _lzEndpoint
        );
        __Ownable_init();
        __DefaultOperatorFilterer_init();
        __ERC2981_init();
        froggyUrl = "https://metadata.froggyfriends.io/blast/frog/";
    }

    function rawOwnerOf(uint tokenId) public view returns (address) {
        if (_exists(tokenId)) {
            return ownerOf(tokenId);
        }
        return address(0);
    }

    function _baseURI() internal view override returns (string memory) {
        return froggyUrl;
    }

    function setFroggyUrl(string memory _froggyUrl) external onlyOwner {
        froggyUrl = _froggyUrl;
    }

    function _mint(address to, uint256 tokenId) internal override {
        super._mint(to, tokenId);
        _totalMinted++;
    }

    function totalSupply() public view returns (uint256) {
        return _totalMinted;
    }

    function setRoyalties(
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    // =============================================================
    //                      ERC2981 OVERRIDES
    // =============================================================

    function approve(
        address operator,
        uint256 tokenId
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    function setApprovalForAll(
        address operator,
        bool approved
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperator(from)
    {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC2981Upgradeable, ONFT721Upgradeable)
        returns (bool)
    {
        return (interfaceId == type(IERC2981Upgradeable).interfaceId ||
            interfaceId == type(IONFT721Upgradeable).interfaceId ||
            super.supportsInterface(interfaceId));
    }
}
