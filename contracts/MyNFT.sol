// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title MyNFT
 * @dev 실제 사용되는 NFT 컨트랙트
 * 
 * 주요 기능:
 * - NFT 민팅 (공개 민팅, 화이트리스트)
 * - 로열티 시스템
 * - 마켓플레이스 통합
 * - 레벨업 시스템 (게임용)
 * 
 * 실제 사용 예시:
 * - CryptoPunks
 * - Bored Ape Yacht Club
 * - NBA Top Shot
 */
contract MyNFT is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard {
    uint256 private _tokenIdCounter;
    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MINT_PRICE = 0.05 ether;
    uint256 public constant MAX_MINT_PER_ADDRESS = 5;
    
    // 로열티 관련
    address public royaltyReceiver;
    uint256 public royaltyPercentage = 250; // 2.5%
    
    // 화이트리스트 관련
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public whitelistMintCount;
    bool public whitelistActive = true;
    uint256 public constant WHITELIST_PRICE = 0.03 ether;
    
    // NFT 레벨 시스템 (게임용)
    mapping(uint256 => uint256) public nftLevel;
    mapping(uint256 => uint256) public nftExperience;
    mapping(address => uint256) public mintCount;
    
    // 마켓플레이스 기능
    struct MarketItem {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
    }
    
    mapping(uint256 => MarketItem) public marketItems;
    mapping(uint256 => address) public tokenApprovals;
    
    event NFTMinted(address indexed to, uint256 indexed tokenId, string uri);
    event NFTLevelUp(uint256 indexed tokenId, uint256 newLevel);
    event NFTListedForSale(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    
    constructor() ERC721("MyNFT Collection", "MYNFT") Ownable(msg.sender) {
        royaltyReceiver = msg.sender;
    }
    
    /**
     * @dev 공개 민팅
     */
    function publicMint(string memory uri) public payable nonReentrant {
        require(!whitelistActive, "Whitelist phase active");
        require(_tokenIdCounter < MAX_SUPPLY, "Max supply reached");
        require(mintCount[msg.sender] < MAX_MINT_PER_ADDRESS, "Max mint per address reached");
        require(msg.value >= MINT_PRICE, "Insufficient payment");
        
        uint256 tokenId = _tokenIdCounter++;
        mintCount[msg.sender]++;
        
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);
        
        nftLevel[tokenId] = 1;
        nftExperience[tokenId] = 0;
        
        emit NFTMinted(msg.sender, tokenId, uri);
    }
    
    /**
     * @dev 화이트리스트 민팅
     */
    function whitelistMint(string memory uri) public payable nonReentrant {
        require(whitelistActive, "Whitelist phase not active");
        require(whitelist[msg.sender], "Not whitelisted");
        require(_tokenIdCounter < MAX_SUPPLY, "Max supply reached");
        require(whitelistMintCount[msg.sender] < 2, "Max whitelist mint reached");
        require(msg.value >= WHITELIST_PRICE, "Insufficient payment");
        
        uint256 tokenId = _tokenIdCounter++;
        whitelistMintCount[msg.sender]++;
        
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);
        
        nftLevel[tokenId] = 1;
        nftExperience[tokenId] = 0;
        
        emit NFTMinted(msg.sender, tokenId, uri);
    }
    
    /**
     * @dev 관리자 민팅 (에어드랍용)
     */
    function adminMint(address to, string memory uri) public onlyOwner {
        require(_tokenIdCounter < MAX_SUPPLY, "Max supply reached");
        
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        
        nftLevel[tokenId] = 1;
        nftExperience[tokenId] = 0;
        
        emit NFTMinted(to, tokenId, uri);
    }
    
    /**
     * @dev NFT 레벨업 (게임 기능)
     */
    function levelUpNFT(uint256 tokenId, uint256 experienceGained) public {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        
        nftExperience[tokenId] += experienceGained;
        
        // 경험치 1000마다 레벨업
        uint256 newLevel = (nftExperience[tokenId] / 1000) + 1;
        if (newLevel > nftLevel[tokenId]) {
            nftLevel[tokenId] = newLevel;
            emit NFTLevelUp(tokenId, newLevel);
        }
    }
    
    /**
     * @dev NFT 마켓플레이스에 등록
     */
    function listForSale(uint256 tokenId, uint256 price) public {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(price > 0, "Price must be greater than 0");
        
        marketItems[tokenId] = MarketItem({
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            active: true
        });
        
        emit NFTListedForSale(tokenId, msg.sender, price);
    }
    
    /**
     * @dev NFT 구매
     */
    function buyNFT(uint256 tokenId) public payable nonReentrant {
        MarketItem memory item = marketItems[tokenId];
        require(item.active, "NFT not for sale");
        require(msg.value >= item.price, "Insufficient payment");
        require(item.seller != msg.sender, "Cannot buy own NFT");
        
        address seller = item.seller;
        uint256 price = item.price;
        
        // 로열티 계산
        uint256 royaltyAmount = (price * royaltyPercentage) / 10000;
        uint256 sellerAmount = price - royaltyAmount;
        
        // 마켓 아이템 비활성화
        marketItems[tokenId].active = false;
        
        // NFT 전송
        _transfer(seller, msg.sender, tokenId);
        
        // 대금 지급
        payable(seller).transfer(sellerAmount);
        payable(royaltyReceiver).transfer(royaltyAmount);
        
        // 초과 지불금 환불
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
        
        emit NFTSold(tokenId, seller, msg.sender, price);
    }
    
    /**
     * @dev 화이트리스트 관리
     */
    function addToWhitelist(address[] memory addresses) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = true;
        }
    }
    
    function removeFromWhitelist(address[] memory addresses) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = false;
        }
    }
    
    function setWhitelistActive(bool active) public onlyOwner {
        whitelistActive = active;
    }
    
    /**
     * @dev 로열티 설정
     */
    function setRoyalty(address receiver, uint256 percentage) public onlyOwner {
        require(percentage <= 1000, "Royalty too high"); // 최대 10%
        royaltyReceiver = receiver;
        royaltyPercentage = percentage;
    }
    
    /**
     * @dev 수익 인출
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
    
    /**
     * @dev NFT 정보 조회
     */
    function getNFTInfo(uint256 tokenId) public view returns (
        address owner,
        string memory uri,
        uint256 level,
        uint256 experience,
        bool forSale,
        uint256 price
    ) {
        owner = ownerOf(tokenId);
        uri = tokenURI(tokenId);
        level = nftLevel[tokenId];
        experience = nftExperience[tokenId];
        
        MarketItem memory item = marketItems[tokenId];
        forSale = item.active;
        price = item.price;
    }
    
    /**
     * @dev 사용자의 모든 NFT 조회
     */
    function getUserNFTs(address user) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(user);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < _tokenIdCounter; i++) {
            if (_ownerOf(i) == user) {
                tokenIds[index] = i;
                index++;
            }
        }
        
        return tokenIds;
    }
    
    // Override functions
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
