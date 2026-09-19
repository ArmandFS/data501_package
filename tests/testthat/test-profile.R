#the profile is what both distance methods consume, so these tests check the
#quantities it stores rather than the distances themselves.

make_feats <- function(n = 40L, p = 5L, seed = 11L) {
  set.seed(seed)
  matrix(stats::rnorm(n * p), ncol = p,
         dimnames = list(NULL, paste0("f", seq_len(p))))
}

# --- what it reports ---

test_that("reports how many documents the profile was built from", {
  expect_message(build_profile(make_feats()),
                 "Profile built from 40 documents on 5 features")
})

test_that("says so when documents are dropped for missing features", {
  #stylo_features() returns a row of NAs for a document with no tokens.
  #expect_message() consumes only the first message, so the second is
  #suppressed here to keep the test output clean.
  bad <- rbind(make_feats(), NA)
  suppressMessages(expect_message(build_profile(bad), "Dropped 1 document"))
})

test_that("stays quiet when asked to", {
  expect_silent(build_profile(make_feats(), verbose = FALSE))
})

# --- what it stores ---

test_that("the centre and scale are the column mean and standard deviation", {
  m <- make_feats()
  p <- build_profile(m, verbose = FALSE)

  expect_equal(p$center, colMeans(m))
  expect_equal(p$scale, apply(m, 2L, stats::sd))
  expect_equal(p$n, 40L)
  expect_equal(p$p, 5L)
})

test_that("the stored factor really is a Cholesky factor of the covariance", {
  m <- make_feats()
  p <- build_profile(m, verbose = FALSE)
  #R'R must reproduce the covariance it was built from
  expect_equal(t(p$chol_cov) %*% p$chol_cov, stats::cov(m), tolerance = 1e-10)
})

# --- scoring through the profile ---

test_that("scoring by mahalanobis agrees with base R", {
  m <- make_feats()
  p <- build_profile(m, verbose = FALSE)
  expect_equal(
    score(m, p, "mahalanobis"),
    stats::mahalanobis(m, colMeans(m), stats::cov(m)),
    tolerance = 1e-8,
    ignore_attr = TRUE
  )
})

test_that("a document at the centre is at distance zero by either method", {
  m <- make_feats()
  p <- build_profile(m, verbose = FALSE)

  #score() returns a classed object now, so compare the values only
  expect_equal(unname(score(p$center, p, "mahalanobis")), 0, ignore_attr = TRUE)
  #acos() loses about half its precision near an angle of zero, so this one
  #can only be checked approximately
  expect_equal(unname(score(p$center, p, "angular")), 0,
               tolerance = 1e-6, ignore_attr = TRUE)
})

test_that("angular scores stay in [0, 1]", {
  m <- make_feats()
  p <- build_profile(m, verbose = FALSE)
  d <- score(m, p, "angular")
  expect_true(all(d >= 0 & d <= 1))
})

# --- bad input ---

test_that("rejects an unknown scoring method", {
  p <- build_profile(make_feats(), verbose = FALSE)
  expect_error(score(make_feats(), p, "euclidean"), "should be one of")
})

test_that("rejects something that is not a profile", {
  expect_error(score(make_feats(), list(center = 1), "mahalanobis"),
               "must be a stylo_profile")
})

test_that("rejects a corpus with fewer documents than features", {
  expect_error(build_profile(make_feats(n = 4L, p = 5L), verbose = FALSE),
               "more documents")
})

test_that("rejects a feature with no variance, which cannot be standardised", {
  m <- make_feats()
  m[, 2L] <- 7
  expect_error(build_profile(m, verbose = FALSE), "zero variance")
})

test_that("rejects a document with the wrong number of features", {
  p <- build_profile(make_feats(), verbose = FALSE)
  expect_error(score(make_feats(p = 3L), p, "mahalanobis"),
               "3 columns but the profile was built on 5")
})

# --- the S3 classes ---
#
#the package is meant to hand back objects with methods, not bare vectors,
#so the class and its methods are part of the contract.

test_that("build_profile() returns a classed object, not a bare list", {
  p <- build_profile(make_feats(), verbose = FALSE)
  expect_s3_class(p, "stylo_profile")
})

test_that("score() returns a classed object that still behaves as a number", {
  p <- build_profile(make_feats(), verbose = FALSE)
  d <- score(make_feats(), p, "angular")

  expect_s3_class(d, "stylo_score")
  expect_equal(attr(d, "method"), "angular")
  #arithmetic must still work, or the class would be a nuisance
  expect_true(all(d >= 0 & d <= 1))
  expect_length(d, 40L)
})

test_that("summary() of a profile reports the per-feature statistics", {
  p <- build_profile(make_feats(), verbose = FALSE)
  s <- summary(p)

  expect_s3_class(s, "summary.stylo_profile")
  expect_equal(s$n, 40L)
  expect_equal(rownames(s$stats), p$features)
  expect_equal(s$stats$mean, as.vector(p$center))
  #a well conditioned covariance from independent columns
  expect_true(s$condition > 1)
})

test_that("summary() of scores counts what lies beyond the cut-off", {
  p <- build_profile(make_feats(), verbose = FALSE)
  s <- summary(score(make_feats(), p, "mahalanobis"))

  expect_s3_class(s, "summary.stylo_score")
  #the squared Mahalanobis distance is chi-squared on p df under normality
  expect_equal(s$cutoff, stats::qchisq(0.95, df = 5L))
  expect_true(s$n_flagged >= 0 && s$n_flagged <= s$n)
  expect_true(s$principled)
})

test_that("the angular cut-off comes from the reference corpus, not the scores", {
  #there is no chi-squared reference distribution for an angle, so the profile
  #records where its own documents sit. Reading a cut-off off the scores being
  #judged would force the flagged share to 5% whatever the input.
  p <- build_profile(make_feats(), verbose = FALSE)
  s <- summary(score(make_feats(n = 60L, seed = 99L), p, "angular"))

  expect_false(s$principled)
  expect_equal(s$cutoff, p$angular_ref)
})

test_that("the print methods run and return their input invisibly", {
  p <- build_profile(make_feats(), verbose = FALSE)
  d <- score(make_feats(), p, "mahalanobis")

  expect_output(print(p), "stylo_profile")
  expect_output(print(summary(p)), "Reference profile")
  expect_output(print(d), "scored by mahalanobis distance")
  expect_output(print(summary(d)), "Flagged above")

  invisible(capture.output(vis <- withVisible(print(p))$visible))
  expect_false(vis)
})
