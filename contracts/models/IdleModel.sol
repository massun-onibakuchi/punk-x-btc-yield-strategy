// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../ModelStorage.sol";
import "../interfaces/ModelInterface.sol";
import "../3rdDeFiInterfaces/IdleTokenV3Interface.sol";
import "../3rdDeFiInterfaces/IUniswapV2Router.sol";

contract IdleModel is ModelInterface, ModelStorage {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event Swap(uint256 idleAmount, uint256 underlying);

    uint256 public constant EXP_SCALE = 1e18;
    address public idleToken;
    address public govToken;
    address public uRouterV2;
    address public referral;

    function initialize(
        address forge_,
        address token_,
        address idleToken_,
        address govToken_,
        address uRouterV2_,
        address referral_
    ) public {
        setForge(forge_);
        addToken(token_); // underlyingToken
        idleToken = idleToken_; // e.g. IdleWBTC (best-yield strategy)
        govToken = govToken_; // IDLE
        uRouterV2 = uRouterV2_;
        referral = referral_; // idle fi reffral
    }

    function underlyingBalanceInModel() public view virtual override returns (uint256) {
        return IERC20(token(0)).balanceOf(address(this));
    }

    function underlyingBalanceWithInvestment() public view virtual override returns (uint256) {
        return
            underlyingBalanceInModel().add(
                IIdleToken(idleToken).tokenPrice().mul(_idleTokenBalanceOf()).div(EXP_SCALE)
            );
    }

    /**
     * @notice invest underlying in this contract to idle fi
     */
    function invest() public virtual override {
        uint256 balance = underlyingBalanceInModel();
        IERC20(token(0)).safeApprove(idleToken, balance);
        IIdleToken(idleToken).mintIdleToken(balance, false, referral);
        emit Invest(balance, block.timestamp);
    }

    /**
     * @notice claim governance token and swap to underlying, then reinvest underlying.
     */
    function reInvest() public virtual {
        _claimGovToken();
        _swapGovTokenToUnderlying();
        invest();
    }

    /**
     * @dev Withdraw all in model. accrued govanance are swapped to underlying.
     */
    function withdrawAllToForge() public virtual override OnlyForge {
        _redeemUnderlying(_idleTokenBalanceOf(), address(this));
        _swapGovTokenToUnderlying();
        uint256 allBalance = underlyingBalanceInModel();
        IERC20(token(0)).safeTransfer(forge(), allBalance);
        emit Withdraw(allBalance, forge(), block.timestamp);
    }

    function withdrawToForge(uint256 amount) public virtual override OnlyForge {
        withdrawTo(amount, forge());
    }

    /**
     * @dev Redeems interest bearing asset and claim accrued govnance tokens.
     * @dev only transfer underlying token
     * @param amount amount of underlying that caller want to withdraw
     */
    function withdrawTo(uint256 amount, address to) public virtual override OnlyForge {
        IERC20 uToken = IERC20(token(0));
        uint256 balanceBefore = uToken.balanceOf(address(this));

        if (amount > balanceBefore) {
            uint256 amountToWithdraw = amount.sub(balanceBefore);
            _redeemUnderlying(amountToWithdraw, address(this));
            uint256 balanceAfter = uToken.balanceOf(address(this));
            uint256 _diff = balanceAfter.sub(balanceBefore);

            if (amountToWithdraw > _diff) {
                amount = balanceBefore.add(_diff);
            }
        }

        uToken.safeTransfer(to, amount);
        emit Withdraw(amount, to, block.timestamp);
    }

    /**
     * @param amount amount of underlying to be redeemed
     * @param account idleToken holder address
     * @return redeemedAmounts  amount of underlying tokens redeemed
     */
    function _redeemUnderlying(uint256 amount, address account) internal returns (uint256) {
        uint256 _idleTokenBalance = amount.mul(EXP_SCALE).div(IIdleToken(idleToken).tokenPriceWithFee(account));
        return IIdleToken(idleToken).redeemIdleToken(_idleTokenBalance);
    }

    function _idleTokenBalanceOf() internal view returns (uint256) {
        return IERC20(idleToken).balanceOf(address(this));
    }

    /**
     * @dev Claim only accrued govnance token. this method doesn't redeem IdleToken.
     */
    function _claimGovToken() internal {
        IIdleToken(idleToken).redeemIdleToken(0);
    }

    /**
     * @notice swap gov token to underlying if any.
     * @dev An insufficient amount of governor tokens in the input will
     * @dev cause the output to go to 0 when swapped by uniswap and cause a revert.
     */
    function _swapGovTokenToUnderlying() internal {
        uint256 balance = IERC20(govToken).balanceOf(address(this));
        if (balance > 0) {
            IERC20(govToken).safeApprove(uRouterV2, balance);

            address[] memory path = new address[](3);
            path[0] = address(govToken);
            path[1] = IUniswapV2Router02(uRouterV2).WETH();
            path[2] = address(token(0));

            IUniswapV2Router02(uRouterV2).swapExactTokensForTokens(
                balance,
                1,
                path,
                address(this),
                block.timestamp + (15 * 60)
            );

            emit Swap(balance, underlyingBalanceInModel());
        }
    }
}
