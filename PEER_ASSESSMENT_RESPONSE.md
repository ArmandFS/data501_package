# Response to Peer Assessment — `styloprofile`

**Assessor:** Claudia Mark (300605457), `peer_review_assessment_stylo_profile.pdf`
**Assessed:** Armand Surbakti (300680133)

This document records what Claudia's peer assessment found and what was changed in response. It pairs
with `PEER_ASSESSMENT_PLAN.md`, the document she was assessing against.

## What she checked, and what needed no change

Claudia's report covers three layers: the 142 automated `testthat` tests (all passing, 0 failures/
warnings/skips; `R CMD check` at 0 errors/0 warnings/1 environmental NOTE), every manual test specified in
`PEER_ASSESSMENT_PLAN.md` §4.2 (`stylo_features()`, `cosine_sim()`, `angular_dist()`, `build_profile()`,
`score()`, `build_oa_filter()`'s existing date validation — all behaved as documented), and a set of
independent tests she designed herself targeting input validation and robustness beyond what the plan
specified.

None of the above needed any change. The numerical core (distances, feature extraction, the OO workflow)
and the validation `build_oa_filter()` already had are all confirmed correct by her testing.

## What her independent testing found, and the fix for each

All three findings were in `build_oa_filter()` (`R/corpus.R`), the function that assembles the OpenAlex
query filter and which `fetch_corpus()` calls before making any network request.

### 1. `has_abstract` silently accepted non-logical values

**Finding (slide 11):** `has_abstract` is supposed to be restricted to `TRUE`/`FALSE`, but the filter was
built with `if (isTRUE(has_abstract)) "has_abstract:true"`. Passing `has_abstract = "yes"` is not `TRUE`,
so instead of erroring, the `has_abstract:true` clause just disappeared from the query — meaning the
search could silently start returning papers with no abstract at all.

**Fix:** `build_oa_filter()` now validates `has_abstract` is a single, non-`NA` logical before building
anything, and stops with `` `has_abstract` must be TRUE or FALSE. `` otherwise. `TRUE`/`FALSE` are
unaffected — `has_abstract = FALSE` still correctly omits the clause.

```r
> build_oa_filter("lidar", "2008-01-01", "2022-12-31", has_abstract = "yes")
Error: `has_abstract` must be TRUE or FALSE.
```

### 2. `source` (and `publisher`) accepted anything

**Finding (slide 12):** `source` should be a valid OpenAlex source ID such as `"S117727964"`, but nothing
checked its shape. Passing `source = 123` was accepted by `build_oa_filter()`, built into a filter string,
and only `fetch_corpus()` sending that filter to the OpenAlex API surfaced the problem — as a bare
`400 Bad Request` network error, with no indication from the package itself that `source` was the cause.

**Fix:** `source` (and, for the same reason, `publisher`, which has the identical `"P" + digits` shape and
the identical gap) are now validated against their OpenAlex ID pattern — `^S[0-9]+$` and `^P[0-9]+$`
respectively — before the filter is built, so the request is never sent in the first place.

```r
> build_oa_filter("machine learning", "2020-01-01", "2020-12-31", source = 123)
Error: `source` must be a valid OpenAlex source ID, e.g. "S117727964".
```

`publisher` wasn't in her report, but it is the exact same validation gap on a structurally identical
argument, so it was fixed in the same pass rather than left as a known sibling bug.

### 3. A date window entirely in the future was accepted with no signal

**Finding (slide 13):** `build_oa_filter()` already validates that `from` precedes `to` and that both are
real `YYYY-MM-DD` dates, but never checked either against today's date. A window like
`from = "2030-01-01"` was accepted, sent to OpenAlex, and came back as a silently empty corpus — with no
indication that the date range itself, not the topic or journal, was why there were no results.

**Fix:** `build_oa_filter()` now warns (not errors — `to` alone being in the future is ordinary, e.g.
querying through the end of the current year) when `from` is later than today:

```r
> build_oa_filter("test", "2030-01-01", "2030-12-31")
Warning message:
`from` (2030-01-01) is in the future; this query is likely to return no results.
```

## Incidental fix: a new `R CMD check` NOTE

Re-running `devtools::check()` while verifying the above turned up one unrelated NOTE —
`PEER_ASSESSMENT_PLAN.md` and `peer_review_assessment_stylo_profile.pdf`, added to the repo root since
Claudia's check, were not excluded from the build and were flagged as non-standard top-level files. Added
to `.Rbuildignore` alongside the existing `LICENSE.md` entry; check is back to 0 errors, 0 warnings,
0 notes.

## Files changed

| File | Change |
|---|---|
| `R/corpus.R` | `build_oa_filter()`: validate `has_abstract` (logical), `source`/`publisher` (OpenAlex ID shape), warn on a future `from` date. Roxygen docs updated to match. |
| `man/build_oa_filter.Rd` | Regenerated via `devtools::document()`. |
| `tests/testthat/test-corpus.R` | 7 new `test_that()` blocks covering all three fixes plus regression checks that valid input (`has_abstract = FALSE`, well-formed `source`/`publisher`, a past date window) still passes with no error or warning. |
| `.Rbuildignore` | Added the two new root-level peer-review documents. |

## Verification

```r
devtools::document()   # regenerates NAMESPACE / man/*.Rd, no unexpected diffs
devtools::test()       # [ FAIL 0 | WARN 0 | SKIP 0 | PASS 154 ]  (142 existing + 12 new)
devtools::check()      # 0 errors, 0 warnings, 0 notes
```

All three of Claudia's exact reported scenarios were re-run directly against the fix and now behave as
described above.
