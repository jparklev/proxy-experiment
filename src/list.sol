pragma solidity ^0.4.24;

import "ds-thing/thing.sol";
import "ds-chief/chief.sol";

contract WhiteList is DSNote, DSAuth {
    mapping(address => bool) public anyone_can_call;
    mapping(address => bool) public authed_can_call;
    function rely(bytes32 what, address addr) public note auth { 
        if (what == "authed") authed_can_call[addr] = true; 
        if (what == "anyone") anyone_can_call[addr] = true; 
    }
    function deny(bytes32 what, address addr) public note auth { 
        if (what == "authed") authed_can_call[addr] = false; 
        if (what == "anyone") anyone_can_call[addr] = false; 
    }
}

contract ListFab {
    event ListCreated(address indexed sender, address indexed list);
    function newList(DSChief chief, address[] apps) public returns (WhiteList list) {
        list = new WhiteList();
        list.setAuthority(chief);
        for (uint i = 0; i < apps.length; i++) { list.rely("authed", apps[i]); }
        list.setOwner(0);
        emit ListCreated(msg.sender, list);
    }
    function newList(address[] apps) public returns (WhiteList list) {
        list = new WhiteList();
        for (uint i = 0; i < apps.length; i++) { list.rely("authed", apps[i]); }
        list.setOwner(msg.sender);
        emit ListCreated(msg.sender, list);
    }
}