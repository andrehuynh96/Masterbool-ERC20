pragma solidity ^0.5.0;
import "../storage/LockingStorage.sol";
import "../ownership/Operation.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/math/SafeMath.sol";


/**
 * Certificate of deposit
 * Users deposit by pre-defined packages
 */

contract Locking is Operation, LockingStorage {
    using SafeMath for uint256;

    constructor() Operation() public {

    }

    /**
     * Create a new pool
     */
    function createPool(
        uint256 _poolId,
        string memory _poolName,
        address _tokenAddr,
        uint256 _reserveTokenAmount,
        bool _needWhitelist
    ) public onlyAdmin() returns(uint) {
        Pool storage p = pools[_poolId];
        require(p.owner == address(0), "Existed");
        // Pool memory p;
        p.name = _poolName;
        p.tokenAddr = _tokenAddr;
        p.reserveTokenAmount = _reserveTokenAmount;
        p.availableTokenAmount = _reserveTokenAmount;
        p.needWhitelist = _needWhitelist;
        p.owner = msg.sender;

        pools[_poolId] = p;

        emit CreatePool(_poolId, _poolName, p.tokenAddr, p.reserveTokenAmount, p.needWhitelist);

        return _poolId;
    }

    function changePoolReserveAmount(uint256 _poolId, uint256 _newAmount) public onlyAdmin() returns(bool) {
        Pool storage p = pools[_poolId];
        require(p.owner != address(0), "Pool does not exist");
        if (_newAmount >= p.reserveTokenAmount) {
            uint256 addAmount = _newAmount.sub(p.reserveTokenAmount);
            p.availableTokenAmount = p.availableTokenAmount.add(addAmount);
        } else {
            uint256 reduceAmount = p.reserveTokenAmount.sub(_newAmount);
            require(reduceAmount <= p.availableTokenAmount, "Reduce amount is too big");

            p.availableTokenAmount = p.availableTokenAmount.sub(reduceAmount);
        }
        p.reserveTokenAmount = _newAmount;
        emit ChangePoolReserveAmount(_poolId, _newAmount, p.availableTokenAmount);
    }

    function changePoolWhitelistNeed(uint256 _poolId, bool _needWhitelist) public onlyAdmin() returns(bool) {
        Pool storage p = pools[_poolId];
        require(p.owner != address(0), "Pool does not exist");
        p.needWhitelist = _needWhitelist;
        emit ChangePoolWhitelist(_poolId, _needWhitelist);
    }
    function changePoolStatus(uint256 _poolId, bool _isClosed) public onlyAdmin() returns(bool) {
        Pool storage p = pools[_poolId];
        require(p.owner != address(0), "Pool does not exist");
        p.isClosed = _isClosed;
        emit ChangePoolStatus(_poolId, _isClosed);
    }

    /**
     * Add a new plan to a pool
     */
    function addPlan(
        uint256 _poolId,
        uint256 _planId,
        uint256 _lockDuration,
        uint256 _annualInterestRate
    ) public onlyAdmin() returns(uint256 planId){
        require(_annualInterestRate > 0, "Interest rate must be greater than zero");
        Pool storage p = pools[_poolId];
        require(p.owner != address(0), "Pool does not exist");

        require(plans[_planId].duration == 0, "Plan id is existed");
        require(_lockDuration > 0, "Lock duration must be greater than zero");
        uint256 interestRate = _lockDuration.mul(_annualInterestRate).div(SECONDS_PER_YEAR);
        require(interestRate > 0, "Interest rate is too small");
        Plan memory plan = Plan({
            poolId: _poolId,
            duration: _lockDuration,
            annualInterestRate: _annualInterestRate,
            interestRate: interestRate,
            isClosed: false
        });
        plans[_planId] = plan;

        emit AddPlan(_planId, _poolId,_lockDuration, _annualInterestRate, interestRate);
        return _planId;
    }

    /**
     * Change status of a plan in a pool
     * Set status=true to disable a plan
     */
    function changePlanStatus(uint256 _planId, bool _isClosed) public onlyAdmin() returns(bool) {
        Plan storage plan = plans[_planId];

        require(plan.duration > 0, "Plan does not exist");

        plan.isClosed = _isClosed;

        emit ChangePlanStatus(_planId, plan.poolId, _isClosed);

        return true;
    }

    function addToWhitelist(address _addr) public onlyAdmin() returns(bool) {
        require(!whitelist[_addr], "Already in whitelist");
        whitelist[_addr] = true;
        emit AddToWhitelist(_addr);
        return true;
    }
    function removeFromWhitelist(address _addr) public onlyAdmin() returns(bool) {
        require(whitelist[_addr], "Not in whitelist");
        whitelist[_addr] = false;
        emit RemoveFromWhitelist(_addr);
        return true;
    }

    /**
     * Deposit token to a pool
     */
    function deposit(uint256 _poolId, uint256 _partnerId, uint256 _planId, uint256 _tokenAmount) external returns(uint256 depositId) {
        Pool storage p = pools[_poolId];
        require(p.owner != address(0), "Pool does not exist");
        require(!p.isClosed, "Pool is closed");

        if (p.needWhitelist) {
            require(whitelist[msg.sender], "Not in whitelist");
        }

        Plan storage plan = plans[_planId];
        require(plan.duration > 0, "Plan does not exist");
        require(!plan.isClosed, "Plan is closed");

        require(partners[_partnerId], "Partner does not exist");

        uint256 estimateInterest = plan.interestRate.mul(_tokenAmount).div(interestBase);
        require(estimateInterest > 0, "Deposit amount is too small");
        require(estimateInterest <= p.availableTokenAmount, "Insufficient avaiable token in pool");
        p.availableTokenAmount = p.availableTokenAmount.sub(estimateInterest);

        // Transfer token
        bool transferred = _executeTransferFrom(p.tokenAddr, msg.sender, address(this), _tokenAmount);
        require(transferred, "Can not transfer token");

        DepositInfo memory d;
        d.owner = msg.sender;
        d.poolId = _poolId;
        d.planId = _planId;
        d.partnerId = _partnerId;
        d.amount = _tokenAmount;
        d.depositAt = block.timestamp;

        depositId = deposits.length;
        deposits.push(d);

        emit Deposit(_poolId, _planId, _partnerId, depositId, d.owner, p.tokenAddr, d.amount, d.depositAt);

        return depositId;
    }

    /**
     * Close a deposit and withdraw token.
     */
    function withdraw(uint256 _depositId, address _recipientAddr) external returns(bool) {
        DepositInfo storage d = deposits[_depositId];
        require(d.owner == msg.sender, "Not depositor");
        require(!d.isClosed, "Is closed");

        // Check mature
        Pool storage p = pools[d.poolId];
        Plan storage plan = plans[d.planId];
        uint256 matureTime = plan.duration + d.depositAt;

        require(matureTime <= block.timestamp, "Immature");

        // Send token
        bool transferred = _executeTransfer(p.tokenAddr, _recipientAddr, d.amount);
        require(transferred, "Can not transfer token");

        deposits[_depositId].isClosed = true;

        emit Withdraw(
            d.poolId,
            d.planId,
            d.partnerId,
            _depositId,
            p.tokenAddr,
            d.owner,
            _recipientAddr,
            d.amount
        );
        return true;
    }

    /**
     * Get info of a pool
     */
    function getPoolInfo(uint256 _poolId) external view returns(address, uint256, uint256, bool, bool) {
        Pool storage p = pools[_poolId];

        return (
            p.tokenAddr,
            p.reserveTokenAmount,
            p.availableTokenAmount,
            p.isClosed,
            p.needWhitelist
        );
    }

    /**
     * Get info of a plan
     */
    function getPlanInfo(uint256 _planId) external view returns(uint256, uint256, uint256, uint256, bool) {
        Plan storage plan = plans[_planId];

        return (
            plan.poolId,
            plan.duration,
            plan.annualInterestRate,
            plan.interestRate,
            plan.isClosed
        );
    }

    /**
     * Get info of a deposit
     */
    function getDepositInfo(
        uint256 _depositId
    ) external view returns(
        uint256,
        uint256,
        uint256,
        address,
        address,
        uint256,
        uint256,
        uint256,
        bool
    ) {
        DepositInfo storage d = deposits[_depositId];
        Pool storage p = pools[d.poolId];
        Plan storage plan = plans[d.planId];

        return (
            d.poolId,
            d.partnerId,
            d.planId,
            d.owner,
            p.tokenAddr,
            d.amount,
            plan.duration,
            d.depositAt,
            d.isClosed
        );
    }

    function getWhitelist(address _addr) public view returns(bool) {
        return whitelist[_addr];
    }

    function _executeTransferFrom(address tokenAddr, address from, address to, uint256 amount) internal returns(bool){
        bytes memory payload = abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount);
        (bool succ,) = tokenAddr.call(payload);
        return succ;
    }

    function _executeTransfer(address tokenAddr, address to, uint256 amount) internal returns(bool){
        bytes memory payload = abi.encodeWithSignature("transfer(address,uint256)", to, amount);
        (bool succ,) = tokenAddr.call(payload);
        return succ;
    }


}