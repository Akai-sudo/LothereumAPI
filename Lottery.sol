pragma solidity ^0.4.25;
//import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";
import "github.com/provable-things/ethereum-api/provableAPI_0.4.25.sol";

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
            provable_query("URL", "json(https://jacksonng.org/codetest/random.php/).random");
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
