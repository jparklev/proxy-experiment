pragma solidity ^0.4.24;

import "ds-test/test.sol";

import "./proxy.sol";
import "./scripts.sol";
import "./list.sol";

contract Gal {
    Proxy public proxy;

    function setProxy(Proxy proxy_) public { proxy = proxy_; }

    function tryForward(address script, bytes data) public returns (bool) {
        return address(proxy).call(abi.encodeWithSignature(
            "forward(address,bytes)", script, data
        ));
    }
}

contract Store {
    bytes32 public word;
    function set(bytes32 _word) public { word = _word; }
    function get() public returns(bytes32) { return word; }
}

contract TestScript {
    function setStoreItem(address _store, bytes32 _word) public { 
        Store(_store).set(_word);
    }
}

contract VoteProxyTest is DSTest {
    TestScript testScript;
    NonceService nonces;
    Auths authScript;
    ListFab listFab;

    Gal ava;
    Gal liv;
    Gal ali;


    function setUp() public {
        listFab     = new ListFab();
        authScript  = new Auths();
        testScript  = new TestScript();
 
        ava = new Gal();
        liv = new Gal();
        ali = new Gal();
    }

    function test_user_auth() public {
        Store    _store = new Store();
        WhiteList _list = listFab.newList(new address[](0));
        Proxy    _proxy = new Proxy(this, _list);
        ava.setProxy(_proxy);
        ali.setProxy(_proxy);
        liv.setProxy(_proxy);

        // give ava ownership of the proxy
        _proxy.forward(authScript, abi.encodeWithSignature(
            "give(address)", ava
        ));

        // ava forward call
        bytes32 word = "ava";
        assertTrue(ava.tryForward(testScript, abi.encodeWithSignature(
            "setStoreItem(address,bytes32)", _store, word
        )));
        assertEq(_store.word(), "ava");

        // ali forward call, should fail as she lacks auth
        word = "ali"; 
        assertTrue(!ali.tryForward(testScript, abi.encodeWithSignature(
            "setStoreItem(address,bytes32)", _store, word
        )));
        assertEq(_store.word(), "ava");

        // ava gives ali auth
        assertTrue(ava.tryForward(authScript, abi.encodeWithSignature(
            "rely(address)", ali
        )));
        assertTrue(_proxy.wards(ali));

        // ava should still not be able to forward this call as testScript hasn't been added to the auth whitelisted
        assertTrue(!ali.tryForward(testScript, abi.encodeWithSignature(
            "setStoreItem(address,bytes32)", _store, word
        )));
        _list.rely("authed", testScript);

        // now she can call this script
        assertTrue(ali.tryForward(testScript, abi.encodeWithSignature(
            "setStoreItem(address,bytes32)", _store, word
        )));
        assertEq(_store.word(), "ali");

        // liv should fail, she has no auth and testScript hasn't been added to the "anyone" whitelist
        word = "liv"; 
        assertTrue(!liv.tryForward(testScript, abi.encodeWithSignature(
            "setStoreItem(address,bytes32)", _store, word
        )));
        assertEq(_store.word(), "ali");
        _list.rely("anyone", testScript);

        // now liv can call
        assertTrue(liv.tryForward(testScript, abi.encodeWithSignature(
            "setStoreItem(address,bytes32)", _store, word
        )));
        assertEq(_store.word(), "liv");
    }

    // the auth script is core to the proxy's usefulness, so it's tested here
    function test_auths_script() public {    
        WhiteList _list = listFab.newList(new address[](0));
        Proxy _proxy    = new Proxy(this, _list);

        // add and remove auth from an address
        assertTrue(!_proxy.wards(address(15)));
        _proxy.forward(authScript, abi.encodeWithSignature(
            "rely(address)", address(15)
        ));
        assertTrue(_proxy.wards(address(15)));
        _proxy.forward(authScript, abi.encodeWithSignature(
            "deny(address)", address(15)
        ));
        assertTrue(!_proxy.wards(address(15)));

        // change a proxy's whitelist
        assertEq(_proxy.list(), _list);
        WhiteList list_ = listFab.newList(new address[](0));
        _proxy.forward(authScript, abi.encodeWithSignature(
            "swap(address)", list_
        ));
        assertEq(_proxy.list(), list_); 

        // give the proxy to someone else
        assertEq(_proxy.owner(), this);
        _proxy.forward(authScript, abi.encodeWithSignature(
            "give(address)", address(10)
        ));
        assertEq(_proxy.owner(), address(10));
    }
}
