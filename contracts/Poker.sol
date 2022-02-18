// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Ownable} from "../interfaces/openzeppelin/access/Ownable.sol";
import {IERC20} from "../interfaces/openzeppelin/token/ERC20/IERC20.sol";
import {PokerHandUtils} from "./libraries/PokerHandUtils.sol";

contract Poker is Ownable {

    enum TableState {
        Active,
        Inactive
    }
    enum RoundState {
        PreFlop,
        Flop,
        River,
        Turn
    }
    enum PlayerAction {
        Call,
        Raise,
        Check,
        Fold
    }

    event NewTableCreated(Table table);
    event NewBuyIn(uint tableId, address player, uint amount);
    event CardsDealt(PlayerCards[] playerCards, uint tableId);

    struct Table {
        TableState state;
        uint currentRound; // index of the current round
        Round[4] rounds; // an array containing the 4 rounds
        uint buyInAmount;
        uint maxPlayers;
        address[] players;
        uint pot;
        uint bigBlind;
    }
    struct Round {
        bool state; // state of the round, if this is active or not
        uint turn; // an index on the players array, the player who has the current turn
        address[] players; // players still playing in the round who have not folded
        uint highestChip; // the current highest chip to be called in the round. 
        uint[] chips; // the amount of chips each player has put in the round. This will be compared with the highestChip to check if the player has to call again or not.
    }
    struct PlayerCards {
        bytes32 card1Hash;
        bytes32 card2Hash;
    }

    IERC20 public immutable token;
    uint public totalTables;
    // id => Table
    mapping(uint => Table) tables;
    // keeps track of the remaining chips of the player in a table
    // player => tableId => remainingChips
    mapping(address => mapping(uint => uint)) chips;
    
    constructor(address _token) {
        token = IERC20(_token);
    }

    function createTable(uint _buyInAmount, uint _maxPlayers, uint _bigBlind) external {
       
       address[] memory empty;
       Round[4] memory rounds;
       
        tables[totalTables] =  Table({
            state: TableState.Inactive,
            currentRound: 0,
            buyInAmount: _buyInAmount,
            maxPlayers: _maxPlayers,
            players: empty,
            rounds: rounds,
            pot: 0,
            bigBlind: _bigBlind
        });

        emit NewTableCreated(tables[totalTables]);

        totalTables += 1;
    }

    /// @dev first the players have to call this method to buy in and enter a table
    function buyIn(uint _tableId, uint _amount) public {
        Table storage table = tables[_tableId];

        require(_amount >= table.buyInAmount, "Not enough buyInAmount");
        require(table.players.length < table.maxPlayers, "Table full");

        // transfer buyIn Amount from player to contract
        require(token.transferFrom(msg.sender, address(this), _amount));
        chips[msg.sender][_tableId] += _amount;

        // add player to table
        table.players.push(msg.sender);

        emit NewBuyIn(_tableId, msg.sender, _amount);
    }

    /// @dev This method will be called by the owner to send the hash of the cards to all the players
    /// The key of the hash and the card itself will be sent privately by the owner to the player
    /// event is kept onchain so that other players can later verify that there was no cheating
    /// This will deal the cards to the players and start the round
    function dealCards(PlayerCards[] memory _playerCards, uint _tableId) external onlyOwner {
        Table storage table = tables[_tableId];
        uint n = table.players.length;
        require(table.state == TableState.Inactive, "Game already going on");
        require(_playerCards.length == n, "ERROR: PlayerCards Length");
        table.state = TableState.Active;

        // initiate the first round
        Round storage round = table.rounds[0];

        round.state = true;
        round.players = table.players;
        round.highestChip = table.bigBlind;
    
        // initiate the small blind and the big blind
        for (uint i=0; i < n; i++) {
            if (i == (n-1)) { // the last player
                // small blinds
                round.chips[i] = table.bigBlind / 2;
                chips[round.players[i]][_tableId] -= table.bigBlind / 2;
            } else if (i == (n-2)) { // the last second player
                // big blinds
                round.chips[i] = table.bigBlind; // update the round array
                chips[round.players[i]][_tableId] -= table.bigBlind; // reduce the players chips
            }
        }

        table.pot += table.bigBlind + (table.bigBlind/2);

        emit CardsDealt(_playerCards, _tableId);
    }

    /// @param _raiseAmount only required in case of raise. Else put zero. This is the amount you are putting in addition to what you have already put in this round
    function playHand(uint _tableId, PlayerAction _action, uint _raiseAmount) external {
        Table storage table = tables[_tableId];
        require(table.state == TableState.Active, "No Active Round");
        
        Round storage round = table.rounds[table.currentRound];
        require(round.players[round.turn] == msg.sender, "Not your turn");

        if (_action == PlayerAction.Call) {
            // in case of calling
            // deduct chips from the users account
            // add those chips to the pot
            // keep the player in the round

            uint callAmount = round.highestChip - round.chips[round.turn];

            chips[msg.sender][_tableId] -= callAmount;

            table.pot += callAmount;
            
        } else if (_action == PlayerAction.Check) {
            // you can only check if all the other values in the round.chips array is zero
            // i.e nobody has put any money till now
            for (uint i =0; i < round.players.length; i++) {
                if (round.chips[i] > 0) {
                    require(false, "Check not possible");
                }
            }
        } else if (_action == PlayerAction.Raise) {
            // in case of raising
            // deduct chips from the player's account
            // add those chips to the pot
            // update the highestChip for the round
            uint totalAmount = _raiseAmount + round.chips[round.turn];
            require(totalAmount > round.highestChip, "Raise amount not enough");
            chips[msg.sender][_tableId] -= _raiseAmount;
            table.pot += _raiseAmount;
            round.highestChip = totalAmount;

        } else if (_action == PlayerAction.Fold) {
            // in case of folding
            /// remove the player from the players & chips array for this round
            _remove(round.turn, round.players);
            _remove(round.turn, round.chips);
        }

        round.turn = _updateTurn(round.turn, round.players.length);

        _finishRound();
       
    }

    // updates the turn to the next player
    function _updateTurn(uint _currentTurn, uint _totalLength) internal pure returns (uint) {
        if (_currentTurn == _totalLength -1) {
            return 0;
        }
        return _currentTurn + 1;
    }  

    function _finishRound() internal {
        // note: if all of the other players have folded then the remaining player automatically wins
        // else it goes to the evaluation of their cards
        
        // check if all the other players has folded



        // if this was the last round then automatically go to evaluation

        // else change the current round to the next round
        // only if
        // nobody has raised, i.e all the values in the coins array are equal

    }

    function _remove(uint index, address[] storage arr) internal {
        arr[index] = arr[arr.length - 1];
        arr.pop();
    }

    function _remove(uint index, uint[] storage arr) internal {
        arr[index] = arr[arr.length - 1];
        arr.pop();
    }

}