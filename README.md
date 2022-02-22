# Solidity Poker

## Introduction

Creating fully decentralized Card Games has always been a difficult task due to the open nature of blockchains. Card games require a certain level of privacy, i.e the cards of a certain player must be private untill the game is over.
If we think of a very general solution where the smart contract randomly chooses a card from the deck and returns it to the user, this will cause the problem that any other malicious actor will also be able to view that card since no data on the blockchain is really private.

Yet efforts have been made to create a fully decentralized card game using a commutative hash function. You can read about it in this [stackoverflow post](https://ethereum.stackexchange.com/questions/376/what-are-effective-and-secure-ways-of-shuffling-a-deck-of-cards-in-a-contract/758).
But this solution has a very fatal assumption of using a theoretical <strong>Commutative</strong> Hash Function. Since the most popular SHA256 hash function is not commutative & I failed to find any real commutative hash functions, and also considering the fact that this solution would create a very difficult UX for the game, I had to come to conclusion this is not a practical solution.

I believe Web3 solutions must not only be equal but better than Web2 solutions.

So I wondered what are the primary Pros & Cons of a web3 onchain poker game compared to the other web2 poker games:

#### Pros

1. <strong>Dont Trust, Verify</strong>: The players must be able to verify at the end of the game that the cards provided to the player are the real cards that had been provided to him/her at the start and not some fabricated cards that the system provided them malicioulsy at the end after all the community cards were dealt. Yet at the same time, this verification must only be possible after the end of a game. The cards of any player must stay private from the other players during the duration of the game.

2. <strong>Freedom of Money</strong>: The players must be able to bet with any token and deposit & withdrawals must be smooth & fast. This gives a huge advantage over web2 poker where you can only bet with INR(in India). Not to mention the fact that online poker is illegal in many states and so is withdrawal of your hard won money.

#### Cons

1. <strong>Inefficient</strong>: Web2 Poker webapps will agree that the most difficult part of writting a poker application is the <strong>"Hand Evaluation Code"</strong>. This problem only grows bigger in solidity with this limited contract size, limited memory, limited EVM stack size, worry about gas costs, etc. etc.

2. <strong>Get Rekt?</strong>: Ahh the ever remaining threat of hackers. The most you can do with a web2 poker game hack is manipulate the hands maybe. But in web3 one critical hack of a smart contract which contains the funds of all the users means losing all your money in the blink of an eye. The openness of our smart contracts & their code is both a blessing & a curse.

## My Solution

So I have tried to come up with a Semi-Decentralized Solidity Poker Game, which maintains the benefits of an ideal blockchain poker game yet solves (or atleast tries to) the disadvantages.

The code is for <strong>Texas Hold'em Poker</strong>.

The primary contract is the (Poker.sol)[https://github.com/realdiganta/poker-solidity/blob/main/contracts/Poker.sol] contract with which the players will interact and the player funds will be stored.

### createTable(uint buyInAmount, uint maxPlayers, uint bigBlind, address token)

This method must first be called by a player to create a table.
This will create a <strong>Table</strong> struct with the

```
buyInAmount: The minimum amount of tokens required to enter the table
maxPlayers: The maximum number of players allowed in this table
bigBlind: The big blinds for the table (Small Blind will be half of bigBlind)
token: The address of the token that will be used to bet in this table
```

parameters and provide a unique id to this table and save it in storage.
Tables once created cannot be modified. Anyone can create a table and anyone can enter a table as long as they supply required buyInAmount and the maxPlayers has not been reached for that table.

The betting token instead of being kept constant to the contract has been kept unique to each table. So the table creator can specify the address of the token to be used for betting and only that token will be used for betting in that particular table.

### buyIn(uint tableId, uint amount)

Once a table is created, this method must be called by a player (with the table id where he wants to enter) to enter the table and start playing games on that table.

This method will transfer <strong>"amount"</strong> number of tokens from the player to the contract. (The user must have already approved the contract for those tokens). <strong>"amount"</strong> must be greater than or equal to the table buyInAmount.

This method will fail if the maximum number of players for this table has been reached.

### dealCards(PlayerCardHashes[] playerCards, uint tableId)

Now the next and most important step is dealing the cards to the players.

This method can only be and needs to be called by the contract owner.

Each player will get a pair of cards. Now we cannot directly give the cards through this method because then the cards will become public and anyone will be able to view the cards of the other player. It wont be much of a game if you already know what card the other player has right.

The contract owner will hash each card pair for each player with a unique secret key and then publish these keys to the network by calling the <strong>dealCards</strong> method.
Then the owner will send the unique key & the card pair to each player privately.
The player can verify through the hash that the card sent to them is correct.

This serves two purposes, firstly only each player will know about his/her card pair because only he/she will get the unique private key. Secondly, since the card pair hashes has been published to the network through the dealCards method, once the game is over, the owner will publish all the secret keys to the network and then other players can verify the cards of other players.

The only centralization here is that the players have to trust that the contract owner will randomize the cards correctly offchain.

The <strong>dealCard</strong> method also activates the table and initiates the first round, by automatically betting the small blind & the big blind from the last 2 players on the board.

### playHand(uint tableId, PlayerAction action, uint raiseAmount)

Once the cards have been dealt to the owner, its time for betting.

This method will be called by the player (who has the current turn) with an action -> Check, Call, Fold, Raise.

After he's done, the turn will automatically go to the next player and then she has to call this method with her respective action.

Once everyone is done, and the round is over, a RoundOver event will be emitted. On receive of this event, the contract owner has to call the <strong>dealCommunityCards()</strong> method to deal the community cards for the next round (3 cards for Flop, 1 card for Turn & River).

Once done, the players will be able to view the community cards, and then start calling the playHand() method again based on whose turn it is to start betting for the next round. This will go on untill either all the players have folded except one (the winner) or all the rounds are over.

#### Scenario 1 : All Players except one has folded

If before the end of the final round, all players have folded, then whoever is left will be sent the money in the pot, and the table will be inactivated. Betting for the next game will start again with the contract owner calling the <strong>dealCards</strong> and dealing a new set of cards.

#### Scenario 2: All rounds are over

Suppose the players keep on betting and the game goes to showdown. In this scenario a <strong>TableShowdown</strong> event will be emitted.

On receiving of this event the contract owner will call the <strong>showdown()</strong> method with the player cards & the private keys as parameters.

The method will first verify with the hashes already provided in the <strong>dealCards()</strong> method that the cards & keys provided are correct.

If verified the method will evaluate each 7 cards hand of each player to find the best hand and reward the pot to the winner.

## Evaluation Logic : How does the contract evaluate the 7 cards hand?

Evaluating a 7card hand in solidity is very expensive compuatationally.
So instead of re-inventing the wheel and writting a naive evaluation algorithm from scratch I started looking for the best evaluation algorithms used in web2 poker apps hoping I could somehow port it to solidity.

But most of the top evaluation stores pre-computed hash tables which go up to 100+ MB in size, for example the [TwoPlusTwo Hand Evaluator](https://github.com/tangentforks/TwoPlusTwoHandEvaluator).

After some more searching I stumbled upon [this very beautiful javascript implementation](https://github.com/thlorenz/phe) which uses very small hash tables for 7-hand evaluation.

Yet porting it to solidity was not an easy task due to the very small size limit of smart contracts.

So I mostly separated the tables into multiple contracts which you can find in the [flush](https://github.com/realdiganta/poker-solidity/tree/main/contracts/flush) & [noFlush](https://github.com/realdiganta/poker-solidity/tree/main/contracts/noFlush) folders.

As a result the main evaluation logic in the [Evaluator7.sol](https://github.com/realdiganta/poker-solidity/blob/main/contracts/Evaluator7.sol) contract is pretty small & efficient.

### withdrawChips(uint amount, uint tableId)

This method can be called by the players to the withdraw the chips they have deposited into a table.

## Installation & Setup

1. Install [Brownie](https://eth-brownie.readthedocs.io/en/stable/install.html) & [Ganache-CLI](https://www.npmjs.com/package/ganache-cli), if you haven't already.

2. Copy the .env.example file, and rename it to .env

3. Sign up for Infura and generate an API key. Store it in the WEB3_INFURA_PROJECT_ID environment variable.

4. Sign up for Etherscan and generate an API key. This is required for fetching source codes of the ethereum mainnet contracts we will be interacting with. Store the API key in the ETHERSCAN_TOKEN environment variable.

Install the dependencies in the package

```
## Python Dependencies
pip install -r requirements.txt
```
