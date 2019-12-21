Thereby I'll try to explain with a combinatorial example why usage of non perfect hash as ID over large variable dataset may be a very bad idea...
This targeting a specific issue of BorgBackup (e. g. illustrate [170#issuecomment-568156845](https://github.com/borgbackup/borg/issues/170#issuecomment-568156845) with programs)
but could be considered in generalized case.

Here are certain questions I trying to address with this PoC:

> The question whether you get collisions hashing every possible chunk (yes, of course) is not relevant.

Wrong. The number of all possible chunks is relevant in probability calculation (see below).

> a handy approximation for the probability of at least one random collision of a PRF with N output values and k inputs is k²/2N (for large k, N). For example, 1e12²/2**257 is ~4e-54.

This approximation is wrong too - simply because the number of every possible chunk (yes, of course) is relevant.

To understand the correct estimation (or else all the dependencies here)... we can use following approximation:<br/>
the task is similar to the probability of finding two cards of same type in some small subset of cards we would take from the whole deck. Two different cards of same type means a collision is found.

---

**Let us play cards** (we starting firstly with 32 classic cards):

- the deck contains `K` (32) cards (approximated to our model - big `K` would be equal the huge sum of all possible variants of the chunks with some fixed size everywhere, not in backup);
- we take `k` (3) cards from the deck (in our model - small `k` equals number of input chunks to backup);
- we playing with classic cards with maximal `n` (4) cards of every type;
- so `N` (32/4 = 8) is number of possible variants of all types (in our model - big `N` is equal the number of hashed values 2<sup>256</sup>);

The probability to find two cards of the same type (so catch a collision) in some 3 (`k`) cards from 32 (`K`) is exactly equal:
<sup>(1\*n-1)</sup>/<sub>(K-1)</sub> + (<sup>(K-n)</sup>/<sub>(K-1)</sub> \* <sup>(2\*n-2)</sup>/<sub>(K-2)</sub>) = </br>
<sup>(1\*4-1)</sup>/<sub>(32-1)</sub> + (<sup>(32-4)</sup>/<sub>(32-1)</sub> \* <sup>(2\*4-2)</sup>/<sub>(32-2)</sub>) = </br>
0.277

The explanation is simply, on iteration number...
1. with a single card we cannot have a collision, but with 1 card "blocking" 4 (`n`) cards for future "colliding" type.
2. with a second card we have a collision in case we have same type as 1st card or if not we'd "reserve" next 4 (`n`) cards and a chance to catch it at next iteration
3. with a third card we have a collision if we cross with 1st or with 2nd types of card.

The formula is also growing recursively (by `k` iterations) doe to probability graph (tree), but this dependency was already pretty clear to everyone.

If one take an attentive look at the formula, one would see that the result will grows if `K` grows too.
Although in normal case the small `n` should remain 4 (classic cards), but in our case it will also grows because we have constant big `N` (our sieve by hashing remaining constantly 2<sup>256</sup>), so the count of variations `n = K/N` grows within `K` (and `k`) together with growth of `K`.

This is pretty well visible in the following tables:

k | N    | K   | n  | P(collision)
--|------|-----|----|----------------
3 | 1..8 | 32  | 4  | 0.277
3 | 1..8 | 64  | 8  | 0.312
3 | 1..8 | 128 | 16 | 0.328

k  | N      | K      | n   | P(collision)
---|--------|--------|-----|----------------
30 | 1..800 | 3200   | 4   | 0.339
30 | 1..800 | 32000  | 40  | 0.415
30 | 1..800 | 320000 | 400 | 0.423

Thus by constant `N` (hash size), with every byte you intentionally grow the set `K` (all possible chunks) and also without of growing of sub-set `k` (all input chunks in backup), the probability is increased significantly, because the growth of `K` is exponentially (so for example by 2<sup>21</sup> bytes, value of `K` has even reached Googol<sup>1000000</sup>).
Moreover the impact increasing further not linearly with growing of number of input chunks in backup `k`.

The numbers speak for themselves and I can only repeat my statement:<br/>
Growing of max chunk size this way is questionable ("since borg 1.0, we target larger chunks of 2^21 bytes by default") moreover it is very very dangerous (you enlarge the probability of collision with every new byte in max chunk size).

I can not provide you the exact estimation how large it can be right now (need a supercomputer, or should possibly try to calculate it in CUDA), but I hope you recognize the tendency and understand now the seriousness of the issue.

For people that don't believe the formulas, I wrote a program estimating the probability (iterative) as well as using a recursive calculation (probability tree), which confirms the numbers.
Here are few examples:
```bash
$ id-hash-colprob.tcl 32 3 8 1000
k = 3 cards from K = 32 max, by sieve N = 1..8, repeated n = 4 times:
Calc-P(collision)=0.2774193548387097
Estm-P(collision)=0.27630985264501645
Results: iter 90869 no 65761 yes 25108
11.0050 µs/# 90869 # 90868.0 #/sec 1000.011 net-ms

$ id-hash-colprob.tcl 64 3 8 1000
k = 3 cards from K = 64 max, by sieve N = 1..8, repeated n = 8 times:
Calc-P(collision)=0.31182795698924726
Estm-P(collision)=0.3100930396890826
Results: iter 76419 no 52722 yes 23697
13.0858 µs/# 76419 # 76418.8 #/sec 1000.003 net-ms

$ id-hash-colprob.tcl 128 3 8 1000
k = 3 cards from K = 128 max, by sieve N = 1..8, repeated n = 16 times:
Calc-P(collision)=0.32808398950131235
Estm-P(collision)=0.32677005383807944
Results: iter 59066 no 39765 yes 19301
16.9303 µs/# 59066 # 59065.5 #/sec 1000.008 net-ms

# ---

$ id-hash-colprob.tcl 36 10 9 1000
k = 10 cards from K = 36 max, by sieve N = 1..9, repeated n = 4 times:
Calc-P(collision)=1.0
Estm-P(collision)=1.0
Results: iter 63674 no 0 yes 63674
15.7050 µs/# 63674 # 63674.0 #/sec 1000.000 net-ms

$ id-hash-colprob.tcl 32 4 8 1000
k = 4 cards from K = 32 max, by sieve N = 1..8, repeated n = 4 times:
Calc-P(collision)=0.5016685205784205
Estm-P(collision)=0.5044833557821821
Results: iter 77955 no 38628 yes 39327
12.8281 µs/# 77955 # 77954.1 #/sec 1000.012 net-ms

```
