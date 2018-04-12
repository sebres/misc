#!/usr/bin/python

# try to prove - python can be fast (python vs scala etc.).
# some benchmarks/tests was original found :
#   http://stackoverflow.com/questions/11641098/interpreting-a-benchmark-in-c-clojure-python-ruby-scala-and-others

from sys import argv
#import math
import time

max_n = '100K'
start_from = None;
times = 1
variants = ('org', 'mod1', 'mod2', 'org2', 'max', 'orgm', 'gesiv', 'gesim', 'siev1', 'siev2', 'osie1', 'osie2')

def usage():
  print('usage: ?pypy|python? sexy-primes-test.py ?max? ?start-from? ?times?' + 
    '\n  max -- (default 10*1000) calc prime below max' +
    '\n  start-from -- (default "org" or "max" for max > 100K) start from variant:\n    ' + ', '.join(variants) +
    '\n  times -- (default 1) repeat for multiple iterations')
  exit()

if len(argv) > 1:
  if (argv[1] in ('-?', '/?', '/h', '-h', '-help', '--help', '/help')):
    usage()
  max_n = argv[1]
  if len(argv) > 2:
    start_from = argv[2]
    if len(argv) > 3:
      times = eval(argv[3])

max_n = int(eval(max_n.upper().replace('K', '*1000').replace('M', '*10**6').replace('G', '*10**9')))
if start_from is None:
  start_from = 'org' if (max_n <= 100*1000) else 'max'

if start_from not in variants:
  print('wrong # args: unexpected variant "%s" in start-from argument' % start_from)
  usage()

comp_l = None
for t in variants[variants.index(start_from):]:

  sexy_primes_below = None

  if t == 'org':
    def is_prime(n):
      return all((n % i > 0) for i in range(2, n))

  elif t == 'mod1':
    def is_prime(n):
      i = 2
      while True:
        if not n % i:
           return False
        i += 1
        if i >= n:
           return True
      return True

  elif t == 'mod2':
    def is_prime(n):
      if not n % 2:
        return False
      i = 3
      while True:
        if n % i == 0:
           return False
        i += 2
        if i >= n:
           return True
      return True

  elif t == 'org2':
    def is_prime(n):
      return n % 2 and all(n % i for i in range(3, n, 2))

  elif t == 'max':
    def is_prime(n):
      if not n & 1:
        return 0
      i = 3
      while 1:
        if not n % i:
           return 0
        if i * i > n:
           return 1
        i += 2
      return 1

  elif t == 'orgm':
    def is_prime(n):
      #return ((n & 1) and all(n % i for i in range(3, int(math.sqrt(n))+1, 2)))
      return ((n & 1) and all(n % i for i in range(3, int(n**0.5)+1, 2)))

  elif t in ('gesiv', 'gesim') :
    if t == 'gesiv':
      def primes_gen():
        """ original generator for primes via the sieve of eratosthenes """
        D = {}
        q = 2
        while 1:
          if q not in D:
            yield q
            D[q*q] = [q]
          else:
            for p in D[q]:
              D.setdefault(p+q,[]).append(p)
            del D[q]
          q += 1
    elif t == 'gesim':
      def primes_gen():
        """ modified generator for primes via the sieve of eratosthenes """
        D = {}
        yield 2
        q = 1
        while True:
          q += 2
          p = D.pop(q, 0)
          if p:
            x = q + p
            while x in D: x += p
            if x & 1:
              D[x] = p
            continue
          yield q
          x = q*q
          if x & 1:
            D[x] = 2*q
    def sexy_primes_below(n):
      l = []
      pp = {}
      for j in primes_gen():
        if j > n: break
        pp[j] = 1
        if j >= 9:
          i = j-6
          if pp.pop(i, 0):
            l.append([i, j])
      return l

  elif t in ('siev1', 'siev2'):
    if t == 'siev1':
      def primes_sieve(n):
        """ temporary "half" mask sieve for primes < n (using bool) """
        sieve = [True] * (n//2)
        for i in range(3, int(n**0.5)+1, 2):
          if sieve[i//2]:
            sieve[i*i//2::i] = [False] * ((n-i*i-1)//(2*i)+1)
        return sieve
    if t == 'siev2':
      def primes_sieve(n):
        """ temporary "half" mask sieve for primes < n (using int)"""
        sieve = [1] * (n//2)
        for i in range(3, int(n**0.5)+1, 2):
          if sieve[i//2]:
            sieve[i*i//2::i] = [0] * ((n-i*i-1)//(2*i)+1)
        return sieve
    def primes(n):
      """ returns a list of primes < n """
      sieve = primes_sieve(n)
      return [2] + [2*i+1 for i in range(1, n//2) if sieve[i]]
    def sexy_primes_below(n):
      l = []
      sieve = primes_sieve(n+1)
      #is_prime = lambda j: (j & 1) and sieve[j//2]
      for j in range(9, n+1, 2):
        i = j-6
        #if (i & 1) and is_prime(i) and is_prime(j):
        if sieve[i//2] and sieve[j//2]:
          l.append([i, j])
      return l

  elif t in ('osie1', 'osie2') :
    if t == 'osie1':
      def primes_sieve(n):
        """ temporary odd direct sieve for primes < n """
        sieve = list(range(3, n, 2))
        l = len(sieve)
        for i in sieve:
          if i:
            f = (i*i-3) // 2
            if f >= l:
              break
            sieve[f::i] = [0] * -((f-l) // i)
        return sieve
    if t == 'osie2':
      def primes_sieve(n):
        """ temporary odd direct sieve for primes < n """
        #sieve = list(range(3, n, 2))
        l = ((n-3)//2)
        sieve = [-1] * l
        for k in range(3, n, 2):
          o = (k-3)//2
          i = sieve[o]
          if i == -1:
            i = sieve[(k-3)//2] = k
          if i:
            f = (i*i-3) // 2
            if f >= l:
              break
            sieve[f::i] = [0] * -((f-l) // i)
        return sieve
    def sexy_primes_below(n):
      l = []
      sieve = primes_sieve(n+1)
      #is_prime = lambda j: (j & 1) and sieve[(j-2)//2]
      for j in range(9, n+1, 2):
        i = j-6
        #if (i & 1) and is_prime(i) and is_prime(j):
        if sieve[(i-2)//2] and sieve[(j-2)//2]:
          l.append([i, j])
      return l
  else:
    continue

  # simple "sexy_primes_below" using is_prime :
  if not sexy_primes_below:
    # def sexy_primes_below(n):
    #   return [[j-6, j] for j in range(9, n+1) if is_prime(j) and is_prime(j-6)]
    def sexy_primes_below(n):
      l = []
      for j in range(9, n+1):
        if is_prime(j-6) and is_prime(j):
          l.append([j-6, j])
      return l


  c = times
  l = None
  a = time.time()
  while c:
    l = None
    l = sexy_primes_below(max_n)
    c -= 1
  b = time.time()

  b = (b-a) / times
  print("%5s === %8.5f s === %10.2f mils  |  %s\n" % (t, b, b*1000,
    ("%d sp: %s, %s, ... %s, %s" % (len(l), l[0], l[1], l[-2], l[-1]))))

  if comp_l is None:
    comp_l = l
    #print(l)
  elif l != comp_l:
    #print(l)
    raise Exception('wrong list of sexy primes retrieved ...')
