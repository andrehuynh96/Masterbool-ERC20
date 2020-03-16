pragma solidity ^0.5.0;

contract LockingStorage {
    struct Pool {
        address owner;
        address tokenAddr;
        uint256 reserveTokenAmount;
        uint256 availableTokenAmount;
        bool isClosed;
        bool needWhitelist;
        string name;
    }

    struct Plan {
        uint256 poolId;
        uint256 duration;
        uint256 annualInterestRate;
        uint256 interestRate;
        bool isClosed;
    }

    struct DepositInfo {
        address owner;
        uint256 planId;
        uint256 poolId;
        uint256 partnerId;
        uint256 amount;
        uint256 depositAt; // Timestamp
        bool isClosed;
    }

    mapping(address=>bool) internal whitelist;
    mapping(uint256=>Pool) internal pools;
    mapping(uint256=>Plan) internal plans;
    DepositInfo[] internal deposits;
    // mapping(uint=>DepositInfo) deposits;
    // uint256 depositCount;

    // The interest rate precision is 2
    // The interest rate is calculated by devided by 10000
    // 100%  = 10000
    // 99.5% = 9950
    // 6.23% = 623
    // 1%    = 100
    // 0.55% = 55
    uint256 constant internal interestBase = 10_000;

    uint256 constant internal SECONDS_PER_YEAR = 60*60*24*365;

    event CreatePool(uint256 indexed poolId, string name, address indexed tokenAddr, uint256 reserveTokenAmount, bool needWhitelist);
    event ChangePoolReserveAmount(uint256 indexed poolId, uint256 newAmount, uint256 availableAmount);
    event ChangePoolWhitelist(uint256 indexed poolId, bool needWhitelist);
    event ChangePoolStatus(uint256 indexed poolId, bool isClosed);

    event ChangePlanStatus(uint256 indexed planId, uint256 indexed poolId, bool isClosed);
    event AddPlan(uint256 indexed planId, uint256 indexed poolId, uint256 lockDuration, uint256 annualInterestRate, uint256 interestRate);

    event AddToWhitelist(address addr);
    event RemoveFromWhitelist(address addr);

    event CreatePool(uint indexed poolId, address indexed poolOwner, address indexed tokenAddress);

   

    event Deposit(uint indexed poolId , uint indexed planId, uint partnerId, uint depositId, address indexed depositor, address tokenAddr, uint tokenAmount, uint depositAt);
    event Withdraw(uint indexed poolId , uint indexed planId, uint partnerId, uint indexed depositId,  address tokenAddr, address depositorAddr, address recipientAddr, uint amount);

    event ActivatePoolOwner(address poolOwnerAddr);
    event DeactivatePoolOwner(address poolOwnerAddr);

}