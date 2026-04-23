// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleNFT is ERC721, Ownable {
    uint256 public mintPrice = 0.001 ether;
    uint256 private tokenIdCounter;
    uint256 public maxToken = 5; // default max token is 5
    uint256 public maxPerWallet; // default = 0, so set must be first called before mint

    mapping(address => uint256) public mintedToken;
    mapping(uint256 => uint256) public tokenPrice;
    mapping(uint256 => bool) public saleToken;
    mapping(uint256 => address) public ogCreator;
    
    constructor() payable ERC721("Simple NFT", "SNFT") Ownable(msg.sender){}

    function mint() external payable {
        require(tokenIdCounter < maxToken, "Max token reached");
        require(mintedToken[msg.sender] < maxPerWallet, "Wallet limit reached");
        require(msg.value >= mintPrice, "Wrong value");

        tokenIdCounter += 1;
        uint256 tokenId = tokenIdCounter;

        mintedToken[msg.sender] += 1;
        ogCreator[tokenId] = msg.sender;

        _safeMint(msg.sender, tokenId);

        // refunds excess amount
        uint256 refund = msg.value - mintPrice;
        if (refund > 0) {
            (bool success, ) = msg.sender.call{value: refund}("");
            require(success, "Refund failed");
        }
    }

    function setMaxToken(uint256 _maxToken) external onlyOwner { 
        maxToken = _maxToken;
    }

    function setMaxPerWallet(uint256 _maxPerWallet) external onlyOwner{
        maxPerWallet = _maxPerWallet;
    }

    function setPrice(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "You are not the owner of this token");
        tokenPrice[tokenId] = price;
    }

    function setTokenState(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "You are not the owner of this token");
        saleToken[tokenId] = !saleToken[tokenId];
    }

    function buyToken(uint256 tokenId) external payable {
        require(saleToken[tokenId], "This token is not for sale");

        uint256 price = tokenPrice[tokenId];
        require(msg.value >= price, "Not enough ether sent");

        address seller = ownerOf(tokenId);
        address creator = ogCreator[tokenId];

        uint256 royaltyAmount = price/10; 
        uint256 sellerAmount = price - royaltyAmount;

        saleToken[tokenId] = false; // update state of token

        //add royalty amount sender
        // send value of token to previous owner
        (bool sentTokenValue, ) = msg.sender.call{value: sellerAmount}("");
        require(sentTokenValue, "Failed to send token price to previous owner");

        // send token to new owner
        _transfer(seller, msg.sender, tokenId);

        // refunds excess amount
        uint256 refund = msg.value - price;
        if (refund > 0) {
            (bool success, ) = msg.sender.call{value: refund}("");
            require(success, "Refund failed");
        }
    }
}
