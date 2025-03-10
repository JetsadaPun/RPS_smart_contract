// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./TimeUnit.sol";
import "./CommitReveal.sol";

contract RPS {
    CommitReveal private commitReveal;
    TimeUnit private timeUnit;

    uint public numPlayer = 0;
    uint public reward = 0;
    mapping(address => bytes32) public commits;
    mapping(address => uint) public revealedChoice;
    address[] public players;

    address constant player1 = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    address constant player2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    address constant player3 = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
    address constant player4 = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;

    constructor() {
        timeUnit = new TimeUnit(); 
        commitReveal = new CommitReveal();
    }
    event PlayerJoined(address indexed player);
    event ChoiceCommitted(address indexed player);
    event ChoiceRevealed(address indexed player, uint choice);
    event GameEnded(address winner, uint reward);
    function addPlayer() public payable {
        require(numPlayer < 2, "Game full");
        require(
            msg.sender == player1 || msg.sender == player2 || msg.sender == player3 || msg.sender == player4,
            "Not allowed"
        );
        if (numPlayer > 0) {
            require(msg.sender != players[0], "Same player");
        }
        require(msg.value == 1 ether, "Must send 1 ETH");
        reward += msg.value;
        players.push(msg.sender);
        numPlayer++;
        if (numPlayer == 1) {
            timeUnit.setStartTime();
        }
        if (numPlayer == 2) {
            timeUnit.resetTime();
            timeUnit.setStartTime();
        }
    }

    function _checkWinnerAndPay() private {
        require(revealedChoice[players[0]] != 0, "Player 1 has not revealed");
        require(revealedChoice[players[1]] != 0, "Player 2 has not revealed");
        uint p0Choice = revealedChoice[players[0]];
        uint p1Choice = revealedChoice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        if ((p0Choice == 0 && (p1Choice == 2 || p1Choice == 3)) || 
            (p0Choice == 1 && (p1Choice == 0 || p1Choice == 4)) || 
            (p0Choice == 2 && (p1Choice == 1 || p1Choice == 3)) || 
            (p0Choice == 3 && (p1Choice == 1 || p1Choice == 4)) || 
            (p0Choice == 4 && (p1Choice == 0 || p1Choice == 2))) {
            account0.transfer(reward);
        }
        else if ((p1Choice == 0 && (p0Choice == 2 || p0Choice == 3)) || 
                (p1Choice == 1 && (p0Choice == 0 || p0Choice == 4)) || 
                (p1Choice == 2 && (p0Choice == 1 || p0Choice == 3)) || 
                (p1Choice == 3 && (p0Choice == 1 || p0Choice == 4)) || 
                (p1Choice == 4 && (p0Choice == 0 || p0Choice == 2))) {
            account1.transfer(reward);
        }
        else {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
        _resetGame();
    }

    function checkTimeout() public payable {
        require(numPlayer == 1, "Game not started");
        if (numPlayer == 1 && timeUnit.elapsedSeconds() >= 120) {
            payable(players[0]).transfer(1 ether);
            _resetGame();
        } 
    }


    function checkTimeoutTwoPlayers(address inputSender) public {
        require(numPlayer == 2, "Game not started");
        require(players[0] == inputSender || players[1] == inputSender, "Invalid player");
        
        if (timeUnit.elapsedSeconds() >= 120) {
            address payable sender = payable(inputSender);
            address payable other = (players[0] == inputSender) ? payable(players[1]) : payable(players[0]);
            
            sender.transfer(1 ether);
            other.transfer(1 ether);
            _resetGame();
        }
    }

    function getElapsedTime() public view returns (uint256) {
        return timeUnit.elapsedSeconds();
    }

    function _makeCommit(bytes32 commitHash) public {
        require(numPlayer == 2, "Game not started");
        require(commits[msg.sender] == 0, "Already committed");
        commitReveal.commit(commitHash);
        commits[msg.sender] = commitHash;
    }

    function _revealChoice(uint choice, bytes32 nonce) public {
        require(commits[msg.sender] != 0, "No commit found");
        require(revealedChoice[msg.sender] == 0, "Already revealed");
        bytes32 revealHash = keccak256(abi.encodePacked(choice, nonce));
        commitReveal.reveal(revealHash);
        revealedChoice[msg.sender] = choice;
        if (revealedChoice[players[0]] != 0 && revealedChoice[players[1]] != 0) {
            _checkWinnerAndPay();
        }
    }

    
    function _resetGame() private {
        delete players;
        numPlayer = 0;
        reward = 0;
    }
}