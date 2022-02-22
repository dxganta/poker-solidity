// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Ownable} from "../interfaces/Ownable.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {Evaluator7} from "./Evaluator7.sol";

contract Poker is Ownable {

    enum TableState {
        Active,
        Inactive,
        Showdown
    }  
    enum PlayerAction {
        Call,
        Raise,
        Check,
        Fold
    }

    event NewTableCreated(Table table);
    event NewBuyIn(uint tableId, address player, uint amount);
    event CardsDealt(PlayerCardHashes[] PlayerCardHashes, uint tableId);
    event RoundOver(uint tableId, uint round);
    event CommunityCardsDealt(uint tableId, uint roundId, uint8[] cards);

    struct Table {
        TableState state;
        uint totalHands; // total Hands till now
        uint currentRound; // index of the current round
        uint buyInAmount;
        uint maxPlayers;
        address[] players;
        uint pot;
        uint bigBlind;
        IERC20 token; // the token to be used to play in the table
    }
    struct Round {
        bool state; // state of the round, if this is active or not
        uint turn; // an index on the players array, the player who has the current turn
        address[] players; // players still playing in the round who have not folded
        uint highestChip; // the current highest chip to be called in the round. 
        uint[] chips; // the amount of chips each player has put in the round. This will be compared with the highestChip to check if the player has to call again or not.
    }
    struct PlayerCardHashes {
        bytes32 card1Hash;
        bytes32 card2Hash;
    }
    struct PlayerCards {
        uint8 card1;
        uint8 card2;
    }

    address public immutable EVALUATOR7;

    uint public totalTables;
    // id => Table
    mapping(uint => Table) public tables;
    // keeps track of the remaining chips of the player in a table
    // player => tableId => remainingChips
    mapping(address => mapping(uint => uint)) public chips;
    // player => tableId => handNum => PlayerCardHashes
    mapping(address => mapping(uint => mapping(uint => PlayerCardHashes))) public playerHashes;
    // tableId => roundNum => Round
    mapping(uint => mapping(uint => Round)) public rounds;
    // tableId => int8[] community cards
    mapping(uint => uint8[]) public communityCards;

    constructor(address _evaluator7) {
        EVALUATOR7 = _evaluator7;
    }

    function withdrawChips(uint _amount, uint _tableId) external {
        require(chips[msg.sender][_tableId] >= _amount, "Not enough balance");
        chips[msg.sender][_tableId] -= _amount;
        require(tables[_tableId].token.transfer(msg.sender, _amount));
    }

    function createTable(uint _buyInAmount, uint _maxPlayers, uint _bigBlind, address _token) external {
       
       address[] memory empty;
       
        tables[totalTables] =  Table({
            state: TableState.Inactive,
            totalHands: 0,
            currentRound: 0,
            buyInAmount: _buyInAmount,
            maxPlayers: _maxPlayers,
            players: empty,
            pot: 0,
            bigBlind: _bigBlind,
            token: IERC20(_token)
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
        require(table.token.transferFrom(msg.sender, address(this), _amount));
        chips[msg.sender][_tableId] += _amount;

        // add player to table
        table.players.push(msg.sender);

        emit NewBuyIn(_tableId, msg.sender, _amount);
    }

    /// @dev This method will be called by the owner to send the hash of the cards to all the players
    /// The key of the hash and the card itself will be sent privately by the owner to the player
    /// event is kept onchain so that other players can later verify that there was no cheating
    /// This will deal the cards to the players and start the round
    function dealCards(PlayerCardHashes[] memory _playerCards, uint _tableId) external onlyOwner {
        Table storage table = tables[_tableId];
        uint n = table.players.length;
        require(table.state == TableState.Inactive, "Game already going on");
        require(_playerCards.length == n, "ERROR: PlayerCardHashes Length");
        table.state = TableState.Active;

        // initiate the first round
        Round storage round = rounds[_tableId][0];

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

            // save the player hashes for later use in showdown()
            playerHashes[table.players[i]][_tableId][table.totalHands] = _playerCards[i];
        }

        table.pot += table.bigBlind + (table.bigBlind/2);

        emit CardsDealt(_playerCards, _tableId);
    }

    /// @param _raiseAmount only required in case of raise. Else put zero. This is the amount you are putting in addition to what you have already put in this round
    function playHand(uint _tableId, PlayerAction _action, uint _raiseAmount) external {
        Table storage table = tables[_tableId];
        require(table.state == TableState.Active, "No Active Round");
        
        Round storage round = rounds[_tableId][table.currentRound];
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

        _finishRound(_tableId, table);       
    }

    /// @dev this method will be called by the offchain node with the
    /// keys of each card hash & the card,  dealt in the dealCards function
    /// this method will then verify them with the hashes stored 
    /// evaluate the cards, and send the pot earnings to the winner
    /// @notice only send the keys & cards of the players who are still living
    function showdown(uint _tableId, uint[] memory _keys, PlayerCards[] memory _cards) external onlyOwner {
        Table storage table = tables[_tableId];
        Round memory round = rounds[_tableId][3];

        require(table.state == TableState.Showdown);

        uint n = round.players.length;
        require(_keys.length == n && _cards.length == n, "Incorrect arr length");

        // verify the player hashes
        for (uint i=0; i<n;i++) {
            bytes32 givenHash1 = keccak256(abi.encodePacked(_keys[i], _cards[i].card1));
            bytes32 givenHash2 = keccak256(abi.encodePacked(_keys[i], _cards[i].card2));

            PlayerCardHashes memory hashes = playerHashes[round.players[i]][_tableId][table.totalHands];

            require(hashes.card1Hash == givenHash1, "incorrect cards");
            require(hashes.card2Hash == givenHash2, "incorrect cards");
        }

        // now choose winner
        address winner;
        uint8 bestRank = 100;
        
        for (uint j=0; j < n;  j++) {
            address player = round.players[j];
            PlayerCards memory playerCards = _cards[j];

            uint8[] memory cCards = communityCards[_tableId];

            uint8 rank = Evaluator7(EVALUATOR7).handRank(
                cCards[0],
                cCards[1],
                cCards[2],
                cCards[3],
                cCards[4],
                playerCards.card1,
                playerCards.card2
            );

            if (rank < bestRank) {
                bestRank = rank;
                winner = player;
            }
        }

        // add to the winner's balance
        require(winner != address(0), "Winner is zero address");
        chips[winner][_tableId] += table.pot;
        _reInitiateTable(table, _tableId);
    }

    /// @dev method called by the offchain node to update the community cards for the next round
    /// @param _roundId The round for which the cards are being dealt (1=>Flop, 2=>Turn, 3=>River)
    /// @param _cards Code of each card(s), (as per the PokerHandUtils Library)
    function dealCommunityCards(uint _tableId, uint _roundId, uint8[] memory _cards) external onlyOwner {
        for (uint i=0; i<_cards.length; i++) {
            communityCards[_tableId].push(_cards[i]);
        }
        emit CommunityCardsDealt(_tableId, _roundId, _cards);
    }

    function _finishRound(uint _tableId, Table storage _table) internal {
        Round storage _round = rounds[_tableId][_table.currentRound];
        // if all of the other players have folded then the remaining player automatically wins
        uint n = _round.players.length;
        bool allChipsEqual = _allElementsEqual(_round.chips); // checks if anybody has raised or not
        if (n == 1) {
            // this is the last player left all others have folded
            // so this player is the winner
            // send the pot money to the user
            chips[_round.players[0]][_tableId] += _table.pot;

            // re initiate the table
            _reInitiateTable(_table, _tableId);
        } else if (allChipsEqual) {
            // all elements equal meaning nobody has raised
            if (_table.currentRound == 3) {
                // if nobody has raised and this is the final round then go to evaluation
                // todo: write evaluation logic here
                _table.state = TableState.Showdown;

                // then re-initiate the table
                // _reInitiateTable(_table);
            } else {
                // if nobody has raised and this is not the final round
                // and this is the last player
                // then just go the next round

                // check if this is the last player
                // if this is not the last player then it might just be check
                // so dont go to the next round
                if (_round.turn == n-1) {

                    // also emit an event if going to the next round which will tell the
                    // offchain node to send the next card (flop, turn or river)
                    emit RoundOver(_tableId, _table.currentRound);

                     _table.currentRound += 1;

                    uint[] memory _chips = new uint[](n);

                    // initiate the next round
                    rounds[_tableId][_table.currentRound] = Round({
                        state: true,
                        turn : 0,
                        players: _round.players, // all living players from the last round
                        highestChip: 0,
                        chips: _chips
                    });
                }
            }
            
        } else if (!allChipsEqual) {
                // or if somebody has raised 
                // ie. all values in the chips array are same then also stay in the same round

                // just update the turn
                _round.turn = _updateTurn(_round.turn, n);
        }
    }

      // updates the turn to the next player
    function _updateTurn(uint _currentTurn, uint _totalLength) internal pure returns (uint) {
        if (_currentTurn == _totalLength -1) {
            return 0;
        }
        return _currentTurn + 1;
    } 

    function _reInitiateTable(Table storage _table, uint _tableId) internal {

        _table.state = TableState.Inactive;
        _table.totalHands += 1;
        _table.currentRound = 0;
        _table.pot = 0;
        delete communityCards[_tableId]; // delete the community cards of the previous round

        // initiate the first round
        Round storage round = rounds[_tableId][0];
        round.state = true;
        round.players = _table.players;
        round.highestChip = _table.bigBlind;
    } 

    function _allElementsEqual(uint[] memory arr) internal pure returns (bool val) {
        uint x = arr[0];
        val = true;
        for (uint i=0; i < arr.length; i++) {
            if (arr[i] != x) {
                val = false;
            }
        }
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