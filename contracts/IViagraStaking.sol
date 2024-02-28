// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface IViagraStaking {
    function pendingRewards(address _user) external view returns (uint256);
    function deposit(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function emergencyWithdraw() external;
    function harvestRewards() external;
    function topUp(uint256 _emissionDays) external payable;
    function coqEmissionRate() external view returns (uint256);
    function totalStaked() external view returns (uint256);
    function userInfo(address _userAddress) external view returns (uint256, uint256);
    function coqTotalPending() external view returns (uint256);
}