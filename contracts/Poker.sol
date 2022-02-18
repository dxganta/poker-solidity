// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Ownable} from "../interfaces/openzeppelin/access/Ownable.sol";
import {IERC20} from "../interfaces/openzeppelin/token/ERC20/IERC20.sol";
import {PokerHandUtils} from "./libraries/PokerHandUtils.sol";

contract Poker is Ownable {

    event NewTableCreated(Table table);
    event NewBuyIn(uint tableId, address player, uint amount);

    struct Table {
        uint buyInAmount;
        uint maxPlayers;
        address[] players;
        uint dealer; // an index on the players array, the current dealer from the group of players
        address[] livingPlayers; // players who are still playing and have not folded
        uint pot;
    }

    IERC20 public immutable token;
    uint public totalTables;
    // id => Table
    mapping(uint => Table) tables;
    // keeps track of the remaining chips of the player in a table
    // address => tableId => remainingChips
    mapping(address => mapping(uint => uint)) chips;
    
    constructor(address _token) {
        token = IERC20(_token);
    }

    function createTable(uint _buyInAmount, uint _maxPlayers) external {
       
       address[] memory empty;
       
        tables[totalTables] =  Table({
            buyInAmount: _buyInAmount,
            maxPlayers: _maxPlayers,
            players: empty,
            dealer: 0,
            livingPlayers: empty,
            pot: 0
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

    /// @dev This method will be called by the owner to send the hash of the cards to the player
    /// The key of the hash and the card itself will be sent privately by the owner to the player
    function dealCards(bytes32 _card1Hash, bytes32 _card2Hash) external onlyOwner {

    }
}