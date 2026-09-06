# data501_package
This is a repository of where I'll store my DATA501 progress, code, and R + Rcpp code, and will include relevant documentation, 


## styloprofile

The R package in this repository is called **`styloprofile`**. It builds toward a
stylometric outlier detector: rather than training a binary human-vs-AI
classifier, it describes typical human writing with a handful of interpretable
numeric features and measures how far a new document sits from that description,
using the Mahalanobis distance.

References: Fröhling & Zubiaga (2021), *PeerJ Computer Science* 7:e443;
Mahalanobis (1936), *Proc. Nat. Inst. Sci. India* 2(1):49–55.

### Install

```r
# install.packages("remotes")
remotes::install_github("ArmandFS/data501_package")
```

Note the repository is `data501_package` but the package it installs is
`styloprofile`.

### Current functions

| Function | Purpose |
|---|---|
| `stylo_features()` | Extracts 5 stylometric features from documents |
| `mahalanobis_sq()` | Squared Mahalanobis distance via a Cholesky factor |
| `count_syllables_cpp()` | Syllable counter (C++, via Rcpp) |
| `count_syllables_r()` | Syllable counter (pure R reference implementation) |

```r
library(styloprofile)

count_syllables_cpp(c("cat", "table", "beautiful"))
#> [1] 1 2 3

stylo_features(c(
  "The cat sat. It was quiet, and nobody moved.",
  "Consequently, the extraordinary ramifications remained incomprehensible."
))
```

### Tests

Unit tests cover `mahalanobis_sq()` and `count_syllables_cpp()`.

```r
devtools::test()   # 48 tests
devtools::check()  # 0 errors, 0 warnings, 0 notes
```

`mahalanobis_sq()` is checked against `stats::mahalanobis()` as an independent
oracle, and against mathematical identities the distance must satisfy (affine
invariance, zero at the centre, reduction to Euclidean distance under an
identity covariance). `count_syllables_cpp()` is checked by differential testing
against `count_syllables_r()`, plus hand-computed counts so that the two
implementations cannot be wrong in the same way undetected.
