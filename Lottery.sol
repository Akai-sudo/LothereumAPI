pragma solidity ^0.4.25;


//import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";
import "github.com/provable-things/ethereum-api/provableAPI_0.4.25.sol";
//import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.6/VRFConsumerBase.sol";

//import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";


/*contract RandomNumberConsumer is VRFConsumerBase {

    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;
    //contract VRFConsumer {
     //constuctor( address _vrfCoordinator, address _link)
    constructor()
    VRFConsumerBase(
        0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
        0xa36085F69e2889c224210F603D836748e7dC0088  // LINK Token
    ) public
    {
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10 ** 18; // 0.1 LINK
    }

}*/

contract Lottery is usingProvable {
    string public betNumber;
    string public result;
    address public house;
    address public better;
    enum State { Created, Betted, Paidout, Inactive }
    State public state;

    uint randNonce = 0;
    
    event newProvableQuery(string description);
    event Aborted();
    event Betted();
    event Released();
	
    constructor() public {
        house = msg.sender;
        state = State.Created;
    }

    modifier condition(bool _condition) {
        require(_condition);
        _;
    }

    modifier onlyBetter() {
        require(msg.sender == better);
        _;
    }

    modifier onlyHouse() {
        require(msg.sender == house);
        _;
    }

    modifier inState(State _state) {
        require(state == _state);
        _;
    }

	//source: https://ethereum.stackexchange.com/questions/30912/how-to-compare-strings-in-solidity
    function compareStrings (string a, string b) public pure returns (bool){
       return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
	}
	
    function bet(string _betNumber)
        public
        inState(State.Created)
        condition(msg.value == (1 ether))
        payable
    {
        emit Betted();
        better = msg.sender;
        betNumber = _betNumber;
        state = State.Betted;
    }
    
    function abort()
        public
        onlyHouse
        inState(State.Created)
    {
        emit Aborted();
        state = State.Inactive;
        house.transfer(address(this).balance);
    }
    
    function release() 
        payable 
        public
        onlyHouse
        inState(State.Betted)
    {
        if (provable_getPrice("URL") > address(this).balance) {
            emit newProvableQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            emit newProvableQuery("Oraclize query was sent, standing by for the answer..");
            //provable_query("json(https://jacksonng.org/codetest/random.php/).random");
            //request.add("get", "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=ETH&tsyms=USD");
        }
    }

     function rand()
        public
        view
    returns(uint256)
    {
        uint256 seed = uint256(keccak256(abi.encodePacked(
            block.timestamp + block.difficulty +
            ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (now)) +
            block.gaslimit + 
            ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (now)) +
            block.number
        )));

        return (seed - ((seed / 1000) * 1000));
    }

    function randGen(uint _modulus) internal returns(uint)
    {
        randNonce++;
        return uint(keccak256(abi.encodePacked(now, msg.sender, randNonce))) % _modulus;
    }
	
	function __callback(bytes32 myid, string res) public {
        if (msg.sender != provable_cbAddress()) revert(); //bil je throw pa je deprecated
        result = res; 
        
        if (compareStrings(result,betNumber)) {
            better.transfer(address(this).balance);            
        }
        else {
            house.transfer(address(this).balance);               
        }

        emit Released();
        state = State.Paidout;
    }
}
