// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// import "hardhat/console.sol";

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";		//https://eips.ethereum.org/EIPS/eip-721
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";  //Individual Metadata URI Storage Functions
import "@openzeppelin/contracts/utils/Counters.sol";
// import "./interfaces/IConfig.sol";
import "./interfaces/IAvatar.sol";
import "./libraries/DataTypes.sol";
import "./abstract/CommonYJ.sol";
import "./abstract/Opinions.sol";


/**
 * @title Avatar as NFT
 * @dev Version 0.3.0
 *  - Contract is open for everyone to mint.
 *  - Max of one NFT assigned for each account
 *  - Can create un-assigned NFT (Kept on contract)
 *  - Minted Token's URI is updatable by Token holder
 *  - Assets are non-transferable by owner
 *  - Tokens can be merged (Multiple Owners)
 *  - [TODO] Orphan tokens can be claimed
 *  - [TODO] Contract is Updatable
  */
contract AvatarNFT is 
        IAvatar, 
        CommonYJ, 
        Opinions,
        ERC721URIStorage {
    
    //--- Storage
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    //Positive & Negative Reputation Tracking Per Domain (Personal,Community,Professional) 
    // mapping(uint256 => mapping(DataTypes.Domain => mapping(DataTypes.Rating => uint256))) internal _rep;  //[Token][Domain][bool] => Rep     //Inherited from Opinions
    mapping(address => uint256) internal _owners;  //Map Multiple Accounts to Tokens (Aliases)


    //--- Modifiers


    //--- Functions

    /// Constructor
    constructor(address hub) CommonYJ(hub) ERC721("Avatar (YourJustice.life)", "AVATAR") {

    }

    /// ERC165 - Supported Interfaces
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAvatar).interfaceId || super.supportsInterface(interfaceId);
    }

    //** Token Owner Index **/

    /// Map Account to Existing Token
    function tokenOwnerAdd(address owner, uint256 tokenId) external onlyOwner {
        _tokenOwnerAdd(owner, tokenId);
    }

    /// Get Token ID by Address
    function tokenByAddress(address owner) external view override returns (uint256){
        return _owners[owner];
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        if(_owners[owner] != 0) return 1;
        return super.balanceOf(owner);
    }

    /// Map Account to Existing Token
    function _tokenOwnerAdd(address owner, uint256 tokenId) internal {
        require(_exists(tokenId), "nonexistent token");
        require(_owners[owner] == 0, "Account Already Mapped to Token");
        _owners[owner] = tokenId;
        //Faux Transfer Event
        emit Transfer(address(0), owner, tokenId);
    }

    //** Reputation **/
    
    /// Add Reputation (Positive or Negative)
    function repAdd(uint256 tokenId, string calldata domain, bool rating, uint8 amount) external override {
        //Validate - Only By Hub
        require(_msgSender() == address(_HUB), "UNAUTHORIZED_ACCESS");

        // console.log("Avatar: Add Reputation to Token:", tokenId, domain, amount);

        //Set
        _repAdd(address(this), tokenId, domain, rating, amount);
    }
    
    //** Token Actions **/
    
    /// Mint (Create New Avatar for oneself)
    function mint(string memory tokenURI) public override returns (uint256) {
        //One Per Account
        require(balanceOf(_msgSender()) == 0, "Requesting account already has an avatar");
        
        //Mint
        uint256 tokenId = _createAvatar(_msgSender(), tokenURI);
        //Index Owner
        _tokenOwnerAdd(_msgSender(), tokenId);
        //Return
        return tokenId;
    }
	
    /// Add (Create New Avatar Without an Owner)
    function add(string memory tokenURI) external override returns (uint256) {
        //Mint
        return _createAvatar(address(this), tokenURI);
    }

    /// Burn NFTs
    function burn(uint256 tokenId) external {
        //Validate Owner of Contract
        require(_msgSender() == owner(), "Only Owner");
        //Burn Token
        _burn(tokenId);
    }

    /// Update Token's Metadata
    function update(uint256 tokenId, string memory uri) public override returns (uint256) {
        //Validate Owner of Token
        require(_isApprovedOrOwner(_msgSender(), tokenId) || _msgSender() == owner(), "caller is not owner nor approved");
        _setTokenURI(tokenId, uri);	//This Goes for Specific Metadata Set (IPFS and Such)
        //Emit URI Changed Event
        emit URI(uri, tokenId);
        //Done
        return tokenId;
    }

    /// Create a new Avatar
    function _createAvatar(address to, string memory uri) internal returns (uint256){
        //Validate - Bot Protection
        require(tx.origin == _msgSender(), "Bots not allowed");
        //Mint
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _safeMint(to, newItemId);
        //Set URI
        _setTokenURI(newItemId, uri);	//This Goes for Specific Metadata Set (IPFS and Such)
        //Emit URI Changed Event
        emit URI(uri, newItemId);
        //Done
        return newItemId;
    }
    
    /// Token Transfer Rules
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721) {
        super._beforeTokenTransfer(from, to, tokenId);
        require(
            _msgSender() == owner()
            || from == address(0)   //Minting
            // || to == address(0)     //Burning
            ,
            "Sorry, Assets are non-transferable"
        );
    }

    /// Receiver Function For Holding NFTs on Contract
    /*
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
    // function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
    */

    /// Receiver Function For Holding NFTs on Contract
    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// Receiver Function For Holding NFTs on Contract (Allow for internal NFTs to assume Roles)
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /// Receiver Function For Holding NFTs on Contract
    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) public pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

}
