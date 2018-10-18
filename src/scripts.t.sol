pragma solidity ^0.4.24;

import "ds-test/test.sol";
import "ds-token/token.sol";
// import "ds-chief/chief.sol";

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

contract NonceDeployer {
    function deploy() public returns (NonceService) { return new NonceService(); }
}

contract ProxyDeployer {
    function deploy(address a, WhiteList b) public returns (Proxy) { return new Proxy(a, b); }
}

contract StoreDeployer {
    function deploy() public returns (Store) { return new Store(); }
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

contract ScriptsTest is DSTest {
    NonceDeployer nonceDeployer;
    ProxyDeployer proxyDeployer;
    StoreDeployer storeDeployer;
    TestScript       testScript;
    NonceService nonces;
    Relay relayScript;
    Auths authScript;
    ListFab listFab;
    DSToken gov;

    Gal ava;
    Gal liv;
    Gal ali;


    function setUp() public {
        // warning: the addresses deterministically generated here are relevant to the signed message we use to test the relay script
        // changing anything in this function will probably require you to re-sign your testing message
        nonceDeployer = new NonceDeployer();
        proxyDeployer = new ProxyDeployer();
        storeDeployer = new StoreDeployer(); 

        listFab       = new ListFab();
        authScript    = new Auths();
        testScript    = new TestScript();
        relayScript   = new Relay();

        gov           = new DSToken("GOV");
        ava           = new Gal();
        liv           = new Gal();
        ali           = new Gal();
    }

    event A(address a);
    function test_relay() public {
        gov.mint(10 ether);
        NonceService _nonces = nonceDeployer.deploy();
        Store         _store = storeDeployer.deploy();
        WhiteList      _list = listFab.newList(new address[](0));
        Proxy         _proxy = proxyDeployer.deploy(this, _list);

        _list.rely("authed", testScript);
        _list.rely("anyone", relayScript);

        ava.setProxy(_proxy);
        liv.setProxy(_proxy);

        // message signed off chain, very sensitive to changes in this setup
        uint8   v = 28;
        bytes32 r = 0x922981df7b1831e662db3ea56c8c778a2cf123c1bceec12c4885094f847c3d40;
        bytes32 s = 0x1e7eff3404512eb9a1597f1e744cd75ccb02557da280fc5227485eba7d14d5eb;
        address authedSigner = 0x00cd2a3d9f938e13cd947ec05abc7fe734df8dd826;

        // give authedSigner auth in the proxy (we can do this b/c we are the owner) 
        _proxy.forward(authScript, abi.encodeWithSignature(
            "rely(address)", authedSigner
        ));

        // give proxy some gov for relay payout
        gov.push(_proxy, 10 ether);
        assertEq(gov.balanceOf(_proxy), 10 ether);
        // liv will be our relayer here
        assertEq(gov.balanceOf(liv), 0 ether);

        // this is the action our authed signer wants performed
        bytes32 word = "relayed";
        bytes memory _data = abi.encodeWithSignature(
            "setStoreItem(address,bytes32)", _store, word
        );
        assertEq(_store.word(), "");
    }



    //     // liv sends the signature to the approved relay script 
    //     assertTrue(liv.tryForward(relayScript, abi.encodeWithSignature(
    //         "verify(address,address,bytes,address,uint256,uint8,bytes32,bytes32)",
    //         authedSigner, testScript, _data, gov, 1 ether, v, r, s
    //     )));

    //     // should perform the authed signer's action
    //     assertEq(store.word(), "mea");
    //     assertEq(gov.balanceOf(liv), 1 ether);

    //     // can't reuse the signature
    //     assertTrue(!liv.tryForward(relayScript, abi.encodeWithSignature(
    //         "verify(address,address,bytes,address,uint256,uint8,bytes32,bytes32)",
    //         authedSigner, testScript, _data, gov, 1 ether, v, r, s
    //     )));
    // }
 
    function test_tokens_script() public { }

}