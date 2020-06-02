pragma solidity ^0.4.25;
import "github.com/provable-things/ethereum-api/blob/master/provableAPI_0.4.25.sol";
import "github.com/Arachnid/solidity-stringutils/strings.sol";
import "https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary/blob/1ea8ef42b3d8db17b910b46e4f8c124b59d77c03/contracts/BokkyPooBahsDateTimeLibrary.sol";



contract OracleFutball is usingProvable {
    using strings for *;
    string public answer;
    string private matchId;
    string public status;
    string private url;
    string public url2;
    string public homeTeam;
    string public awayTeam;
    uint public goalHT;
    uint public goalAT;
    uint private tyear;
    uint private tmonth;
    uint private tday;
    uint private thour;
    uint private tminute;
    uint public timeresult;
    uint private matchset;
    event LogNewProvableQuery(string description);

   constructor() public payable {
        matchset = 0;
   }
   
    function setMatchId(string _matchId) public {
        require(matchset == 0);
        matchId = _matchId;
        url = "json(https://api-football-v1.p.rapidapi.com/v2/fixtures/id/".toSlice().concat(matchId.toSlice()); 
        url2 = url.toSlice().concat("?rapidapi-key=0fc5e0da34msh7fd9ba25fa448dcp1f206ejsndada5b83e617).api.fixtures.0.[event_date,statusShort,goalsHomeTeam,goalsAwayTeam,homeTeam,awayTeam]".toSlice()); 
        matchset +=1;
    }

    function timestampFromDateTime(uint year, uint month, uint day, uint hour, uint minute, uint second) internal pure returns (uint timestamp) {
        return BokkyPooBahsDateTimeLibrary.timestampFromDateTime(year, month, day, hour, minute, second);
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
   function __callback(bytes32 _queryId, string result) public {
        if (msg.sender != provable_cbAddress()) revert();
        answer = result;
        strings.slice memory s = result.toSlice();                
        strings.slice memory delim = ",".toSlice();                            
        string[] memory parts = new string[](s.count(delim) + 1);                  
        for (uint i = 0; i < parts.length; i++) {                              
           parts[i] = s.split(delim).toString();                               
        } 
        tyear = stringToUint(substring(parts[0], 2 , 6));
        tmonth = stringToUint(substring(parts[0], 7 , 9));
        tday = stringToUint(substring(parts[0], 10 , 12));
        thour = stringToUint(substring(parts[0], 13 , 15));
        tminute = stringToUint(substring(parts[0], 16 , 18));
        timeresult = timestampFromDateTime(tyear, tmonth, tday, thour, tminute, 60);
        status = substring(parts[1], 2 , parts[1].toSlice().len() - 1);
        goalHT = stringToUint(parts[2]);
        goalAT = stringToUint(parts[3]);
        homeTeam = substring(parts[6], 15 , parts[6].toSlice().len() - 1);
        awayTeam = substring(parts[9], 15 , parts[9].toSlice().len() - 2);
   }

   function updatePrice(uint _delay) public payable {
       if (provable_getPrice("URL") > address(this).balance) {
           emit LogNewProvableQuery("Provable query was NOT sent, please add some ETH to cover for the query fee");
       } else {
           emit LogNewProvableQuery("Provable query was sent, standing by for the answer..");
           provable_query(_delay, "URL", url2);
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
    uint private delay;

    
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
        timeend = _time + 9000;
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
        
        delay = timeend - now;
        oracleF.updatePrice.value(0.001 ether)(delay);
        currentState = State.AWAITING_END;
    }
    
    
    function declareWinner() public payable returns(string) {
        string memory _message;
        require(block.timestamp >= timeend);
        require(currentState == State.AWAITING_END);
        
        if(keccak256(abi.encodePacked(oracleF.status())) != keccak256(abi.encodePacked("FT"))) {
            oracleF.updatePrice.value(0.001 ether)(200); 
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
