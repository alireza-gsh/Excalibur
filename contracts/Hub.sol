//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IConfig.sol";
import "./interfaces/IHub.sol";
import "./interfaces/IJurisdictionUp.sol";
import "./interfaces/ICase.sol";
import "./interfaces/IAvatar.sol";
import "./libraries/DataTypes.sol";
import "./abstract/CommonYJ.sol";


/**
 * YJ Hub Contract
 * - Hold Known Contract Addresses (Avatar, History)
 * - Contract Factory (Jurisdictions & Cases)
 * - Remember Products (Jurisdictions & Cases)
 */
contract Hub is IHub, Ownable {
    //---Storage
    address public beaconCase;
    address public beaconJurisdiction;  //TBD

    // mapping(string => address) internal _contracts;      // Mapping for Used Contracts

    //Avatar Contract Address
    // address public override avatarContract;
    //Action Repo
    // address public override historyContract;

    //Contract Associations
    mapping(string => address) internal _assoc;
    
    // using Counters for Counters.Counter;
    // Counters.Counter internal _tokenIds; //Track Last Token ID
    // Counters.Counter internal _caseIds;  //Track Last Case ID

    // Arbitrary contract designation signature
    string public constant override role = "YJHub";
    // string public constant symbol = "YJHub"; //TODO: Use This

    //--- Storage
    // address internal _CONFIG;    //Configuration Contract
    IConfig private _CONFIG;  //Configuration Contract       //Try This

    mapping(address => bool) internal _jurisdictions; // Mapping for Active Jurisdictions   //[TBD]
    mapping(address => address) internal _cases;      // Mapping for Case Contracts  [C] => [J]


    //--- Events
    //TODO: Owner 
    //TODO: Config changed

    //--- Functions

    constructor(address config, address jurisdictionContract, address caseContract){
        //Set Protocol's Config Address
        _setConfig(config);
        //Init Jurisdiction Contract Beacon
        UpgradeableBeacon _beaconJ = new UpgradeableBeacon(jurisdictionContract);
        beaconJurisdiction = address(_beaconJ);
        //Init Case Contract Beacon
        UpgradeableBeacon _beaconC = new UpgradeableBeacon(caseContract);
        beaconCase = address(_beaconC);
    }

    /// @dev Returns the address of the current owner.
    function owner() public view override(IHub, Ownable) returns (address) {
        return _CONFIG.owner();
    }

    /// Get Configurations Contract Address
    function getConfig() public view returns (address) {
        // return _CONFIG;
        return address(_CONFIG);
    }

    /// Expose Configurations Set for Current Owner
    function setConfig(address config) public onlyOwner {
        _setConfig(config);
    }

    /// Set Configurations Contract Address
    function _setConfig(address config) internal {
        //Validate Contract's Designation
        require(keccak256(abi.encodePacked(IConfig(config).symbol())) == keccak256(abi.encodePacked("YJConfig")), "Invalid Config Contract");
        //Set
        _CONFIG = IConfig(config);
    }

    //-- Assoc

    ////Get Contract Association
    function getAssoc(string memory key) public view override returns(address) {
        //Validate
        require(_assoc[key] != address(0) , string(abi.encodePacked("Faild to Get Assoc: ", key)));
        return _assoc[key];
    }

    //Set Association
    function setAssoc(string memory key, address contract_) external onlyOwner {
        _setAssoc(key, contract_);
    }

    //Set Association
    function _setAssoc(string memory key, address contract_) internal {
        _assoc[key] = contract_;
    }

    //--- Factory 

    /// Make a new Jurisdiction
    function jurisdictionMake(string calldata name_, string calldata uri_) external override returns (address) {
        //Validate
        // require(beaconJurisdiction != address(0), "Jurisdiction Beacon Missing");      //Redundant

        console.log("Deploy J", beaconJurisdiction);

        //Deploy
        BeaconProxy newJurisdictionProxy = new BeaconProxy(
            beaconJurisdiction,
            abi.encodeWithSelector(
                IJurisdiction( payable(address(0)) ).initialize.selector,
                address(this),   //Hub
                name_,          //Name
                uri_            //Contract URI
                // "Anti-Scam Jurisdiction",
                // "YJ_CASE",      //Symbol
                // _msgSender()    //Birth Parent (Container)
            )
        );
        //Event
        emit ContractCreated("jurisdiction", address(newJurisdictionProxy));
        //Remember
        _jurisdictions[address(newJurisdictionProxy)] = true;
        //Return
        return address(newJurisdictionProxy);
    }

    /// Make a new Case
    function caseMake(
        string calldata name_
        , DataTypes.RuleRef[] memory addRules
        , DataTypes.InputRole[] memory assignRoles
    ) external override returns (address) {
        //TODO: Validate Caller Permissions (A Jurisdiction)

        //Assign Case ID
        // _caseIds.increment(); //Start with 1
        // uint256 caseId = _caseIds.current();

        //Validate
        // require(beaconCase != address(0), "Case Beacon Missing");    //Redundant
        //Deploy
        BeaconProxy newCaseProxy = new BeaconProxy(
            beaconCase,
            abi.encodeWithSelector(
                ICase( payable(address(0)) ).initialize.selector,
                name_,          //Name
                "YJ_CASE",      //Symbol
                address(this),   //Hub
                addRules,
                assignRoles,
                _msgSender()    //Birth Parent (Container)
            )
        );
        //Event
        emit ContractCreated("case", address(newCaseProxy));
        //Remember
        _cases[address(newCaseProxy)] = msg.sender;
        //Return
        return address(newCaseProxy);
    }

    /// Add Reputation (Positive or Negative)       /// Opinion Updated
    function repAdd(address contractAddr, uint256 tokenId, string calldata domain, bool rating, uint8 amount) public override {

        //TODO: Validate - Known Jurisdiction
        // require(_jurisdictions[_msgSender()], "NOT A VALID JURISDICTION");

        // console.log("Hub: Add Reputation to Contract:", contractAddr, tokenId, amount);
        // console.log("Hub: Add Reputation in Domain:", domain);
        address avatarContract = getAssoc("avatar");
        //Update Avatar's Reputation    //TODO: Just Check if Contract Implements IRating
        if(avatarContract != address(0) && avatarContract == contractAddr){
            _repAddAvatar(tokenId, domain, rating, amount);
        }
    }

    /// Add Repuation to Avatar
    function _repAddAvatar(uint256 tokenId, string calldata domain, bool rating, uint8 amount) internal {
        address avatarContract = getAssoc("avatar");
        // require(avatarContract != address(0), "AVATAR_CONTRACT_UNKNOWN");
        // repAdd(avatarContract, tokenId, domain, rating, amount);
        IAvatar(avatarContract).repAdd(tokenId, domain, rating, amount);
    }

    //-- Upgrades

    /// Upgrade Case Implementation
    function upgradeCaseImplementation(address newImplementation) public onlyOwner {
        //Validate Interface
        // require(IERC165(newImplementation).supportsInterface(type(ICase).interfaceId), "Implmementation Does Not Support Case Interface");  //Might Cause Problems on Interface Update. Keep disabled for now.

        //Upgrade Beacon
        UpgradeableBeacon(beaconCase).upgradeTo(newImplementation);
        //Upgrade Event
        // emit UpdatedCaseImplementation(newImplementation);
        emit UpdatedImplementation("case", newImplementation);
    }

    /// Upgrade Jurisdiction Implementation [TBD]
    function upgradeJurisdictionImplementation(address newImplementation) public onlyOwner {
        //Validate Interface
        // require(IERC165(newImplementation).supportsInterface(type(ICase).interfaceId), "Implmementation Does Not Support Case Interface");  //Might Cause Problems on Interface Update. Keep disabled for now.

        //Upgrade Beacon
        UpgradeableBeacon(beaconJurisdiction).upgradeTo(newImplementation);
        //Upgrade Event
        emit UpdatedImplementation("jurisdiction", newImplementation);
    }

}