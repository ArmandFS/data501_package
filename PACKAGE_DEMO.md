# Package Demo — `styloprofile`

**Armand Surbakti — 300680133**
**Repository:** <https://github.com/ArmandFS/data501_package>

This is a live walkthrough of `styloprofile`, built to be run top to bottom in a fresh R session. It
covers the package workflow, installation, the automated test suite, manual function-by-function checks
(including deliberately trying to break three functions), the plot methods, and the headline result. It's
written to double as a presentation script and as a self-contained verification guide for anyone checking
the package by hand.

---

## 1. Package workflow

`styloprofile` measures how far a document sits from a statistical profile of human writing, rather than
training a human-vs-AI classifier:

```
Text Documents -> Extract Writing-Style Features -> Build Reference Profile -> Score New Documents
```

1. **Text documents** — research abstracts or any other written documents.
2. **Extract writing-style features** — `stylo_features()` converts each document into 5 numerical
   features: sentence length, conjunction use, variation in word length, syllable complexity, vocabulary
   sophistication.
3. **Build a reference profile** — `build_profile()` summarises a collection of documents into a
   `stylo_profile`.
4. **Score new documents** — `score()` reports how far each document sits from that profile, by two
   complementary distances: **Mahalanobis** (how unusual a document is overall) and **angular** (how
   wrong the *proportions* between its features are).

A high score means a document is unusual *relative to the reference corpus*. It is not evidence that a
document was machine-generated.

---

## 2. Installation

```r
# install.packages("remotes")
remotes::install_github("ArmandFS/data501_package")
library(styloprofile)
```

The repository is `data501_package`; the package it installs is `styloprofile`. It compiles C++ via
Rcpp, so a working toolchain is needed: Xcode command line tools on macOS, Rtools on Windows.

---

## 3. Automated testing

```r
devtools::test()
#> [ FAIL 0 | WARN 0 | SKIP 0 | PASS 174 ]
```

| File | Blocks | Expectations | Covers |
|---|---|---|---|
| `test-angular.R` | 12 | 21 | `cosine_sim()`, `angular_dist()` |
| `test-corpus.R` | 27 | 47 | corpus query, parsing, bundled data, the three fixes in §5.5 below |
| `test-features.R` | 14 | 20 | `stylo_features()` |
| `test-mahalanobis.R` | 13 | 22 | `mahalanobis_sq()` |
| `test-profile.R` | 19 | 38 | `build_profile()`, `score()`, S3 methods |
| `test-syllables.R` | 13 | 26 | `count_syllables_cpp()` / `_r()` |

```r
devtools::check()
#> 0 errors | 0 warnings | 0 notes
```

---

## 4. Manual testing, function by function

Everything below uses the corpus bundled with the package (`lidar_reference`, `lidar_contrast`), so none
of it needs network access.

### `stylo_features()`

```r
stylo_features(c("This is a simple test sentence.", ""))
#>      mean_sentence_length conj_rate cv_word_length prop_polysyllabic
#> [1,]                    6         0      0.6150122                 0
#> [2,]                   NA        NA             NA                NA
#>      vocab_sophistication
#> [1,]                  0.5
#> [2,]                   NA
```

An empty document (no word tokens) returns a row of `NA` rather than erroring or dividing by zero.

### `cosine_sim()` / `angular_dist()` — certified angles

```r
angular_dist(c(1, 0), c(1, 1))   # 45 degrees
#> [1] 0.25
angular_dist(c(1, 0), c(0, 1))   # 90 degrees
#> [1] 0.5
```

### `mahalanobis_sq()` — agrees with base R's own implementation

```r
set.seed(1)
m <- matrix(rnorm(200), ncol = 4)
mu <- colMeans(m); R <- chol(cov(m))
all.equal(mahalanobis_sq(m, mu, R), stats::mahalanobis(m, mu, cov(m)), check.attributes = FALSE)
#> [1] TRUE
```

### `count_syllables_cpp()` vs `count_syllables_r()` — the compiled version against its R oracle

```r
count_syllables_cpp(c("cat", "table", "beautiful"))
#> [1] 1 2 3
count_syllables_r(c("cat", "table", "beautiful"))
#> [1] 1 2 3
```

### `build_profile()` + `print()` / `summary()`

```r
profile <- build_profile(lidar_reference$abstract)
#> Profile built from 245 documents on 5 features.
profile
#> <stylo_profile>
#>   245 documents, 5 features
#>
#>        mean_sentence_length conj_rate cv_word_length prop_polysyllabic
#> center              25.6192    1.7895         0.5432            0.2675
#> scale               11.1352    0.7722         0.0296            0.0438
#>        vocab_sophistication
#> center               0.5763
#> scale                0.0410

summary(profile)
#> Reference profile
#>
#> Documents: 245
#> Features:  5
#>
#>                         mean      sd
#> mean_sentence_length 25.6192 11.1352
#> conj_rate             1.7895  0.7722
#> cv_word_length        0.5432  0.0296
#> prop_polysyllabic     0.2675  0.0438
#> vocab_sophistication  0.5763  0.0410
#>
#> Covariance condition number: 179871.6
#> The features are close to collinear; consider build_profile(shrink=).
```

### `score()` — both distance methods

```r
s_maha <- score(lidar_contrast$abstract, profile, "mahalanobis")
summary(s_maha)
#> Scores for 211 document(s), mahalanobis distance
#> Reference profile: 245 documents, 5 features
#>
#>      0%     25%     50%     75%    100%
#>  0.4965  3.0095  5.5194  7.8416 36.6638
#>
#> Mean: 6.3495
#>
#> Flagged above 11.0705 (chi-squared(5) 95%): 28 of 211 (13.3%)
#>
#> A flagged document is unusual relative to the reference corpus.
#> It is not evidence that the document was machine-generated.

s_ang <- score(lidar_contrast$abstract, profile, "angular")
summary(s_ang)
#> Flagged above 0.0389 (95th percentile of the reference corpus): 42 of 211 (19.9%)
```

### `read_corpus_json()` — parses an OpenAlex response, fully offline

```r
f <- system.file("extdata", "openalex_sample.json", package = "styloprofile")
read_corpus_json(f)
#> Parsed 3 records; dropped 2 (no abstract, or under 40 words).
#>   [one usable record returned, the other two dropped: one had no abstract,
#>    one was too short for sentence-level features to mean anything]
```

### 4.5. Try to break it — the three bugs peer review found, now fixed

These three were found by Claudia Mark's independent peer-review testing
(`peer_review_assessment_stylo_profile.pdf`), written up in `PEER_ASSESSMENT_RESPONSE.md`. All three are
in `build_oa_filter()`, which `fetch_corpus()` always calls first, so none of these ever reach a network
request.

```r
build_oa_filter("lidar", "2008-01-01", "2022-12-31", has_abstract = "yes")
#> Error: `has_abstract` must be TRUE or FALSE.

build_oa_filter("machine learning", "2020-01-01", "2020-12-31", source = 123)
#> Error: `source` must be a valid OpenAlex source ID, e.g. "S117727964".

build_oa_filter("test", "2030-01-01", "2030-12-31")
#> Warning message:
#> `from` (2030-01-01) is in the future; this query is likely to return no results.
```

---

## 5. Plots

```r
plot(profile)
```

Draws the `center`/`scale` table as one small panel per feature — a point at the reference mean with
whiskers at one reference standard deviation. One panel per feature because the five features differ too
much in scale to share an axis (`mean_sentence_length` is in the tens; `vocab_sophistication` is a
proportion).

```r
plot(s_maha)
```

Draws a histogram of the scores with a dashed vertical line at the same 95% flagging cut-off
`summary()` reports, so the picture and the printed summary always agree.

For the full walkthrough with both plots inline, see:

```r
vignette("styloprofile", package = "styloprofile")
```

---

## 6. Results

Holding out 80 of the 245 reference abstracts, building a profile on the remaining 165, and scoring both
the held-out pre-2023 documents and all 211 post-2023 documents:

| Method | Median, pre | Median, post | Flagged, pre | Flagged, post | Wilcoxon |
|---|---|---|---|---|---|
| Mahalanobis | 4.130 | 6.061 | 7.5% | 17.1% | p = 0.00024 |
| Angular | 0.0227 | 0.0295 | 6.2% | 18.0% | p = 0.000015 |

Both methods agree: post-2023 abstracts sit further from the pre-2023 profile, and roughly **2.5× as many
are flagged**. The contrast corpus is split by publication date, not by authorship, so this is a
distributional-shift finding, not a measure of detection accuracy.

---

## 7. Known limitations

- The spell-check feature from the original design proposal (a 6th feature, needs the `hunspell`
  package and a system dictionary) stays deferred, to keep the dependency list at `Rcpp`, `stats`,
  `graphics`, `jsonlite`, `tools` and `utils`.
- Two of the five features, `vocab_sophistication` and `mean_sentence_length`, correlate with English
  proficiency and education — a fairness caveat carried through from the design proposal. A flagged
  document is a statistical outlier relative to its reference corpus, and nothing more.

Everything else named as a gap in `PEER_ASSESSMENT_PLAN.md`'s "Known limitations" section — `plot()`
methods, a vignette, a dedicated test file for `stylo_features()` — is closed as of this document.
