// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import {DpTables} from "./DpTables.sol";

import {Flush1} from "./flush/Flush1.sol";
import {Flush2} from "./flush/Flush2.sol";
import {Flush3} from "./flush/Flush3.sol";

import {NoFlush1} from "./noFlush/NoFlush1.sol";
import {NoFlush2} from "./noFlush/NoFlush2.sol";
import {NoFlush3} from "./noFlush/NoFlush3.sol";
import {NoFlush4} from "./noFlush/NoFlush4.sol";
import {NoFlush5} from "./noFlush/NoFlush5.sol";
import {NoFlush6} from "./noFlush/NoFlush6.sol";
import {NoFlush7} from "./noFlush/NoFlush7.sol";
import {NoFlush8} from "./noFlush/NoFlush8.sol";
import {NoFlush9} from "./noFlush/NoFlush9.sol";
import {NoFlush10} from "./noFlush/NoFlush10.sol";
import {NoFlush11} from "./noFlush/NoFlush11.sol";
import {NoFlush12} from "./noFlush/NoFlush12.sol";
import {NoFlush13} from "./noFlush/NoFlush13.sol";
import {NoFlush14} from "./noFlush/NoFlush14.sol";
import {NoFlush15} from "./noFlush/NoFlush15.sol";
import {NoFlush16} from "./noFlush/NoFlush16.sol";
import {NoFlush17} from "./noFlush/NoFlush17.sol";


contract Evaluator7 {

    address public immutable DP_TABLES;
    address[3] public  FLUSH_ADDRESSES;
    address[16] public NOFLUSH_ADDRESSES;

    uint[52] public binaries_by_id = [  // 52
        0x1,  0x1,  0x1,  0x1,
        0x2,  0x2,  0x2,  0x2,
        0x4,  0x4,  0x4,  0x4,
        0x8,  0x8,  0x8,  0x8,
        0x10, 0x10, 0x10, 0x10,
        0x20, 0x20, 0x20, 0x20,
        0x40, 0x40, 0x40, 0x40,
        0x80, 0x80, 0x80, 0x80,
        0x100,  0x100,  0x100,  0x100,
        0x200,  0x200,  0x200,  0x200,
        0x400,  0x400,  0x400,  0x400,
        0x800,  0x800,  0x800,  0x800,
        0x1000, 0x1000, 0x1000, 0x1000
    ];

    uint[52] public suitbit_by_id = [ // 52
        0x1,  0x8,  0x40, 0x200,
        0x1,  0x8,  0x40, 0x200,
        0x1,  0x8,  0x40, 0x200,
        0x1,  0x8,  0x40, 0x200,
        0x1,  0x8,  0x40, 0x200,
        0x1,  0x8,  0x40, 0x200,
        0x1,  0x8,  0x40, 0x200,
        0x1,  0x8,  0x40, 0x200,
        0x1,  0x8,  0x40, 0x200,
        0x1,  0x8,  0x40, 0x200,
        0x1,  0x8,  0x40, 0x200,
        0x1,  0x8,  0x40, 0x200,
        0x1,  0x8,  0x40, 0x200
    ];

    constructor(address _dpTables, address[3] memory _flushes, address[16] memory _noflushes)  {
        DP_TABLES = _dpTables;

        for (uint i=0; i<_flushes.length; i++) {
            FLUSH_ADDRESSES[i] = _flushes[i];
        }

        for (uint j=0; j<_noflushes.length; j++) {
            NOFLUSH_ADDRESSES[j] = _noflushes[j];
        }
    }

    function evaluate(uint a, uint b, uint c , uint d, uint e, uint f, uint g) public view returns (uint) {
        uint suit_hash = 0;
        uint[4] memory suit_binary = [ uint(0), uint(0), uint(0), uint(0) ]; // 4
        uint8[13] memory quinary = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ]; // 13
        uint hsh;

        suit_hash += suitbit_by_id[a];
        quinary[(a >> 2)]++;
        suit_hash += suitbit_by_id[b];
        quinary[(b >> 2)]++;
        suit_hash += suitbit_by_id[c];
        quinary[(c >> 2)]++;
        suit_hash += suitbit_by_id[d];
        quinary[(d >> 2)]++;
        suit_hash += suitbit_by_id[e];
        quinary[(e >> 2)]++;
        suit_hash += suitbit_by_id[f];
        quinary[(f >> 2)]++;
        suit_hash += suitbit_by_id[g];
        quinary[(g >> 2)]++;

        uint suits = DpTables(DP_TABLES).suits(suit_hash);

        if (suits > 0) {
            suit_binary[a & 0x3] |= binaries_by_id[a];
            suit_binary[b & 0x3] |= binaries_by_id[b];
            suit_binary[c & 0x3] |= binaries_by_id[c];
            suit_binary[d & 0x3] |= binaries_by_id[d];
            suit_binary[e & 0x3] |= binaries_by_id[e];
            suit_binary[f & 0x3] |= binaries_by_id[f];
            suit_binary[g & 0x3] |= binaries_by_id[g];

            uint sb = suit_binary[suits - 1];

            if (sb < 3000) {
                return Flush1(FLUSH_ADDRESSES[0]).flush(suit_binary[suits - 1]);
            } else if (sb < 6000) {
                return Flush2(FLUSH_ADDRESSES[1]).flush(suit_binary[suits - 1]);
            } else {
                return Flush3(FLUSH_ADDRESSES[2]).flush(suit_binary[suits - 1]);
            }

        }     

        hsh = hash_quinary(quinary, 13, 7);

        if (hsh < 3000) {
            return NoFlush1(NOFLUSH_ADDRESSES[0]).noflush(hsh);
        } else if (hsh < 6000 ) {
            return NoFlush2(NOFLUSH_ADDRESSES[1]).noflush(hsh);

        } else if (hsh < 9000) {
            return NoFlush3(NOFLUSH_ADDRESSES[2]).noflush(hsh);

        } else if (hsh < 12000) {
            return NoFlush4(NOFLUSH_ADDRESSES[3]).noflush(hsh);

        } else if (hsh < 15000) {
            return NoFlush5(NOFLUSH_ADDRESSES[4]).noflush(hsh);

        } else if (hsh < 18000) {
            return NoFlush6(NOFLUSH_ADDRESSES[5]).noflush(hsh);

        } else if (hsh < 21000) {
            return NoFlush7(NOFLUSH_ADDRESSES[6]).noflush(hsh);

        } else if (hsh < 24000) {
            return NoFlush8(NOFLUSH_ADDRESSES[7]).noflush(hsh);

        } else if (hsh < 27000) {
            return NoFlush9(NOFLUSH_ADDRESSES[8]).noflush(hsh);

        } else if (hsh < 30000) {
            return NoFlush10(NOFLUSH_ADDRESSES[9]).noflush(hsh);

        } else if (hsh < 33000) {
            return NoFlush11(NOFLUSH_ADDRESSES[10]).noflush(hsh);

        } else if (hsh < 36000) {
            return NoFlush12(NOFLUSH_ADDRESSES[11]).noflush(hsh);

        } else if (hsh < 39000) {
            return NoFlush13(NOFLUSH_ADDRESSES[12]).noflush(hsh);

        } else if (hsh < 42000) {
            return NoFlush14(NOFLUSH_ADDRESSES[13]).noflush(hsh);

        } else if (hsh < 45000) {
            return NoFlush15(NOFLUSH_ADDRESSES[14]).noflush(hsh);

        } else {
            return NoFlush16(NOFLUSH_ADDRESSES[15]).noflush(hsh);
        }

    }

    function hash_quinary(uint8[13] memory q, uint len, uint k) public view returns (uint sum) {

        for (uint i = 0; i < len; i++) {
            sum += DpTables(DP_TABLES).dp(q[i], (len - i - 1), k);

            k -= q[i];

            if (k <= 0) break;
        }
    }
}