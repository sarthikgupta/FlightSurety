pragma solidity >=0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    address[] airlines;                                                 // Store all airlines's address
    mapping(address => bool) private registeredAirlines;                // List of all registered airlines - level1
    mapping(address => uint256) private authorizedContracts;            // Lists of all authorized contracts that can interact with this contract
    mapping(address => uint) private fundedAirlines;                    // List of funds of all the registered airlines - level 2
    mapping(address => address[]) private airlineVotes;                 // List of votes of all airlines
    mapping(bytes32 =>address[]) private flightinsurees;               // Key to address of all passengers insured.
    struct Insurance {
                bytes32 id;
                address owner;
                uint256 amount;
                bool isRefunded;
        }
    mapping(bytes32 => Insurance) private flightInsuranceDetails;
    mapping(address => uint256) private walletBalance;
    address[] activeairlines;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address firstAirline
                                )
                                public
    {
        contractOwner = msg.sender;
        airlines.push(firstAirline);
        registeredAirlines[firstAirline] = true;
    }

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

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsCallerAuthorized()
    {
        require(authorizedContracts[msg.sender] == 1, "Caller is not contract owner");
        _;
    }

    modifier requireIsAirlineRegistered(address airline)
    {
        require(registeredAirlines[airline] == true, "Airline is not registered");
        _;
    }

    modifier requireisAirlineNotRegistered(address airline)
    {
        require(registeredAirlines[airline] == false, "Airline already registered");
        _;
    }



    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational()
                            public
                            view
                            returns(bool)
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus
                            (
                                bool mode
                            )
                            external
                            requireContractOwner
    {
        operational = mode;
    }

    function authorizeCaller
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        authorizedContracts[contractAddress] = 1;
    }

    function deauthorizeCaller
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        delete authorizedContracts[contractAddress];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function getAirlineVotes(address airline) external view requireIsOperational returns(address[]) {
        return airlineVotes[airline];
    }

    function addAirlineVotes(address airline, address senderAddress) external requireIsOperational returns(address[]) {
        airlineVotes[airline].push(senderAddress);
    }

    function hasAirlineVoted(address airline, address sender) external view requireIsOperational returns (bool) {
        bool isAlreadyVoted = false;
        for(uint i = 0; i < airlineVotes[airline].length; i++) {
            if(airlineVotes[airline][i] == sender) {
                isAlreadyVoted = true;
            }
        }
        return isAlreadyVoted;
    }

    function getBalance(address passenger) external view
    requireIsOperational
    returns(uint) {
        uint fund = walletBalance[passenger];
    }


    function isAirlineRegistered
                            (
                                address airline
                            )
                            public
                            view
                            returns (bool)
    {
        return registeredAirlines[airline];
    }


     function getAirlineFunds
                            (
                                address airline
                            )
                            external
                            view
                            requireIsOperational
                            requireIsCallerAuthorized
                            requireIsAirlineRegistered(airline)
                             returns(uint funds)
    {
        return (fundedAirlines[airline]);
    }


   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline
                            ( address airline
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
                            requireisAirlineNotRegistered(airline)
                            returns(bool success)
    {
        require(airline != address(0),"Airline address can not be zero address");
        airlines.push(airline);
        registeredAirlines[airline] = true;
        return registeredAirlines[airline];
    }

   function getAirlines() external view requireIsOperational returns(address[]) {
       return airlines;
   }

// Fund an airline
 function fundAirline (address airline) external payable
 requireIsOperational
 requireIsCallerAuthorized
 requireIsAirlineRegistered(airline)
 {
     activeairlines.push(airline);
     fundedAirlines[airline] = fundedAirlines[airline].add(msg.value);
 }

 function isActiveAirline (address airline) external view requireIsOperational returns(bool) {
      bool isactiveairline = false;
        for(uint i = 0; i < activeairlines.length; i++) {
            if(activeairlines[i] == airline) {
                isactiveairline = true;
            }
        }
        return isactiveairline;
 }
    // Get registered airlines
    function getCountofRegisteredAirlines() external view requireIsOperational returns(uint count) {
        return airlines.length;
    }
    
    function getCountofFundedAirlines() external view requireIsOperational returns(uint count) {
        return activeairlines.length;
    }

    function isinsured(address airline, string flight, uint timestamp,address passenger) external view requireIsOperational returns(bool){
       bool isInsured = false;
        bytes32 key = getFlightKey(airline,flight,timestamp);
        bytes32 insuranceKey = keccak256(abi.encodePacked(key, passenger));
        if(flightInsuranceDetails[insuranceKey].owner == passenger) {
                isInsured = true;
            }
        return isInsured;
    }



   /**
    * @dev Buy insurance for a flight
    *
    */
    function buy
                            (
                                address  passenger,
                                string flight,
                                uint256 _timestamp,
                                address airline
                            )
                            external payable
                            requireIsOperational
                            requireIsCallerAuthorized
                            {
        uint amount = msg.value;
        bytes32 flightkey = getFlightKey(airline, flight, _timestamp);
        bytes32 insuranceKey = keccak256(abi.encodePacked(flightkey, passenger));
        flightinsurees[flightkey].push(passenger);
        flightInsuranceDetails[insuranceKey] = Insurance({
            id: insuranceKey,
            owner: passenger,
            amount: amount,
            isRefunded: false
        });
        fund(airline,amount);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address airline,
                                    string flight,
                                    uint8 timestamp
                                )
                                external
                                requireIsOperational
                                requireIsCallerAuthorized
    {
        bytes32 flightkey = getFlightKey(airline, flight, timestamp);
        address[] passengers = flightinsurees[flightkey];
        for(uint i = 0; i < passengers.length; i++)
        {
        address passenger = passengers[i];
        bytes32 insuranceKey = keccak256(abi.encodePacked(flightkey, passenger));
        require(flightInsuranceDetails[insuranceKey].id == insuranceKey, "You have not purchased the insurance for this flight.");
        require(!flightInsuranceDetails[insuranceKey].isRefunded, "You have already claimed the insurance amount.");
        uint256 currentAirlineBalance = walletBalance[airline];
        uint256 refundamount = flightInsuranceDetails[insuranceKey].amount.mul(15).div(10);
        require(refundamount <= currentAirlineBalance,"Please try again later.");
        flightInsuranceDetails[insuranceKey].isRefunded = true;
        walletBalance[airline] = currentAirlineBalance.sub(refundamount);
        walletBalance[passenger] = walletBalance[passenger].add(refundamount);
        }
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function withdrawFunds(uint amount,address passenger)
                                    external
                                    requireIsOperational
                                    requireIsCallerAuthorized
                                    returns(uint)
    {
        require(walletBalance[passenger] > 0, "There is no balance available in your wallet");
        walletBalance[passenger] = walletBalance[passenger] - amount;
        passenger.transfer(amount);

        return walletBalance[passenger];
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */
    function fund(address senderAddress, uint256 fund) internal {
        walletBalance[senderAddress] = walletBalance[senderAddress].add(fund);
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        internal
                        pure
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }



    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    


}

