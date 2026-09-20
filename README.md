# styloprofile

**DATA501 Software Project — Armand Surbakti (300680133)**

An R package that measures how far a document sits from a statistical profile of
human writing. Rather than training a binary human-vs-AI classifier, it
describes typical human writing with five interpretable stylometric features and
scores new documents against that description by two complementary distances.

A high score means a document is unusual *relative to the reference corpus*. It
is not evidence that the document was machine-generated.

---

## Installation Guide And Steps

```r
# install.packages("remotes")
remotes::install_github("ArmandFS/data501_package")
```

The repository is `data501_package`; the package it installs is `styloprofile`.
It compiles C++ via Rcpp, so you might need a specific toolchain, and also depending on your operating system as well.
([Rtools](https://cran.r-project.org/bin/windows/Rtools/) on Windows, Xcode
command line tools on macOS).

## Verifying the Installation

When pasting this whole code block, It utilizes the Rcpp code, the various S3 classes, and both
distance methods (mahalanobis and cosine similarity), using the corpus bundled with the package.

```r
library(styloprofile)

## 1. the compiled Rcpp function
count_syllables_cpp(c("cat", "table", "make", "beautiful", "queue"))
#> [1] 1 2 1 3 1

## 2. the OO function -- returns an object with methods
profile <- build_profile(lidar_reference$abstract)
#> Profile built from 245 documents on 5 features.

class(profile)
#> [1] "stylo_profile"

summary(profile)

## 3. score new documents by either method
scores <- score(lidar_contrast$abstract, profile, method = "mahalanobis")
class(scores)
#> [1] "stylo_score"

summary(scores)

## 4. run the unit tests
testthat::test_local()
#> [ FAIL 0 | WARN 0 | SKIP 0 | PASS 142 ]
```

To run the full package check from a clone:

```r
devtools::check()   # 0 errors, 0 warnings, 0 notes
```

---

## Assignment 2 report

### 1. This is an object oriented function with Rcpp as well. 

**`build_profile()`** and **`score()`**.

`build_profile()` takes a corpus and returns an object of class
`stylo_profile`. `score()` takes documents and a profile and returns an object
of class `stylo_score`. Both are S3 classes with `print` and `summary` methods,
and `summary` itself returns a classed object with its own `print` method — the
same structure `stats::aov()` uses.

| Classes | Constructors | Methods |
|---|---|---|
| `stylo_profile` | `build_profile()` | `print`, `summary` |
| `summary.stylo_profile` | `summary()` | `print` |
| `stylo_score` | `score()` | `print`, `summary` |
| `summary.stylo_score` | `summary()` | `print` |

**The Rcpp function.** Given any raw text from a document, `build_profile()` calls
`stylo_features()`, which calls the compiled `count_syllables_cpp()` to compute
`prop_polysyllabic`. The call chain and flow is:

```
build_profile(text) -> stylo_features() -> count_syllables_cpp()   [C++]
                                        -> .Call()                 [RcppExports.R]
                                        -> src/count_syllables.cpp
```

Syllable counting is a character-by-character scan carrying state between
iterations. Measured on 10,000 words over 20 repetitions:

| Implementation Method | Median |
|---|---|
| `count_syllables_cpp()` | 1.97 ms |
| `count_syllables_r()` | 27.11 ms |

This is around **13.8× faster**, which is what justifies the compilation step.

`stylo_score` deliberately subclasses a numeric vector, so `d >= 0`,
`median(d)` and `length(d)` all still works.

### 2. An R function that tests the previous function

`count_syllables_r()` is an R implementation of the same algorithm as
`count_syllables_cpp()`, written to serve as the **test oracle**. Differential
testing in `tests/testthat/test-syllables.R` compares the two over a curated
word list, roughly 500 randomly generated strings, and a messy input on purpose:

```r
test_that("agrees with the R implementation on random letter strings", {
  set.seed(7)
  words <- vapply(seq_len(500), function(i) {
    paste(sample(letters, sample(1:12, 1), replace = TRUE), collapse = "")
  }, character(1))
  expect_equal(count_syllables_cpp(words), count_syllables_r(words))
})
```

The test functions and files are in `tests/testthat/`, and is run via `devtools::test()` or `testthat::test_local()`.

### 3. The different unit tests

```r
devtools::test()
#> [ FAIL 0 | WARN 0 | SKIP 0 | PASS 142 ]
```

**142 expectations across 77 `test_that` blocks in 5 files:**

| File | Blocks | Expectations | Covers |
|---|---|---|---|
| `test-angular.R` | 12 | 21 | `cosine_sim()`, `angular_dist()` |
| `test-corpus.R` | 20 | 35 | corpus query, parsing, bundled data |
| `test-mahalanobis.R` | 13 | 22 | `mahalanobis_sq()` |
| `test-profile.R` | 19 | 38 | `build_profile()`, `score()`, S3 methods |
| `test-syllables.R` | 13 | 26 | `count_syllables_cpp()` / `_r()` |

#### The selection principle

Functions were chosen for testing because their correct answers are knowable independently of how they are
implemented. A test written by reading the implementation and asserting it
returns what it currently returns proves only that the code has not changed; it
cannot detect that the code was wrong from the start.

Four kinds of oracle are used.

**(a) Independent implementations.** `mahalanobis_sq()` is checked against
`stats::mahalanobis()`. The same logic
drives `count_syllables_cpp()` against `count_syllables_r()`.

**(b) Certified values.** Angles are known in advance from geometry, so these
would catch the function being wrong at the first commit:

```r
expect_equal(angular_dist(c(1, 0), c(1, 0)),  0)      # identical
expect_equal(angular_dist(c(1, 0), c(1, 1)),  0.25)   # 45 degrees
expect_equal(angular_dist(c(1, 0), c(0, 1)),  0.5)    # orthogonal
expect_equal(angular_dist(c(1, 0), c(-1, 0)), 1)      # opposing
```

Eight syllable counts are pinned the same way (`cat` = 1, `table` = 2,
`queue` = 1, `rhythm` = 1). This is good because differential testing alone has
a specific weakness: two implementations written by the same author from the
same specification can be wrong in the same way and would agree perfectly.
Hand-computed anchors would catch that; the cross-check catches translation errors.
Both are needed.

**(c) Mathematical identities.** Properties any correct implementation must
satisfy, whatever algorithm it uses:

- *Reduction to Euclidean distance.* When Σ = I, D² must equal the squared
  Euclidean distance from the centre.
- *Zero at the centre.* D²(μ) = 0 exactly.
- *Affine invariance.* Under x ↦ Ax + b with Σ ↦ AΣAᵀ, every distance is
  unchanged — the distance cannot depend on the units the features are measured
  in. 
- *Triangle inequality.* `acos(cos θ)/π` is a true metric; `1 − cos θ` is not.
  The test asserts both halves, so it also justifies why I chose that design choice.

  | | d(a,c) | d(a,b) + d(b,c) | Metric? |
  |---|---|---|---|
  | Angular | 0.5 | 0.25 + 0.25 = 0.5 | holds |
  | Cosine | 1.0 | 0.293 + 0.293 = 0.586 | violated |

- *Factor correctness.* `t(R) %*% R` must reproduce the covariance it came from.

**(d) Invalid input and edge cases.** Each malformed argument has a test
asserting both that an error is raised and that its *message names the problem*,
rather than a plausible-looking number being returned:

```r
expect_error(mahalanobis_sq(x, center[1:2], R), "length 2.*3 columns")
```

Rejecting `NA` rather than propagating it is deliberate — an `NA` distance would
flow into a downstream verdict and be easy to miss.

Edge cases get more attention on the compiled function than its line count
suggests, because a bug in C++ is quieter than the same bug in R. The silent-`e`
branch indexes `w[len - 3]`, so 1-to-3 letter words are exactly the inputs that
could read out of bounds. In R an out-of-range index raises an error or returns
`NA`.

#### Two bugs the tests actually caught

These were found while writing the tests, not afterwards:

1. **`as.Date("30-11-2022", format = "%Y-%m-%d")` returns year 30**, not an
   error — R's date parser is lenient. `build_oa_filter()` now checks the
   string's shape before its value.
2. **`acos()` returns `NaN` on a self-comparison.** Floating point pushes an
   exact self-similarity to `1 + 2.2e-16`, and `acos()` of anything above 1 is
   undefined. The clamp in `cosine_sim()` is load-bearing and has its own test.

---

## Functions

| Function | Purpose |
|---|---|
| `fetch_corpus()` | Downloads a corpus of abstracts from OpenAlex |
| `build_oa_filter()` | Builds the OpenAlex query for a topic, journal and window |
| `read_corpus_json()` | Parses a saved OpenAlex response |
| `stylo_features()` | Extracts 5 stylometric features from documents |
| `build_profile()` | Summarises a corpus into a `stylo_profile` |
| `score()` | Scores documents against a profile, returns a `stylo_score` |
| `mahalanobis_sq()` | Squared Mahalanobis distance via a Cholesky factor |
| `angular_dist()` | Angular distance in `[0, 1]` |
| `cosine_sim()` | Cosine similarity in `[-1, 1]` |
| `count_syllables_cpp()` | Syllable counter (C++, via Rcpp) |
| `count_syllables_r()` | Syllable counter (pure R, the test oracle) |

### The features

| Feature | Definition |
|---|---|
| `mean_sentence_length` | Word tokens per sentence |
| `conj_rate` | Coordinating and subordinating conjunctions per sentence |
| `cv_word_length` | Coefficient of variation of word length, s/x̄ |
| `prop_polysyllabic` | Proportion of tokens with three or more syllables |
| `vocab_sophistication` | Proportion of tokens outside a 517-word common band |

Each is a rate, proportion or ratio, so documents of different lengths can stay
comparable.

### The two distances

They answer different questions, which is why both are offered.

- **Mahalanobis** responds to a document being *extreme*, once the spread and
  correlation of the features are accounted for. Computed from a Cholesky
  factor rather than an explicit inverse, so a profile factorises once and
  reuses it for every document scored.
- **Angular** divides each feature by its reference standard deviation and
  measures the angle to the reference direction, so it responds to the
  proportions between features being wrong even when nothing is extreme.

---

## Corpus Database

Both corpora are lidar articles from a **single journal**, the IEEE Journal of
Selected Topics in Applied Earth Observations and Remote Sensing (OpenAlex
`S117727964`), retrieved from OpenAlex:

| Dataset | Window | n | Median abstract |
|---|---|---|---|
| `lidar_reference` | 2008 → 2022-12-31 | 245 | 223 words |
| `lidar_contrast` | 2023-01-01 → 2026 | 211 | 231 words |

Holding the journal fixed removes venue as a source of stylistic variation, and
abstracts within one journal run to a similar length, which matters because
`mean_sentence_length` and `conj_rate` are noisy on short documents. Each
dataset is the **complete** query result rather than a sample, so both are
exactly reproducible from the filter recorded in their `filter` attribute.

Topic, journal and both dates are put as arguments here:

```r
fetch_corpus("lidar", from = "2008-01-01", to = "2022-12-31")
fetch_corpus("hyperspectral", from = "2008-01-01", to = "2022-12-31")
fetch_corpus("lidar", source = NULL, publisher = "P4310319808")  # all of IEEE
```

Results are cached under `tools::R_user_dir()`. Re-run
`data-raw/fetch_lidar_corpus.R` to rebuild the bundled datasets.

**Why OpenAlex and not IEEE Xplore.** IEEE Xplore's terms prohibit systematic
downloading, and violating them can terminate e-resource access for an entire
institution. OpenAlex is an open index of scholarly works released under CC0,
with no paywall or authentication, so no access agreement is involved. The
trade is that the unit of analysis is the abstract rather than the full text.

---

## Results

Holding out 80 of the 245 reference abstracts, building a profile on the
remaining 165, and scoring both the held-out pre-2023 documents and all 211
post-2023 documents:

| Method | Median, pre | Median, post | Flagged, pre | Flagged, post | Wilcoxon |
|---|---|---|---|---|---|
| Mahalanobis | 4.130 | 6.061 | 7.5% | 17.1% | p = 0.00024 |
| Angular | 0.0227 | 0.0295 | 6.2% | 18.0% | p = 0.000015 |

Both methods agree: post-2023 abstracts sit further from the pre-2023 profile,
and roughly **2.5× as many are flagged**. The features moving most are
`vocab_sophistication` (+0.055) and `prop_polysyllabic` (+0.037) — rarer, longer
words — while sentences are slightly shorter.

The contrast corpus is not labelled. It is defined by publication date, not by
authorship, so this is a shift in the distribution between two time periods and
not a measure of detection accuracy.

Cut-offs come from the reference corpus, never from the scores being judged: the
chi-squared 95% point on p degrees of freedom for Mahalanobis, and the 95th
percentile of the reference documents' own angles for the angular distance.

`summary()` on a profile also reports the covariance condition number, which on
this corpus is ~1.8×10⁵ — the features are close to collinear, and
`build_profile(shrink = 0.1)` brings it down to ~46.

---


## References

Fröhling, L., & Zubiaga, A. (2021). Feature-based detection of automated
language models: Tackling GPT-2, GPT-3 and Grover. *PeerJ Computer Science*, 7,
e443.

Mahalanobis, P. C. (1936). On the generalised distance in statistics.
*Proceedings of the National Institute of Sciences of India*, 2(1), 49–55.

Priem, J., Piwowar, H., & Orr, R. (2022). OpenAlex: A fully-open index of
scholarly works, authors, venues, institutions, and concepts. *arXiv:2205.01833*.

Salton, G., Wong, A., & Yang, C. S. (1975). A vector space model for automatic
indexing. *Communications of the ACM*, 18(11), 613–620.

van Dongen, S., & Enright, A. J. (2012). Metric distances derived from cosine
similarity and Pearson and Spearman correlations. *arXiv:1208.3145*.

---

MIT licensed.
