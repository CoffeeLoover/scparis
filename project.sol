pragma solidity ^0.4.25;
import "github.com/provable-things/ethereum-api/blob/master/provableAPI_0.4.25.sol";
import "github.com/Arachnid/solidity-stringutils/strings.sol";



contract OracleFutball is usingProvable {
    using strings for *;
    address private owner;
    string private matchId;
    string public status;
    string private url;
    string public url2;
    string public homeTeam;
    string public awayTeam;
    uint public goalHT;
    uint public goalAT;
    uint public timeresult;
    uint private matchset;
    mapping(bytes32=>bool) validIds;
    event LogNewProvableQuery(string description);
    event knowprice(uint queryprice);

   constructor() public {
       owner = msg.sender;
        matchset = 0;
   }
  
    function stringToUint(string s) internal pure returns (uint) {
        bytes memory b = bytes(s);
        uint result = 0;
        for (uint i = 0; i < b.length; i++) { // c = b[i] was not needed
            if (b[i] >= 48 && b[i] <= 57) {
                result = result * 10 + (uint(b[i]) - 48); // bytes and int are not compatible with the operator -.
            }
        }
        return result; // this was missing
    }
    
    function substring(string str, uint startIndex, uint endIndex) internal pure returns (string) {
        bytes memory strBytes = bytes(str);
        bytes memory cutted = new bytes(endIndex-startIndex);
        for(uint i = startIndex; i < endIndex; i++) {
            cutted[i-startIndex] = strBytes[i];
        }
        return string(cutted);
    }
   
    function setMatchId(string _matchId) public {
        require(matchset == 0);
        matchId = _matchId;
        url = "json(https://api-football-v1.p.rapidapi.com/v2/fixtures/id/".toSlice().concat(matchId.toSlice()); 
        url2 = url.toSlice().concat("?rapidapi-key=0fc5e0da34msh7fd9ba25fa448dcp1f206ejsndada5b83e617).api.fixtures.0.[event_timestamp,statusShort,goalsHomeTeam,goalsAwayTeam,homeTeam,awayTeam, elapsed]".toSlice()); 
        matchset +=1;
    }

   function __callback(bytes32 myid, string result) public {
        if (!validIds[myid]) revert();
        if (msg.sender != provable_cbAddress()) revert();
        strings.slice memory s = result.toSlice();                
        strings.slice memory delim = ",".toSlice();                            
        string[] memory parts = new string[](s.count(delim) + 1);                  
        for (uint i = 0; i < parts.length; i++) {                              
           parts[i] = s.split(delim).toString();                              
        } 

        timeresult = stringToUint(parts[0]);
        status = substring(parts[1], 2 , parts[1].toSlice().len() - 1);
        goalHT = stringToUint(parts[2]);
        goalAT = stringToUint(parts[3]);
        homeTeam = substring(parts[6], 15 , parts[6].toSlice().len() - 2);
        awayTeam = substring(parts[9], 15 , parts[9].toSlice().len() - 3);
        delete validIds[myid];
   }

   function updatePrice(uint _delay) public payable {
       require(tx.origin == owner);
       if (provable_getPrice("URL") > address(this).balance) {
           emit LogNewProvableQuery("Balance insuffisante pour la requête");
       } 
       else {
           emit LogNewProvableQuery("Ok requête en cours");
           bytes32 queryId = provable_query(_delay, "URL", url2);
           validIds[queryId] = true;
       }
   }
}











contract Betting {
    OracleFutball oracleF;
    using strings for *;
    enum State { AWAITING_SETTINGS, AWAITING_PAYMENT_NICO, AWAITING_PAYMENT_COCO, AWAITING_START,AWAITING_RESULT, AWAITING_END, COMPLETE}
    State public currentState;    
    address private nico;
    address private coco;
    uint private misecoco;
    uint private misenico;
    uint public betcoco;
    uint public betnico;
    uint private total;
    uint public mise;
    uint public timeend;
    string public status;
    address private winner;
    address private oracleAddress;
    string private matchId;
    uint private tie = 0;
    uint public delay;
    string public elapsed;
    
    /// initialisation: entrée par le constructeur du contrat les adresses des participants
    constructor(uint _mise, address _oracleAddress) public {
        coco = msg.sender;
        mise = _mise;
        oracleAddress = _oracleAddress;
        oracleF = OracleFutball(oracleAddress); 
    }



    function getBalance() public view returns(uint) {
        return address(this).balance;
    }
    
    
    function setMatchId(string _matchId) public {
        require(currentState == State.AWAITING_SETTINGS);
        require(msg.sender == coco);
        matchId = _matchId;
        oracleF.setMatchId(matchId);
        oracleF.updatePrice(0);  
        currentState = State.AWAITING_PAYMENT_NICO;
    }
    

    
    function getInfoMatch() public returns (string _message, uint _time) {
        string memory _tempm;

        _message = "équipe 1: ".toSlice().concat(oracleF.homeTeam().toSlice()); 
        _tempm = _message.toSlice().concat(", équipe 2: ".toSlice()); 
        _message = _tempm.toSlice().concat(oracleF.awayTeam().toSlice());
        _tempm = _message.toSlice().concat(", début du match: ".toSlice()); 
        _message = _tempm;
        _time = oracleF.timeresult();
        delay =  now + 600;
        status = oracleF.status();
        return (_message, _time);
    }    
    
    function confirmPaymentCoco(uint _betcoco) public payable {
        require(msg.sender == coco);
        require(msg.value == mise);
        require(_betcoco != betnico);
        require(currentState == State.AWAITING_PAYMENT_COCO);
        misecoco = msg.value;
        betcoco = _betcoco;
        currentState = State.AWAITING_START;
            
    }
    
    function confirmPaymentNico(uint _betnico) public payable {
        require(msg.sender != coco);
        require(msg.value == mise);
        require(currentState == State.AWAITING_PAYMENT_NICO);
        nico = msg.sender;
        currentState = State.AWAITING_PAYMENT_COCO;
        misenico = msg.value;
        betnico = _betnico;
    }
    
    function startBet() public payable {
        // revérifier que le match n'est pas commencé
        require(misenico == misecoco);
        require(currentState == State.AWAITING_START);
        require(msg.sender == coco);
        currentState = State.AWAITING_RESULT;
        oracleF.updatePrice.value(0.005 ether)(delay);
        currentState = State.AWAITING_END;
    }
    
    
    function declareWinner() public payable returns(string) {
        string memory _message;
        require(block.timestamp >= delay);
        require(currentState == State.AWAITING_END);
        
        status = oracleF.status();
        
        if(keccak256(abi.encodePacked(oracleF.status())) != keccak256(abi.encodePacked("FT"))) {
            oracleF.updatePrice.value(0.005 ether)(delay + 300); 
            _message = "Le match n'est pas encore fini";
        }
        else {
            if(oracleF.goalHT() > oracleF.goalAT()) {
                if(betcoco < betnico) {
                    winner = coco;
                }
                else {
                    winner = nico;
                }
            }
            else if(oracleF.goalHT() < oracleF.goalAT()) {
                if(betcoco < betnico) {
                    winner = nico;
                }
                else {
                    winner = nico;
                }
            }
            else {
                tie = 1;
            }
            
            if(tie == 1) {
                coco.transfer(address(this).balance / 2);
                nico.transfer(address(this).balance / 2);
            }
            else {
            winner.transfer(address(this).balance);
            }
            currentState = State.COMPLETE;
            _message = "Le match est fini";
            selfdestruct(coco);
            
        }
        
        return(_message);    
    }

}
