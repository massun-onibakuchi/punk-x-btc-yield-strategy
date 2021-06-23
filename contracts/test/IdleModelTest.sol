// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../models/IdleModel.sol";
import "../interfaces/ModelInterface.sol";
import "../3rdDeFiInterfaces/IdleTokenV3Interface.sol";
import "../3rdDeFiInterfaces/IUniswapV2Router.sol";

import "hardhat/console.sol";

contract IdleModelTest is IdleModel {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    function redeemUnderlying(uint256 amount, address account) public returns (uint256 redeemedAmounts) {
        redeemedAmounts = _redeemUnderlying(amount, account);
    }

    function claimGovToken() public {
        _claimGovToken();
    }

    function swapGovTokenToUnderlying() public {
        _swapGovTokenToUnderlying();
    }
}
