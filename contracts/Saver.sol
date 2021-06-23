// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

struct Saver {
    uint256 createTimestamp;
    uint256 startTimestamp;
    uint256 count;
    uint256 interval;
    uint256 mint;
    uint256 released;
    uint256 accAmount;
    uint256 relAmount;
    uint256 score;
    uint256 status;
    uint256 updatedTimestamp;
}

struct Transaction {
    bool pos;
    uint256 timestamp;
    uint256 amount;
}
