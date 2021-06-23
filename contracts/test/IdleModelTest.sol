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

    function withdrawTo(uint256 amount, address to) public override OnlyForge {
        IERC20 uToken = IERC20(token(0));
        uint256 balanceBefore = uToken.balanceOf(address(this));

        // check balance
        if (amount > balanceBefore) {
            uint256 amountToWithdraw = amount.sub(balanceBefore);
            _redeemUnderlying(amountToWithdraw, address(this));
            uint256 balanceAfter = uToken.balanceOf(address(this));
            uint256 _diff = balanceAfter.sub(balanceBefore);

            console.log("input amount:>>", amount);
            console.log("amountToWthdraw :>>", amountToWithdraw);
            if (amountToWithdraw > _diff) {
                console.log("_diff :>>", _diff);
                amount = balanceBefore.add(_diff);
            }
        }
        console.log("balanceBefore:>>", balanceBefore);
        console.log("amount:>>", amount);

        uToken.safeTransfer(to, amount);
        emit Withdraw(amount, to, block.timestamp);
    }

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
