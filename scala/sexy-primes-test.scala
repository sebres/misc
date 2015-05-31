import sys.exit
import scala.util.control.Breaks._
import scala.math.sqrt


var maxN = 100000
var startFrom: Option[String] = None
var times = 1
val variants = Array("org", "mod1", "mod2", "org2", "max", "orgm", "siev", "osie1", "osie2")

def usage() {
  print("usage: scala sexy-primes-test.scala ?max? ?start-from? ?times?" +
    "\n  max -- (default 100000) calc prime below max" +
    "\n  start-from -- (default \"org\" or \"max\" for max > 100K) start from variant:\n    " +
    variants.mkString(", ") +
    "\n  times -- (default 1) repeat for multiple iterations")
  exit()
}

if (args.length > 0) {
  if (List("-?", "/?", "/h", "-h", "-help", "--help", "/help").contains(args(0)))
    usage()
  maxN = args(0).toInt
  if (args.length > 1) {
    startFrom = Some(args(1))
    if (args.length > 2)
      times = args(2).toInt
  }
}

val start = startFrom match {
  case Some(x) => x
  case None => if (maxN <= 100 * 1000) "org" else "max"
}

if (!variants.contains(start)) {
  print(s"wrong # args: unexpected variant '$start' in start-from argument")
  usage()
}

var comp_l: Array[Array[Int]] = null
for (t <- variants drop variants.indexOf(start)) {
  var proceed = true
  var sexy_primes_below: Option[(Int) => Iterable[Array[Int]]] = None
  var primes_sieve: (Int) => Array[Boolean] = null
  var is_prime: (Int) => Boolean = null

  if (t == "org") {
    is_prime = (n: Int) => {
      (2 until n).forall(i => (n % i) != 0)
    }
  }

  else if (t == "mod1") {
    is_prime = (n: Int) => {
      var i = 2
      var result = true
      breakable {
        while (true) {
          if ((n % i) == 0) {
            result = false
            break()
          }
          i += 1
          if (i >= n) break()
        }
      }
      result
    }
  }

  else if (t == "mod2") {
    is_prime = (n: Int) => {
      if ((n % 2) == 0) {
        false
      } else {
        var i = 3
        var result = true
        breakable {
          while (true) {
            if ((n % i) == 0) {
              result = false
              break()
            }
            i += 2
            if (i >= n) break()
          }
        }
        result
      }
    }
  }

  else if (t == "org2") {
    is_prime = (n: Int) => {
      (n % 2) != 0 && (3 until(n, 2)).forall(i => (n % i) != 0)
    }
  }

  else if (t == "max") {
    is_prime = (n: Int) => {
      if ((n & 1) == 0) {
        false
      } else {
        var i = 3
        var result = 1
        breakable {
          while (true) {
            if ((n % i) == 0) {
              result = 0
              break()
            }
            if (i * i > n) break()
            i += 2
          }
        }
        result != 0
      }
    }
  }

  else if (t == "orgm") {
    is_prime = (n: Int) => {
      (n & 1) != 0 && (3 until(sqrt(n).intValue + 1, 2)).forall(i => (n % i) != 0)
    }
  }

  else if (t == "siev") {
    primes_sieve = (n: Int) => {
      // temporary "half" mask sieve for primes < n (using bool)
      var sieve = Array.fill(n / 2)(true)
      for (i <- 3 until(sqrt(n).intValue + 1, 2)) {
        if (sieve(i / 2)) {
          (i * i / 2 until(sieve.size, i)).foreach(x => {
            sieve(x) = false
          })
        }
      }
      sieve
    }
    sexy_primes_below = Some((n: Int) => {
      val sieve = primes_sieve(n + 1)
      for (
        j <- 9 until n + 1;
        i = j - 6;
        if ((i & 1) != 0 && sieve(i / 2) && sieve(j / 2))
      ) yield Array(i, j)
    })
  }

  else if (List("osie1", "osie2").contains(t)) {
    var primesSieveInt: (Int) => Array[Int] = null
    if (t == "osie1") {
      primesSieveInt = (n: Int) => {
        // temporary odd direct sieve for primes < n
        val sieve = (3 until(n, 2)).toArray
        val l = sieve.length
        breakable {
          for (i <- sieve) {
            if (i != 0) {
              val f = (i * i - 3) / 2
              if (f >= l)
                break()
              (f until(sieve.size, i)).foreach({
                sieve(_) = 0
              })
            }
          }
        }
        sieve
      }
    }
    if (t == "osie2") {
      primesSieveInt = (n: Int) => {
        // temporary odd direct sieve for primes < n
        val l = ((n - 3) / 2)
        val sieve = Array.fill(l)(-1)
        breakable {
          for (k <- 3 until(n, 2)) {
            val o = (k - 3) / 2
            var i = sieve(o)
            if (i == -1) {
              i = k
              sieve((k - 3) / 2) = k
            }
            if (i != 0) {
              val f = (i * i - 3) / 2
              if (f >= l)
                break()
              (f until(sieve.size, i)).foreach({
                sieve(_) = 0
              })
            }
          }
        }
        sieve
      }
    }
    sexy_primes_below = Some((n: Int) => {
      val sieve = primesSieveInt(n + 1)
      for (
        j <- 9 until n + 1;
        i = j - 6;
        if ((i & 1) != 0 && sieve((i - 2) / 2) != 0 && sieve((j - 2) / 2) != 0)
      ) yield Array(i, j)
    })
  }

  else
    proceed = false

  if (proceed) {
    // simple "sexy_primes_below" using is_prime :
    if (!sexy_primes_below.isDefined) {
      sexy_primes_below = Some((n: Int) => {
        for (
          j <- 9 until n + 1;
          if (is_prime(j - 6) && is_prime(j))
        ) yield Array(j - 6, j)
      })
    }

    var c = times
    var l: Array[Array[Int]] = null
    val a = System.nanoTime
    while (c > 0) {
      l = sexy_primes_below.get.apply(maxN).toArray
      c -= 1
    }
    val b = System.nanoTime

    val b1 = ((b - a) / times).toDouble / 1e9
    print("%5s === %8.5f s === %10.2f mils  |  %s\n" format(t, b1, b1 * 1000,
      ("%d sp: %s, %s, ... %s, %s" format(
        l.length, l(0).toList, l(1).toList, l(l.size - 2).toList, l.last.toList
        ))))

    if (comp_l == null) {
      comp_l = l
    }
    else if (l.deep != comp_l.deep) {
      throw new RuntimeException("wrong list of sexy primes retrieved ...")
    }
  }
}
