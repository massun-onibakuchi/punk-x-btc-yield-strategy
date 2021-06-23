// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../Saver.sol";

interface ForgeInterface {
    event CraftingSaver(address owner, uint256 index, uint256 deposit);
    event AddDeposit(address owner, uint256 index, uint256 deposit);
    event Withdraw(address owner, uint256 index, uint256 amount);
    event Terminate(address owner, uint256 index, uint256 amount);
    event Bonus(address owner, uint256 index, uint256 amount);

    function modelAddress() external view returns (address);

    function withdrawable(address account, uint256 index) external view returns (uint256);

    function countByAccount(address account) external view returns (uint256);

    function craftingSaver(
        uint256 amount,
        uint256 startTimestamp,
        uint256 count,
        uint256 interval
    ) external returns (bool);

    function addDeposit(uint256 index, uint256 amount) external returns (bool);

    function withdraw(uint256 index, uint256 amount) external returns (bool);

    function terminateSaver(uint256 index) external returns (bool);

    function countAll() external view returns (uint256);

    function totalScore() external view returns (uint256);

    function saver(address account, uint256 index) external view returns (Saver memory);

    function transactions(address account, uint256 index) external view returns (Transaction[] memory);

    function getExchangeRate() external view returns (uint256);

    function getBonus() external view returns (uint256);

    function getTotalVolume() external view returns (uint256);
}
