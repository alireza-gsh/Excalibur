// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IERC1155GUID {

    //--- Functions 

    /// Unique Members Addresses
    function uniqueMembers(uint256 id) external view returns (address[] memory);
    
    /// Unique Members Count (w/Token)
    function uniqueMembersCount(uint256 id) external view returns (uint256);
    
    /// Check if account is assigned to role
    function GUIDHas(address account, bytes32 guid) external view returns (bool);
    
    //--- Events

    /// New GUID Created
    event GUIDCreated(uint256 indexed id, bytes32 guid);
   
}
