// VoteProxy - vote w/ a hot or cold wallet using a proxy identity
pragma solidity ^0.4.24;

import "ds-thing/thing.sol";
import "ds-chief/chief.sol";

contract ListLike {
    function anyone_can_call(address) public returns (bool);
    function authed_can_call(address) public returns (bool);
}

contract Proxy is DSNote {
    address public owner;
    address public  list;
    mapping    (address => bool) public wards;
    constructor(address _owner, address _list) public { owner = _owner; list = _list; }
    function() public payable { }

    function forward(address app, bytes data) public {
        bool can  = msg.sender == owner;
        bool may  = can || (wards[msg.sender] && ListLike(list).authed_can_call(app));
        bool will = may || ListLike(list).anyone_can_call(app);
        require(will && execute(app, data));
    }

    function execute(address app, bytes data) internal note returns (bool succeeded) {
        assembly {
            succeeded := delegatecall(sub(gas, 5000), app, add(data, 0x20), mload(data), 0, 0)
        }
    }
}