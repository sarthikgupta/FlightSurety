pragma solidity >=0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;
    // Contract constants
    uint256 public constant MIN_FUNDING_AMOUNT = 10 ether;
    uint8 private constant MULTIPARTY_CONSENSUS_COUNT = 4;
    uint256 public constant MAX_INSURANCE_FEE = 1 ether;
    address private contractOwner;          // Account used to deploy contract
    FlightSuretyData _flightSuretyData;
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational()
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    modifier requireDataIsOperational()
    {
         // Modify to call data contract's status
        require(_flightSuretyData.isOperational(), "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsAirlineNotRegistered(address airline)
    {
        require(!_flightSuretyData.isAirlineRegistered(airline), "Airline already registered");
        _;
    }
     modifier requireIsAirlineRegistered(address airline)
    {
        require(_flightSuretyData.isAirlineRegistered(airline), "Airline not registered");
        _;
    }

    modifier requireIsAirlineFunded(address airline)
    {
    require(_flightSuretyData.getAirlineFunds(airline) >= MIN_FUNDING_AMOUNT,
            "Airline Cannot participate in regsiterting until funding of 10 ETH");
        _;
    }

    modifier requireIsCallerAirlineRegistered(address airline)
    {

        require(_flightSuretyData.isAirlineRegistered(airline), "Airline not registered");
        _;
    }

    modifier requireIsTimestampValid(uint timestamp)
    {
       uint currentTime = block.timestamp;
       require(timestamp >= currentTime,"Timetstamp is not valid");
        _;
    }



    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address dataContract
                                )
                                public
    {
        contractOwner = msg.sender;
        _flightSuretyData = FlightSuretyData(dataContract);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

   function isOperational()
                            public
                            view
                            returns(bool)
    {
        return operational;
    }

    function setOperatingStatus
                            (
                                bool mode
                            )
                            external
                            requireContractOwner
    {
        operational = mode;
    }
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/



   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline
                            (
                                address airline
                            )
                            external
                            requireIsOperational
                            requireIsAirlineNotRegistered(airline)
                            requireIsCallerAirlineRegistered(msg.sender)
                            requireDataIsOperational
                            returns(bool success, uint256 votes)
    {
        require(airline != address(0),"Address of airline cannot be zero");
        uint256 registeredAirlines = _flightSuretyData.getCountofRegisteredAirlines();
        uint256 fundedAirlines = _flightSuretyData.getCountofFundedAirlines();
        success = false;
        address[] memory airlineVotes;
        if(registeredAirlines < MULTIPARTY_CONSENSUS_COUNT) {
            success = _flightSuretyData.registerAirline(airline);
        }

        else {
            require(_flightSuretyData.isActiveAirline(msg.sender),"You are not active airline. Please fund 10ETH for participation in registration of other airlines.");
            require(!_flightSuretyData.hasAirlineVoted(airline,msg.sender),"You have already voted for this airline");
            _flightSuretyData.addAirlineVotes(airline,msg.sender);
            airlineVotes = _flightSuretyData.getAirlineVotes(airline);
            if(airlineVotes.length >= fundedAirlines.div(2))
            {
                 success = _flightSuretyData.registerAirline(airline);
            }
        }
    return(success,airlineVotes.length);
    }

    // Fund an airline
    function airlineFund() public payable
    requireIsOperational
    requireDataIsOperational
    requireIsAirlineRegistered(msg.sender)
    {
        require(_flightSuretyData.getAirlineFunds(msg.sender) == 0,"Airline is already funded.");
        require(msg.value >= MIN_FUNDING_AMOUNT,"Fund can not be less than 10ETH");
        _flightSuretyData.fundAirline.value(msg.value)(msg.sender);
    }

    // Get total votes an airline got
    function getAirlineVote(address newAirline) external view
    requireDataIsOperational
    returns(address[] memory)
    {
        address[] memory votes = _flightSuretyData.getAirlineVotes(newAirline);
        return votes;
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight
                                (
                                    address airline,
                                    string flight,
                                    uint timestamp
                                )
                                external
                                payable
                                requireIsOperational
                                requireDataIsOperational
                                requireIsAirlineRegistered(airline)
                                requireIsTimestampValid(timestamp)
                        
    {
        require(!_flightSuretyData.isinsured(airline,flight,timestamp,msg.sender),"You are already insured");
        require(msg.value != 0,"Insurance fee can not be zero.");
        require(msg.value <= MAX_INSURANCE_FEE, "Insurance fee must be less than 1 ether");
        _flightSuretyData.buy.value(msg.value)(msg.sender, flight, timestamp, airline);
    }

   /**
    * @dev Called after oracle has updated flight status
    *
    */
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
                                requireIsOperational
                                requireDataIsOperational
    {
        if(statusCode == STATUS_CODE_LATE_AIRLINE) {
            _flightSuretyData.creditInsurees(airline,flight,timestamp);
        }
    }



    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            external
                            view
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        internal
                        pure
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (
                                address account
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    function getExistingAirlines
                            (

                            )
                             public
                             view
                             requireIsOperational
                             requireDataIsOperational
                            returns(address[])
        {
         return _flightSuretyData.getAirlines();
        }

    function getAirlineFunds
                            ()
                             public
                             view
                             requireIsOperational
                             requireDataIsOperational
                             requireIsCallerAirlineRegistered(msg.sender)
                            returns(uint funds)
        {
         return _flightSuretyData.getAirlineFunds(msg.sender);
        }

    function getBalance() public view
        requireIsOperational
        requireDataIsOperational
        returns(uint funds)
    {
        return _flightSuretyData.getBalance(msg.sender);
    }

    function withdrawFunds
            (
                uint amount
            )
            public
            requireIsOperational
            requireDataIsOperational
            returns(uint funds)
            {
               uint balance = _flightSuretyData.getBalance(msg.sender);
                require(amount <= balance, "Requested amount exceeds balance");
                 // returns remaining balance
                 return _flightSuretyData.withdrawFunds(amount,msg.sender);
            }

// endregion

}

contract FlightSuretyData {
  function isOperational() public view returns(bool);
    function isAirlineRegistered(address airline) public view returns (bool);
    function registerAirline(address airline) external returns (bool success);
    function fundAirline(address airline) external payable;
    function buy(address passenger, string flight, uint256 timestamp,address airline) external payable;
    function creditInsurees(address airline, string flight, uint256 timestamp) external;
    function getAirlines() external view returns(address[]);
    function getAirlineFunds(address airline) external view  returns(uint funds);
    function isinsured(address airline,string flight,uint timestamp,address passenger) external view returns(bool);
    function getBalance(address passenger) external view returns(uint);
    function withdrawFunds(uint amount,address passenger) external returns(uint);
    function getCountofRegisteredAirlines() external view returns(uint count);
    function getCountofFundedAirlines() external view returns(uint count);
    function getAirlineVotes(address newAirline) external view returns(address[]);
    function addAirlineVotes(address newAirline, address senderAddress) external returns(address[]);
    function hasAirlineVoted(address airline, address sender) external view returns (bool);
    function isActiveAirline (address airline) external view returns(bool);
    }