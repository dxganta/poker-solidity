// // Code take and modified from
// // https://github.com/beachgrub/PokerHandSolidity/blob/master/contracts/PokerHandUtils.sol


// // PokerHandUtils 
// // 
// // Library for handling of poker hands consisting of cards numbered 0-51
// // Ace = 0, King = 12 in the suits Clubs, Diamonds, Hearts, Spades
// //
// // Function: 	evaluateHand takes a list of 5 cards (0-51)
// // Returns:  	enum of Hand type and up to 5 values of the cards sorted to break ties
// //
// // Notes: 		State of the art poker hand evals use data tables and hash to run fast.
// //				For in contract, wanted an old school analytic approach with low memory
// //
// // Next Steps: 	Test and Optimize.  Potentially change tiebreaker list to a hash number to compare.
// //
// // Usage: 
// //
// // int8[5] memory hand = [ int8(PokerHandUtils.CardId.Six_Clubs), int8(PokerHandUtils.CardId.Three_Clubs), int8(PokerHandUtils.CardId.Jack_Diamonds), int8(PokerHandUtils.CardId.Two_Clubs), int8(PokerHandUtils.CardId.Seven_Clubs)];
// // PokerHandUtils.HandEnum handVal;
// // int8[5] memory result;
// // (handVal, result) = poker.evaluateHand(hand);
// // Example returns (HandEnum.HighCard, [Jack, Eight, Six, Three, Two])
// //

// pragma solidity ^0.8.9;

// // Should be library but contract so I can run truffle tests
// // library PokerHandUtils {
// library PokerHandUtils {
// 	// Enum for all Cards, 0-51
// 	enum CardId { 
// 		Ace_Clubs, Two_Clubs, Three_Clubs, Four_Clubs, Five_Clubs, Six_Clubs, Seven_Clubs, Eight_Clubs, Nine_Clubs, Ten_Clubs, Jack_Clubs, Queen_Clubs, King_Clubs,
// 		Ace_Diamonds, Two_Diamonds, Three_Diamonds, Four_Diamonds, Five_Diamonds, Six_Diamonds, Seven_Diamonds, Eight_Diamonds, Nine_Diamonds, Ten_Diamonds, Jack_Diamonds, Queen_Diamonds, King_Diamonds,
// 		Ace_Hearts, Two_Hearts, Three_Hearts, Four_Hearts, Five_Hearts, Six_Hearts, Seven_Hearts, Eight_Hearts, Nine_Hearts, Ten_Hearts, Jack_Hearts, Queen_Hearts, King_Hearts,
// 		Ace_Spades, Two_Spades, Three_Spades, Four_Spades, Five_Spades, Six_Spades, Seven_Spades, Eight_Spades, Nine_Spades, Ten_Spades, Jack_Spades, Queen_Spades, King_Spades
// 	}
// 	// Values of Cards
// 	enum CardValue { Ace, Two, Three, Four, Five, Six, Seven, Eight, Nine, Ten, Jack, Queen, King, Ace_High }
// 	// Suits of Cards
// 	enum CardSuit { Clubs, Diamonds, Hearts, Spades }
// 	// Type of hand from High card to Royal flush
// 	enum HandEnum { RoyalFlush, StraightFlush, FourOfAKind, FullHouse, Flush, Straight, ThreeOfAKind, TwoPair, Pair, HighCard }
	
// 	// Convert a card to standard card name pair
// 	function getCardName(int8 code) public pure returns (CardValue, CardSuit) {
// 		require(code >= 0 && code <52);
// 		return (CardValue(code % 13), CardSuit(code / 13));
// 	}

// 	// Convert a card name to card code
// 	function getCardCode(CardValue value, CardSuit suit) public pure returns (int8) {
// 		return int8(uint8(suit)*13 + uint8(value));
// 	}
	
// 	// Helper to get the value for a card 1,12 plus Ace high can be 13.
// 	// Used for judging relative strength
// 	function getCardOrderValue(CardValue cardVal) pure public returns (int8)
// 	{
// 		// Ace values as High Ace in ranking
// 		if (uint8(cardVal) == 0) {
// 			return int8(uint8(CardValue.Ace_High));
// 		}
// 		return int8(uint8(cardVal));
// 	}

// 	// Helper Sort function
// 	// Modified from
// 	// https://github.com/alice-si/array-booster
// 	function sortHand(int8[5] memory data) pure public returns (int8[5] memory arr) {
// 		uint n = data.length;
// 		uint i;

// 		for(i=0; i<n; i++) {
// 			arr[i] = data[i];
// 		}

// 		int8 key;
// 		uint j;

// 		for(i = 1; i < arr.length; i++ ) {
// 			key = arr[i];

// 			for(j = i; j > 0 && arr[j-1] < key; j-- ) {
// 			arr[j] = arr[j-1];
// 			}

// 			arr[j] = key;
// 		}
// 	}
	
// 	// Hand evaluator - returns the type of hand and card values for a 5 card hand in order
// 	// Will return the cards ranked by value order where -1 is something we don't care about
// 	// E.G. Four of a kind will return HandEnum=FourOfAKind and ranks will be [FourOfAKind_Value, Extra card value, -1,-1,-1]
// 	function evaluateHand(int8[5] memory cards) pure public returns (HandEnum, int8[5] memory)
// 	{
// 		// order of card values to return for evaluating
// 		int8[5] memory retOrder= [-1, -1, -1, -1, -1];
// 		int8[5] memory sortCards;	// List of card values with Ace = 13
// 		uint8 i;
// 	    HandEnum handVal = HandEnum.HighCard;	// Assume high card
// 		uint8[4] memory suits = [0, 0, 0, 0];   // Count suits to check for a flush
// 		uint8[13] memory val_match = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];      // Array of values to check for pairs, ToaK, FoaK
// 		uint8 testValue = 0;
// 		CardValue cardValue;
// 		CardSuit cardSuit;
// 		int8[2] memory pairs = [-1, -1];	// Value of two pairs
// 		// Initial pass through cards
// 		for (i = 0; i < 5; i++)
// 		{
// 			(cardValue, cardSuit) = getCardName(cards[i]);
// 			testValue = uint8(cardValue);
// 			val_match[testValue]++;            //  Update val_match for card values
// 			sortCards[i] = getCardOrderValue(cardValue);
// 			// Test for 4 of a kind
// 			if (val_match[testValue] == 4 && handVal > HandEnum.FourOfAKind)
// 			{
// 				handVal = HandEnum.FourOfAKind;
// 				retOrder[0] = getCardOrderValue(cardValue);
// 			}
// 			else if (val_match[testValue] == 3 && handVal > HandEnum.ThreeOfAKind)
// 			{
// 				handVal = HandEnum.ThreeOfAKind;
// 				retOrder[0] = getCardOrderValue(cardValue);
// 			}
// 			else if (val_match[testValue] == 2)
// 			{
// 				// Handle pairs by storing off for later
// 				if (pairs[0] == -1)
// 					pairs[0] = getCardOrderValue(cardValue);
// 				else
// 					pairs[1] = getCardOrderValue(cardValue);
// 			}
// 			suits[uint8(cardSuit)]++;    //  increment suits
// 			// Handle flush situations
// 			if (suits[uint8(cardSuit)] == 5) {
// 				// flush of all five cards so we are going to return in here
// 				sortHand(sortCards);           //  Sort the cards
// 				if (sortCards[0] - sortCards[4] == 4)
// 				{        
// 					if (sortCards[0] == 13) {
// 						//  Its a royal flush
// 						handVal = HandEnum.RoyalFlush;
// 					} else {
// 						handVal = HandEnum.StraightFlush;
// 					}
// 			        return (handVal, sortCards);
// 				}
// 				else if (sortCards[0] == 13 && sortCards[1] == 4 &&
// 					sortCards[1] - sortCards[4] == 3) 			// Ace low straight flush
// 				{
// 					handVal = HandEnum.StraightFlush;
// 					retOrder = [int8(4), 3, 2, 1, 0];  // Ace Low straight
// 			        return (handVal, retOrder);
// 				}
// 				else
// 				{
// 					// it is a flush
// 					handVal = HandEnum.Flush;
// 			        return (handVal, sortCards);
// 				}

// 			}
// 		}
// 		// Check 4oaK and 3oaK
// 		if (handVal == HandEnum.FourOfAKind) {
// 			for (i = 0; i < 5; i++) {
// 				// Find the only kicker
// 				if (sortCards[i] != retOrder[0]) {
// 					retOrder[1] = sortCards[i];
// 					return (handVal, retOrder);
// 				}
// 			}
// 		} else if (handVal == HandEnum.ThreeOfAKind) {
// 			// Check for full house
// 			if (pairs[1] > -1) {
// 				handVal = HandEnum.FullHouse;
// 				if (pairs[0] == retOrder[0])
// 					retOrder[1] = pairs[1];
// 				else
// 					retOrder[1] = pairs[0];
// 				return (handVal, retOrder);
// 			}
// 			// 3oaK, so check the last two cards
// 			for (i = 0; i < 5; i++) {
// 				// Find the kickers
// 				if (sortCards[i] != retOrder[0]) {
// 					if (sortCards[i] > retOrder[1]) {
// 						retOrder[2] = retOrder[1];
// 						retOrder[1] = sortCards[i];
// 					} else {
// 						retOrder[2] = sortCards[i];
// 					}
// 				}
// 			}
// 			// return 3oaK
// 			return (handVal, retOrder);			
// 		}
// 		// check for straights via sorted rank list if not 3 of a kind or pairs
// 		if (handVal > HandEnum.ThreeOfAKind)
// 		{
// 			// no pair so could be a straight
// 			if (pairs[0] == -1) 
// 			{
// 				sortHand(sortCards);           //  Sort the cards
// 				// Check the straights
// 				if (sortCards[0] - sortCards[4] == 4) {
// 					handVal = HandEnum.Straight;
// 					return (handVal, sortCards);
// 				}
// 				else if (sortCards[0] == 13 && sortCards[1] == 4 &&
// 					sortCards[1] - sortCards[4] == 3) 			// Ace low straight
// 				{
// 					handVal = HandEnum.Straight;
// 					retOrder = [int8(4), 3, 2, 1, 0];   // Ace Low straight
// 			        return (handVal, retOrder);
// 				}
// 				else // High card only
// 				{
// 					handVal = HandEnum.HighCard;
// 			        return (handVal, sortCards);
// 				}
// 			}
// 			else	// pair or two pair
// 			{
// 				if (pairs[1] != -1)	// two pair
// 				{
// 					handVal = HandEnum.TwoPair;
// 					if (pairs[0] > pairs[1])
// 					{
// 						retOrder[0] = pairs[0];
// 						retOrder[1] = pairs[1];
// 					}
// 					else
// 					{
// 						retOrder[0] = pairs[1];
// 						retOrder[1] = pairs[0];
// 					}
// 					// find the final kicker
// 					for (i = 0; i < 5; i++) {
// 						if (sortCards[i] != pairs[0] && sortCards[i] != pairs[1]) {
// 							retOrder[2] = sortCards[i];
// 						}
// 					}
// 					return (handVal, retOrder);
// 				}
// 				else // just a pair
// 				{
// 					sortCards = sortHand(sortCards);           //  Sort the cards
// 					handVal = HandEnum.Pair;
// 					retOrder[0] = pairs[0];
// 					uint8 cnt = 1;
// 					for (i = 0; i < 5; i++)
// 					{
// 						// not the pair add to list
// 						if (sortCards[i] != pairs[0]) {
// 							retOrder[cnt] = sortCards[i];
// 							cnt++;
// 						}
// 					}
// 					return (handVal, retOrder);
// 				}
// 			}
// 		}
//         return (handVal, retOrder);
// 	}

// }
