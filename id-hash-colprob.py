#!/usr/bin/env python

import sys
def _opt(i, dflt=None):
  return int(sys.argv[i]) if len(sys.argv) > i else dflt

if len(sys.argv) <= 3:
  print("""usage: %s K k N ?TM?
  # K  - cards in deck
  # k  - cards we will take from the deck
  # N  - variants of different card types (we can \"hash\" at all)
  # TM - time to run estimation (iterate)""" % sys.argv[0])
  sys.exit(0)

K = _opt(1);  # K cards in deck
k = _opt(2);  # k cards we will take from the deck
N = _opt(3);  # N variants of different card types (we can "hash" at all)
TM = _opt(4); # time to run estimation (iterate)

if k > K or N > K:
  print("k and N should be less or equal K, but %s > %s or %s > %s" % (k, K, N, K))
  sys.exit(1)
if K % N:
  print("Warning: n is not decimal, we have rest by %s / %s (%s %% %s != 0), estimated and calculated probabilities may vary" % (
    K, N, K, N))

n = K / N
print("k = %s cards from K = %s max, by sieve N = 1..%d, repeated n = %d times:" % (k, K, N, n))

# calculate (recursive probability tree):

def calcp(K, n, k):
  # unfold recursion to cycle (multiply backwards starting from last iteration),
  # calculate iterative considering previous value (and both chances on every iteration):
  v = 0.0
  while k:
    k -= 1
    v = float(k*n-k)/(K-k) + float(K-n*k)/(K-k) * v
  return v
print("Calc-P(collision)=%s" % calcp(K, n, k))

# estimation (simulate playing):
if TM:
  import time, random
  # fill the array NewDck with a card deck (K cards in deck, repeats K/N times of N variants of the cards):
  NewDck = []
  v = 0
  i = 0
  while i < K:
    v += 1
    NewDck.append(v)
    if v >= N: v = 0
    i += 1
  # print(NewDck)

  # run estimation cycle:
  col = {}
  col['yes'] = 0
  col['no'] = 0

  endTM = time.time() + float(TM) / 1000
  while time.time() < endTM:
    Dck = list(i for i in NewDck)
    Tk = {}
    # take k cards and check for a collision:
    fnd = 0
    x = 1
    while x <= k:
      while 1:
        i = random.randint(0, K-1); # random index in deck
        t = Dck[i]
        if t != -1: break; # unused card
      if t in Tk:
        fnd = 1; break;   # same type of card (collision) found
      Tk[t] = 1;          # add new know type in subset of cards
      Dck[i] = -1;        # mark card as used in deck
      x += 1
    if fnd: # incr count of collision / success
      col['yes'] += 1
    else:
      col['no'] += 1

  col['iter'] = col['no']+col['yes']
  print("Estm-P(collision)=%s" % (float(col['yes'])/col['iter'],))
  print("Results: %s" % col)
