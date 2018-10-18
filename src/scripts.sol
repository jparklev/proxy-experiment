pragma solidity ^0.4.24;

import "./proxy.sol";

contract TokenLike {
    function approve(address) public returns (bool);
    function allowance(address, address) returns (uint256);
    function transferFrom(address, address, uint256) public returns (bool);
}

contract AppLike {
    function lock(uint256) public;
    function free(uint256) public;
    function vote(address[]) public;
    function vote(bytes32) public;
    function vote(uint256, bool, bytes) public;
    function unSay(uint256) public;
}

// Recommend script for anyone, plugs into standard auth -----------------------

contract NonceService {
    mapping (address => uint256) nonces;
    function get() public returns (uint256) { return nonces[msg.sender]++; }
}

contract Relay {
    address public owner;
    address public list;
    mapping (address => bool) public wards;

    bytes32 constant DOMAIN_SEPARATOR = 0x035238edb0e361107188dc796ec7bbb404d271d3f52b32a6637a6dd19f9779e8;
    bytes32 constant ACTION_TYPEHASH  = 0x0945d0cdf3e642360d77a531787d8ad025f399f881cc8316c4271d9d9337dec5;
    NonceService constant      NONCE  = NonceService(0x0099db7a7dcb7726ec5d29d08d50685dd8d8843915);

    event A(address a);
    function verify(
        address lad, address app, bytes data, address gem, 
        uint256 amt, uint8 v, bytes32 r, bytes32 s
    ) public {
        uint256 nonce = NONCE.get();
        address gal = who(lad, app, data, gem, amt, nonce, v, r, s);
        require(lad == gal && (gal == owner || wards[gal] && ListLike(list).authed_can_call(app)));
        assembly {
            if eq(delegatecall(sub(gas, 5000), app, add(data, 0x20), mload(data), 0, 0), 0) { revert(0, 0) }
        }
        require(TokenLike(gem).transferFrom(this, msg.sender, amt));
    }

    event Digest(bytes32 digest);
    function who(
        address lad, address app, bytes data, address gem, 
        uint256 amt, uint256 nonce, uint8 v, bytes32 r, bytes32 s
    ) public returns (address) {
        bytes32 digest = keccak256(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(
                ACTION_TYPEHASH,
                lad, amt, gem, app, keccak256(data), nonce
            ))
        );
        emit Digest(digest);
        return ecrecover(digest, v, r, s);
    }
}

// Recommend scripts for owner only ------------------------------------------------

contract Auths {
    address public owner;
    address public list;
    mapping (address => bool) public wards;

    function give(address _owner) public {
        owner = _owner;
    }
    function swap(address _list) public {
        list = _list;
    }
    function rely(address _ward) public {
        wards[_ward] = true;
    }
    function deny(address _ward) public {
        wards[_ward] = false;
    }
}

contract Coins {
    function pull(address guy, address gem, uint256 wad) public {
        TokenLike(gem).transferFrom(guy, this, wad);
    }
    function push(address guy, address gem, uint256 wad) public {
        TokenLike(gem).transferFrom(this, guy, wad);
    }
    function approve(address guy, address gem) public {
        TokenLike(gem).approve(guy);
    }
}

// Recommend scripts for authed folks ------------------------------------------------

contract RestrictedCoins {
    address public owner;

    function pull(address guy, address gem, uint256 wad) public {
        TokenLike(gem).transferFrom(guy, this, wad);
    }
    function push(address gem, uint256 wad) public {
        TokenLike(gem).transferFrom(this, owner, wad);
    }
}

contract RestrictedVoteHelpers {
    address public     owner;
    AppLike constant   CHIEF = AppLike(  0x8E2a84D6adE1E7ffFEe039A35EF5F19F13057152);
    AppLike constant POLLING = AppLike(  0x8E2a84D6adE1E7ffFEe039A35EF5F19F13057152);
    TokenLike constant   GOV = TokenLike(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2);
    TokenLike constant   IOU = TokenLike(0x9AeD7A25F2d928225e6fb2388055c7363aD6727b);

    function pullLock(address guy, uint256 wad) public {
        GOV.transferFrom(guy, this, wad);
        if (GOV.allowance(this, CHIEF) != uint(-1))   GOV.approve(CHIEF);
        CHIEF.lock(wad);
    }
    function dualPullLock(address guy, uint256 wad) public {
        GOV.transferFrom(guy, this, wad);
        if (GOV.allowance(this, CHIEF) != uint(-1))   GOV.approve(CHIEF);
        CHIEF.lock(wad);
        if (IOU.allowance(this, POLLING) != uint(-1)) IOU.approve(POLLING);
        POLLING.lock(wad);
    }
    function freePush(uint256 wad) public {
        CHIEF.free(wad);
        GOV.transferFrom(this, owner, wad);
    }
    function dualFreePush(uint256 wad) public {
        POLLING.free(wad);
        CHIEF.free(wad);
        GOV.transferFrom(this, owner, wad);
    }
}

contract Voting {
    function vote(AppLike chief, address[] yays) public {
        chief.vote(yays);
    }
    function vote(AppLike chief, bytes32 slate) public {
        chief.vote(slate);
    }
    function vote(AppLike polling, uint256 id, bool yea, bytes logData) public {
        polling.vote(id, yea, logData);
    }
    function unSay(AppLike polling, uint256 id) public {
        polling.unSay(id);
    }
}
