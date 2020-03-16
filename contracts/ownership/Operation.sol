pragma solidity ^0.5.0;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.0/contracts/ownership/Ownable.sol";
import "../storage/OperationStorage.sol";
/**
 * Certificate of deposit
 * User deposit by predefined packages
 */

contract Operation is Ownable, OperationStorage {
    /**
     * Check the if msg.sender is the owner or an operator
     */
    modifier onlyAdmin() {
        require(operators[msg.sender] || (msg.sender == owner()), "Not admin");
        _;
    }
    constructor () Ownable() public {
        
    }
    /**
     * Grant creating pool permission to an address
     */
    function addOperator(address _operatorAddr) public onlyOwner() returns(bool) {
        require(!operators[_operatorAddr], "Existed");
        operators[_operatorAddr] = true;
        emit AddOperator(_operatorAddr);
        return true;
    }

    /**
     * Revoke creating pool permission of an address
     */
    function removeOperator(address _operatorAddr) public onlyOwner() returns(bool) {
        require(operators[_operatorAddr], "Does not exist");
        delete operators[_operatorAddr];
        emit RemoveOperator(_operatorAddr);
        return true;
    }

    function addPartner(uint _partnerId) public onlyAdmin() returns(bool) {
        require(!partners[_partnerId], "Existed");
        partners[_partnerId] = true;
        emit AddPartner(_partnerId);
        return true;
    }

    function removePartner(uint _partnerId) public onlyAdmin() returns(bool) {
        require(partners[_partnerId], "Does not exist");

        delete partners[_partnerId];
        emit RemovePartner(_partnerId);
        return true;
    }

    function getPartner(uint256 _id) public view returns(bool) {
        return partners[_id];
    }
    function getOperator(address _addr) public view returns(bool) {
        return operators[_addr];
    }
}