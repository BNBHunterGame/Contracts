pragma solidity ^0.8.0;

import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./openzeppelin/contracts/utils/Context.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/utils/math/SafeMath.sol";
import "./openzeppelin/contracts/security/Pausable.sol";

interface ISwapRouter {
    function WETH() external pure returns (address);

    function factory() external pure returns (address);
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}
interface ISwapPair{
    function sync() external;
}
interface ISwapFactory {
    function createPair(address tokenA, address tokenB)
    external
    returns (address pair);

}
contract BHTToken is  IERC20, IERC20Metadata,Ownable,Pausable {
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;



    uint256 private _totalSupply=0;

    string private _name="BNB Hunter Token";
    string private _symbol="BHT";
    uint256 lpFeeRate = 30;
    uint256 devFeeRate = 50;
    address public devAddress;
    address public weth;
    uint256 numTokensSellToAddToLiquidity = 1000*10**18;
    bool public swapAndLiquifyEnabled = true;
    bool inSwapAndLiquify;
    address public swapRouterAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address public swapPairAddress;
    mapping(address=>bool) whiteList;
    mapping(address=>bool) burnContracts;//which contracts can burn user's token
    event SetSetting(address indexed _owner,address _devAddress,uint256 _lpFeeRate,uint256 _devFeeRate,uint256 _numTokensSellToAddToLiquidity,bool _swapAndLiquifyEnabled,bool _enForce);
    event AddWhiteList(address indexed _owner,address[] _whiteList);
    event RemoveWhiteList(address indexed _owner,address _whiteList);
    event AddBurnContracts(address indexed _owner,address[] _addresses);
    event RemoveBurnContract(address indexed _owner,address _address);
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(address _routerAddress,address _devAddress,address _weth) {
        _mint(msg.sender, 1000000000*(10**18));
        ISwapRouter _router = ISwapRouter(_routerAddress);
        require(_routerAddress!=address(0),"invalid swap router address");
        if (_weth==address(0)){
            weth = _router.WETH();
        }else{
            weth=_weth;
        }
        swapPairAddress = ISwapFactory(_router.factory())
        .createPair(address(this),  weth);

        // set the rest of the contract variables
        swapRouterAddress = address(_routerAddress);
        devAddress = _devAddress;
        whiteList[address(this)] = true;
        whiteList[msg.sender] = true;
        if (devAddress!=address(0)){
            whiteList[devAddress] = true;
        }
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
    unchecked {
        _approve(sender, _msgSender(), currentAllowance - amount);
    }

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
    unchecked {
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);
    }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal whenNotPaused {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        uint256 contractTokenBalance = balanceOf(address(this));

        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            sender != swapPairAddress &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }



        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }

        if (whiteList[sender]||whiteList[recipient]){

        }else{
            if(swapPairAddress!=address(0)&&(swapPairAddress==sender||swapPairAddress==recipient)){
                uint256 _devAmount = amount.mul(devFeeRate).div(1000);
                _balances[devAddress] = _balances[devAddress].add(_devAmount);
                emit Transfer(sender, devAddress, _devAmount);
                uint256 _lpAmount = amount.mul(lpFeeRate).div(1000);
                _balances[address(this)] = _balances[address(this)].add(_lpAmount);
                emit Transfer(sender, address(this), _lpAmount);
                amount = amount.sub(_devAmount).sub(_lpAmount);
            }

        }
        //amount = amount.sub(_taxFee);
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");


        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);


    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
    unchecked {
        _balances[account] = accountBalance - amount;
    }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);


    }
    function burn(address _user,uint256 _amount) public{
        if (burnContracts[msg.sender]){
            _burn(_user,_amount);
        }
    }
    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }



    function setSetting(address _devAddress,uint256 _lpFeeRate,uint256 _devFeeRate,uint256 _numTokensSellToAddToLiquidity,bool _swapAndLiquifyEnabled,bool _enForce) public onlyOwner {
        require(_lpFeeRate<=100,"too big lp fee rate");
        require(_devFeeRate<=100,"too big dev fee rate");
        if(_devAddress!=address(0)){
            devAddress = _devAddress;
            whiteList[devAddress]=true;
        }
        if (_lpFeeRate>0||_enForce){
            lpFeeRate = _lpFeeRate;
        }
        if (_devFeeRate>0||_enForce){
            devFeeRate = _devFeeRate;
        }
        if (_numTokensSellToAddToLiquidity>0){
            numTokensSellToAddToLiquidity = _numTokensSellToAddToLiquidity;
        }
        swapAndLiquifyEnabled = _swapAndLiquifyEnabled;
        emit SetSetting(msg.sender,_devAddress,_lpFeeRate,_devFeeRate,_numTokensSellToAddToLiquidity,_swapAndLiquifyEnabled,_enForce);
    }

    function addWhiteList( address[] memory _addresses)  public onlyOwner {

        for(uint256 i=0;i<_addresses.length;i++){
            require(_addresses[i]!=address(0),"invalid zero address");
            whiteList[_addresses[i]] = true;
        }

        emit AddWhiteList(msg.sender,_addresses);
    }

    function removeWhiteList( address _address) public onlyOwner {
        delete whiteList[_address];
        emit RemoveWhiteList(msg.sender,_address);
    }


    function addBurnContracts( address[] memory _addresses)  public onlyOwner {

        for(uint256 i=0;i<_addresses.length;i++){
            require(_addresses[i]!=address(0),"invalid zero address");
            burnContracts[_addresses[i]] = true;
        }

        emit AddBurnContracts(msg.sender,_addresses);
    }

    function removeBurnContract( address _address) public onlyOwner {
        delete burnContracts[_address];
        emit RemoveBurnContract(msg.sender,_address);
    }

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    function swapAndLiquify(uint256 tokens) private lockTheSwap{
        // split the contract balance into halves
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance =  address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half);
        // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {


        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = weth;

        _approve(address(this), swapRouterAddress, tokenAmount);

        // make the swap
        ISwapRouter(swapRouterAddress).swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );

    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), swapRouterAddress, tokenAmount);

        // add the liquidity
        (, , uint liquidity) = ISwapRouter(swapRouterAddress).addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),//lock LP in contract
            block.timestamp
        );
        require(liquidity > 0);
    }
    function pause() external onlyOwner {
        _pause();
    }
    function unpause() external onlyOwner {
        _unpause();
    }
    receive() external payable {}
}
