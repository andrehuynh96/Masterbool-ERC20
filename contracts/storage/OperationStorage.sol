pragma solidity ^0.5.0;

contract OperationStorage {
    mapping(address=>bool) internal operators;
    mapping(uint256=>bool) internal partners;

    event AddOperator(address operatorAddr);
    event RemoveOperator(address operatorAddr);
    event AddPartner(uint256 partnerId);
    event RemovePartner(uint256 partnerId);
}