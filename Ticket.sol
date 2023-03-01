// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;



import "./Airline.sol";

import "hardhat/console.sol";


contract TicketMgt{
    
    event TicketConfirmed(uint fareAmount, address ticketAddr);
    event TicketBooked(address _ticketContract);
    event TicketCancelled(address ticketAddr);
    event TicketSettled(address ticketAddr);

    struct TicketDetail {
        uint flightNumber;
        uint8 seatNumber;
        string source;
        string destination;
        //string journeyDate;
        uint schedDep;
        uint schedArr;
    }
    TicketDetail _ticketDetails;

    //From portal
    //mapping(address => address[]) bookingHistory;
    address[] private customers;
    //
    
      // Stores details of the trip
    address private _ticketID;
    TicketDetail private _ticketDetail;
        // Different stages of lifetime of a ticket
    enum TicketStatus {CREATED, CONFIRMED, CANCELLED, SETTLED}
       // Stores current ticket status
    TicketStatus private _ticketStatus;

    // Addresses involved in the contract
    address private _airlineContract; // creator of this contract
    address payable private _airlineAccount;
    address payable private _customerAccount;
    AirlineManagement private _airline;

    
    // Stores fare details
    uint private _baseFare;
    uint private _totalFare;
    bool private _isFarePaid;

    // Stores creation time of this contract
    uint private _createTime;


    
    
   constructor(
            address airlineAccount_,
            address customerAccount_,
            uint flightNumber_,
            uint8 seatNumber_,
            string memory source_,
            string memory destination_,
            //string memory journeyDate_,
            uint depTime,
            uint arrTime
            //uint baseFare_ : Hardcodindg for now : TODO
        ) payable {
        _ticketID = address(this);
        //To check if deployed once set airlineCONTRACT TO CONTRACT NODE
        //if(_airlineContract == address(0)){
          //  _airlineContract = msg.sender;
        //}
        _airlineContract = msg.sender;
        _airlineAccount = payable(airlineAccount_);
        _customerAccount = payable(customerAccount_);
        _ticketStatus = TicketStatus.CREATED;
        
        _ticketDetail = TicketDetail(
            {
                flightNumber: flightNumber_,
                seatNumber: seatNumber_,
                source: source_,
                destination: destination_,
                //journeyDate: journeyDate_,
                schedDep: depTime,
                schedArr: arrTime
            }
        );
        //TODO baseFare
        //_baseFare = baseFare_;
        _baseFare = 1000000000000000000;
        //_totalFare = baseFare_;
        _totalFare = 1000000000000000000;
        _isFarePaid = false;
        _airline = AirlineManagement(_airlineContract);
        _createTime = block.timestamp;
       // console.log(msg.sender + ":" + flightNumber_ + ":"  + _airlineContract + ":" +_airlineAccount + ":"+ _customerAccount);
    
    }

    //TODO : modify to add multiple customer not just _customerAccount but iterate over mutiple netry in  customers[] 
    modifier onlyCustomer {
        require(msg.sender == _customerAccount, "Error: Only customer can do this action");
        _;
    }
    //Function exposed to Customer
    //Sequence of flow for customer : bookTicket(Create Ticket for customer if seat available)  
    //                                payFare (get Seat Nos and Transfer Amount to contract )
    // to be called from customer address
    //function bookTicket(uint flightNo) public  onlyCustomer returns (address ticketAddr) {
    //  customers.push(msg.sender);
    //   address ticket = _airline.createTicket(flightNo, msg.sender);
    //   bookingHistory[msg.sender].push(ticket);
    //    console.log("trials");
    //    return ticket;
   // }


//onlyCustome
    function tocallAirlinemethod(uint flightNumber)public {
        _ticketDetails.seatNumber = _airline.completeReservation(flightNumber);
        
        emit TicketConfirmed(_totalFare, _ticketID);

    }
    function payFare(uint flightNumber, address customerAccount) public payable  {
        require(_ticketStatus == TicketStatus.CREATED, "Error: Fare already paid or ticket is settled");
        //_totalFare = _calculateFare(); // calculate the fare & save it in the contract//TODO
        _totalFare = _baseFare; 
        require(msg.value == _totalFare, "Error: Invalid amount");

        _ticketDetails.seatNumber = _airline.completeReservation(flightNumber);
        
        _ticketStatus = TicketStatus.CONFIRMED;
        _isFarePaid = true;
        emit TicketConfirmed(_totalFare, _ticketID);
    }

    function cancelTicket() public payable onlyCustomer {
        require(_ticketStatus == TicketStatus.CONFIRMED, "Error: Ticket is already cancelled or settled");

        AirlineManagement.FlightStatus flightStatus = _airline.A_6_getFlightStatus(_ticketDetails.flightNumber);
        if(flightStatus == AirlineManagement.FlightStatus.ARRIVED || flightStatus == AirlineManagement.FlightStatus.DEPARTED) {
            revert("Error: Cannot cancel after departure or arrival");
        }

        uint schedDep = _ticketDetails.schedDep;
        
        if(schedDep - (2* 1 hours) < block.timestamp) {
            revert("Error: Cannot cancel within two hours of departure");
        }
        
        uint penalty = _calcCancelPenalty();
        _customerAccount.transfer(_totalFare - penalty);
        _airlineAccount.transfer(penalty);
        _ticketStatus = TicketStatus.CANCELLED;
        
        _airline.cancelReservation(_ticketDetails.flightNumber, _ticketDetails.seatNumber);
        emit TicketCancelled(_ticketID);
    }

    //Claim refund only before 24 hours past arrival
    function claimRefund() external payable onlyCustomer {
        require(_ticketStatus != TicketStatus.SETTLED && _ticketStatus != TicketStatus.CANCELLED,
        "Error: This ticket has already been settled");

        uint schedArr = _ticketDetails.schedArr;
        
        if(schedArr + (24 * 1 hours) > block.timestamp) {
            revert("Error: Cannot settle before 24 hours past scheduled arrival");
        }

        AirlineManagement.FlightStatus flightStatus = _airline.A_6_getFlightStatus(_ticketDetails.flightNumber);
        if(flightStatus != AirlineManagement.FlightStatus.ARRIVED) {
            _customerAccount.transfer(_totalFare);
            _ticketStatus = TicketStatus.SETTLED;
            emit TicketSettled(_ticketID);
        }

        uint penalty = _calcDelayPenalty();

        _customerAccount.transfer(_totalFare - penalty);
        _airlineAccount.transfer(penalty);
        _ticketStatus = TicketStatus.SETTLED;
        emit TicketSettled(_ticketID);
    }
   
   function settleTicket() external payable {
        require(msg.sender == _airlineContract, "Error: Only Airline can do this.");
        
        require(_ticketStatus != TicketStatus.SETTLED && _ticketStatus != TicketStatus.CANCELLED, 
        "Error: This ticket has already been settled");
        

        uint schedArr = _ticketDetails.schedArr;
        if(schedArr > block.timestamp) {
            revert("Error: Cannot settle before scheduled arrival");
        }

        AirlineManagement.FlightStatus flightStatus = _airline.A_6_getFlightStatus(_ticketDetails.flightNumber);
        if(flightStatus == AirlineManagement.FlightStatus.CANCELLED) {
            _customerAccount.transfer(_totalFare);
            _ticketStatus = TicketStatus.SETTLED;
            emit TicketSettled(_ticketID);
        }

        if(flightStatus != AirlineManagement.FlightStatus.ARRIVED) {
            revert("Error: Flight has not arrived yet");
        }

        uint delayPenalty = _calcDelayPenalty();
        if(delayPenalty == 0) {
            _airlineAccount.transfer(_totalFare);
        } else {
            _airlineAccount.transfer(_totalFare-delayPenalty);
            _customerAccount.transfer(delayPenalty);
        }

        _ticketStatus = TicketStatus.SETTLED;
        emit TicketSettled(_ticketID);
    }

        function _calcDelayPenalty() private view returns (uint) {
        uint8 penaltyPercent = _calcDelayPenaltyPercent();
        uint penaltyAmount = (_totalFare * penaltyPercent) / 100;

        return penaltyAmount;
    }

    function _calcDelayPenaltyPercent() private view returns (uint8) {
        uint actArr = _airline.getArrTime(_ticketDetails.flightNumber);
        uint schedArr = _ticketDetails.schedArr;
        
        uint8 penaltyPercent = 0;
        if(actArr-schedArr < 30*1 minutes) {
            penaltyPercent = 0;
        } else if(actArr-schedArr < 2*1 hours) {
            penaltyPercent = 10;
        } else {
            penaltyPercent = 30;
        }

        return penaltyPercent;
    }
    
    function _calcCancelPenalty() private view returns (uint) {
        uint8 penaltyPercent = _calcCancelPenaltyPercent();
        uint penaltyAmount = (_totalFare * penaltyPercent) / 100;

        return penaltyAmount;
    }

    function _calcCancelPenaltyPercent() private view returns (uint8) {
        uint currentTime = block.timestamp;
        uint timeLeft = _ticketDetails.schedDep - currentTime;
        uint8 penaltyPercent = 0;
        
        if(timeLeft <=  2 * 1 hours) {
            penaltyPercent = 100;
        } else if (timeLeft <= 3 * 1 days) {
            penaltyPercent = 50;
        } else {
            penaltyPercent = 10;
        }
        
        return penaltyPercent;
    }
}
