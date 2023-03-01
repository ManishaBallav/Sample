// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./Ticket.sol";




contract AirlineManagement {

    event AirlineCreated(string _airlineName);
    event FlightAdded(uint _flightNumber, address _address);
    event FlightModified(uint _flightNumber, address _address);
    event StatusUpdated(uint _flightNumber, FlightStatus _flightStatus, address _address);
    event FlightBalance(uint _airlineBalance);
    event PenaltyPaid(uint _totalPenaltyAmount);
    event TicketBooked(address _ticketContract);

    enum FlightStatus {SCHEDULED, ONTIME, DELAYED, CANCELLED, DEPARTED, ARRIVED}

//Customer
    address[] private customers;
    //AirlineManagement airline;
    TicketMgt ticket_inst;
    //cutomer => ticket
    mapping(address => address[]) bookingHistory;

//

    struct Flight {
        uint flightNumber;
        string source;
        string destination;
        uint fixedBasePrice;
        uint totalSeats;
        uint totalPassengers;
        uint departureTime;
        uint256 arrivalTime;
        uint256 duration;
        address[] allTicketsInTheFlight; //lists of ticket contracts in a flight
        mapping(address => bool) ticketExists;
        FlightStatus flightStatus;
        mapping(uint8 => address) reservedSeats;
    }    
    address payable airlineAdmin = payable(0);
    address airlineAccount = address(0);

    // flight -> isFlightActive
    mapping (uint => bool) private isFlightActive;
    string public airlineName;
    string public airlineSymbol;

    // Total amount received for all flights
    uint private airlineBalance;

    // Total panelty paid for all flights
    uint private totalPenaltyAmount;

    mapping (uint => Flight) private allFlightDetailsMap;
    uint[] private allFlights;

        // Modifiers - START
    modifier onlyAirline() {
        require((airlineAccount != address(0)), "Only the Airline can do this & Airline Accounts are not setup yet.");
        require((msg.sender == airlineAccount) || (msg.sender == airlineAdmin), "Only the Airline can do this.");
        _;
    }

    modifier validateFlightStatus(uint _flightNumber,  FlightStatus status){
        require (allFlightDetailsMap[_flightNumber].flightStatus != status, "Flight Status is already updated.");
        require (allFlightDetailsMap[_flightNumber].flightStatus < status, "Flight Status is not modifiable to previous state.");
        _;
    }

    modifier flightNotCancelled(uint _flightNumber){
        require (allFlightDetailsMap[_flightNumber].flightStatus != FlightStatus.CANCELLED, "Can't change status, as current status is cancelled.");
        _;
    }
    
    modifier flightNotArrived(uint _flightNumber){
        require (allFlightDetailsMap[_flightNumber].flightStatus != FlightStatus.ARRIVED, "Can't change status, as current status is arrived.");
        _;
    }
        modifier flightNotDeparted(uint _flightNumber){
        require (allFlightDetailsMap[_flightNumber].flightStatus != FlightStatus.DEPARTED, "Can't change status, as current status is departed.");
        _;
    }
    //Draft version : _arilineAccount will be same where airline contract deployed , will enhance later 
    constructor (string memory _airlineName, address _airlineAccount) {
        airlineName = _airlineName;
        airlineBalance = 0;
        totalPenaltyAmount = 0;
        airlineAdmin = payable(msg.sender);
        airlineAccount = _airlineAccount;
        emit AirlineCreated(_airlineName);
    }


    function bookTicket(uint flightNo) public payable returns (address ticketAddr) {
        customers.push(msg.sender);
        address ticket = createTicket(flightNo, msg.sender);
        ticket_inst  = TicketMgt(ticket);
        bookingHistory[msg.sender].push(ticket);
        return ticket;
    }

    // Adding value to the map
    //TODO : fixedBasePrice variable, 
    function _A_1_addFlight(uint _flightNumber, string memory _source, string memory _destination,
     uint256 _departureTime, uint256 _arrivalTime) public onlyAirline { //uint _fixedBasePrice,bool _activeStatus

        //departureTIme = block.timestamp + inputParameter * Hours

        Flight storage flight = allFlightDetailsMap[_flightNumber];
        flight.flightNumber = _flightNumber;
        flight.source = _source;
        flight.destination = _destination;
        flight.fixedBasePrice = 1000000000000000000;//_fixedBasePrice;
        flight.departureTime = block.timestamp + (_departureTime * 1 hours);
        flight.arrivalTime = block.timestamp + (_arrivalTime * 1 hours); 
    
        flight.duration = _arrivalTime - _departureTime;
        
        flight.totalSeats = 240;
            
        flight.totalPassengers = 0;
        allFlights.push(_flightNumber);
       // isFlightActive[_flightNumber] = _activeStatus;
       isFlightActive[_flightNumber] = true;
        emit FlightAdded(_flightNumber, msg.sender);
    }
    // Flight Status Operations - START

    function __settleAllTicket(uint _flightNumber) private onlyAirline {
        address[] memory ticketsToBeSetteled = allFlightDetailsMap[_flightNumber].allTicketsInTheFlight;
        for (uint i=0; i<ticketsToBeSetteled.length; i++){
            TicketMgt(ticketsToBeSetteled[i]).settleTicket();
        }
    }
    
    function updateStatus(uint _flightNumber, FlightStatus _flightStatus) public onlyAirline {
        allFlightDetailsMap[_flightNumber].flightStatus = _flightStatus;
        emit StatusUpdated(_flightNumber, _flightStatus, msg.sender);
    }

    function A_1_flightOnTime(uint _flightNumber) public
    validateFlightStatus(_flightNumber, FlightStatus.ONTIME){
        updateStatus(_flightNumber, FlightStatus.ONTIME);
    }

    function A_2_flightDelayed(uint _flightNumber) public 
    flightNotCancelled(_flightNumber) flightNotArrived(_flightNumber) 
    flightNotDeparted(_flightNumber) validateFlightStatus(_flightNumber, FlightStatus.DELAYED){
        updateStatus(_flightNumber, FlightStatus.DELAYED);
    }
    
    function A_3_flightCancelled(uint _flightNumber) public 
    flightNotArrived(_flightNumber) flightNotDeparted(_flightNumber) 
    validateFlightStatus(_flightNumber, FlightStatus.CANCELLED){
        updateStatus(_flightNumber, FlightStatus.CANCELLED);
        __settleAllTicket(_flightNumber);
    }

    function A_4_flightDeparted(uint _flightNumber) public 
    flightNotArrived(_flightNumber)
    validateFlightStatus(_flightNumber, FlightStatus.DEPARTED){
        updateStatus(_flightNumber, FlightStatus.DEPARTED);
    }

    function A_5_flightArrived(uint _flightNumber) public
    validateFlightStatus(_flightNumber, FlightStatus.ARRIVED){
        updateStatus(_flightNumber, FlightStatus.ARRIVED);
        __settleAllTicket(_flightNumber);
    }
    // Flight Status Operations - END


    // Getter for Flight Status - START
    function A_6_getFlightStatus(uint _flightNumber) public view returns (FlightStatus){
        return allFlightDetailsMap[_flightNumber].flightStatus;
    }
    // Getter for Flight Status - END


     function getArrTime(uint _flightNumber) public view returns (uint) {
        return allFlightDetailsMap[_flightNumber].arrivalTime;
    }

    function viewContractsList(uint _flightNumber) public view onlyAirline returns (address[] memory){
        return allFlightDetailsMap[_flightNumber].allTicketsInTheFlight;
    }

    function viewAirlineBalance() public onlyAirline {
        emit FlightBalance(airlineBalance);
    }

    function viewPenaltyPaid() public onlyAirline {
        emit PenaltyPaid(totalPenaltyAmount);
    }

    function getSeatLeft(uint _flightNumber) public view  returns (uint) {
        return allFlightDetailsMap[_flightNumber].totalSeats - allFlightDetailsMap[_flightNumber].totalPassengers;
    }

    function getTotalSeats(uint _flightNumber) public view  returns (uint) {
        return allFlightDetailsMap[_flightNumber].totalSeats;
    }

    function getFixedBasePrice(uint _flightNumber) public view returns (uint) {
        return allFlightDetailsMap[_flightNumber].fixedBasePrice;
    }

    // Book Ticket: Function for reserving the seat in a flight.
    function completeReservation(uint _flightNumber) external  returns (uint8 seatNo) {
        Flight storage flight = allFlightDetailsMap[_flightNumber];
        require(flight.ticketExists[msg.sender] == true, "Error: Ticket not associated with this flight");
        require(flight.totalPassengers < flight.totalSeats, "Error: No seats left!!");
        
        uint8 _seatNumber = 1;
        for(uint8 i = 1; i <= flight.totalSeats; i++) {
            if(flight.reservedSeats[i] == address(0)) {
                _seatNumber = i;
                break;
            }
        }
        
        flight.reservedSeats[_seatNumber] = msg.sender;
        flight.totalPassengers += 1;
        return _seatNumber;
    }

    function createTicket(uint _flightNumber, address _customerAddr) private returns (address) {
        Flight storage flight = allFlightDetailsMap[_flightNumber];
        require(flight.totalPassengers < flight.totalSeats, "Error: No seats available");
        //TODO
        //console.log(msg.sender + ":-" + _flightNumber );
        TicketMgt ticket = new TicketMgt(airlineAccount, _customerAddr, _flightNumber, 0,
        flight.source, flight.destination, flight.departureTime, flight.arrivalTime);//, flight.fixedBasePrice);

        address ticketAddr = address(ticket);

        flight.allTicketsInTheFlight.push(ticketAddr);
        flight.ticketExists[ticketAddr] = true;
        
        emit TicketBooked(ticketAddr);
        return ticketAddr;
    }

    function cancelReservation(uint _flightNumber, uint8 _seatNo) external payable {
        Flight storage flight = allFlightDetailsMap[_flightNumber];
        require(flight.ticketExists[msg.sender] == true, "Error: Ticket not associated with this flight");
        
        flight.reservedSeats[_seatNo] = address(0);
        
        flight.totalPassengers -= 1;
    }
    
    // Method for searching a flight between two destinations.
    function searchFlight(string calldata origin, string calldata dest) public view returns (uint flightFound){
        
    }
}
