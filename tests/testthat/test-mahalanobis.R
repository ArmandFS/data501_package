# Tests for mahalanobis_sq().
#
# This function is worth testing because its correct answer is knowable
# independently of how it is implemented, in three separate ways: base R ships
# a completely separate implementation to compare against, the distance obeys
# mathematical identities that must hold for any correct version, and several
# arguments have shapes that are simply invalid. None of that depends on a
# corpus, so the tests are fast and deterministic.

make_case <- function(n = 50L, p = 3L, seed = 42L) {
  set.seed(seed)
  x <- matrix(stats::rnorm(n * p), ncol = p)
  list(x = x, center = colMeans(x), S = stats::cov(x))
}

# --- Oracle: agreement with a separate implementation -----------------------

test_that("agrees with stats::mahalanobis() across dimensions", {
  for (p in c(1L, 2L, 5L, 10L)) {
    cs <- make_case(n = 60L, p = p, seed = 100L + p)
    expect_equal(
      mahalanobis_sq(cs$x, cs$center, chol(cs$S)),
      stats::mahalanobis(cs$x, cs$center, cs$S),
      tolerance = 1e-8,
      ignore_attr = TRUE
    )
  }
})

test_that("handles a single observation passed as a bare vector", {
  cs <- make_case()
  expect_equal(
    unname(mahalanobis_sq(cs$x[1, ], cs$center, chol(cs$S))),
    unname(stats::mahalanobis(cs$x[1, , drop = FALSE], cs$center, cs$S)),
    tolerance = 1e-8
  )
})

# --- Mathematical invariants ------------------------------------------------

test_that("reduces to squared Euclidean distance when the covariance is I", {
  cs <- make_case()
  expect_equal(
    mahalanobis_sq(cs$x, rep(0, ncol(cs$x)), diag(ncol(cs$x))),
    rowSums(cs$x^2),
    tolerance = 1e-10,
    ignore_attr = TRUE
  )
})

test_that("the distance at the centre is exactly zero", {
  cs <- make_case()
  expect_equal(unname(mahalanobis_sq(cs$center, cs$center, chol(cs$S))), 0)
})

test_that("is invariant under an invertible affine map", {
  # D^2 is unchanged by x -> Ax + b when Sigma -> A Sigma A'. This is the
  # defining property of the Mahalanobis distance: it is the Euclidean distance
  # after whitening, so it cannot depend on the units the features are in.
  cs <- make_case(p = 3L)
  A <- matrix(c(2, 0.5, 0, 0, 3, 1, 0.25, 0, 4), nrow = 3)
  b <- c(10, -5, 0.5)

  before <- mahalanobis_sq(cs$x, cs$center, chol(cs$S))
  after <- mahalanobis_sq(
    t(A %*% t(cs$x) + b),
    as.vector(A %*% cs$center + b),
    chol(A %*% cs$S %*% t(A))
  )

  expect_equal(before, after, tolerance = 1e-8, ignore_attr = TRUE)
})

test_that("is non-negative for any positive definite covariance", {
  for (seed in 1:5) {
    set.seed(seed)
    p <- 4L
    B <- matrix(stats::rnorm(p * p), p)
    S <- crossprod(B) + diag(p)  # positive definite by construction
    x <- matrix(stats::rnorm(30L * p), ncol = p)
    expect_true(all(mahalanobis_sq(x, rep(0, p), chol(S)) >= 0))
  }
})

test_that("preserves rownames and returns one distance per row", {
  cs <- make_case(n = 7L)
  rownames(cs$x) <- paste0("doc", 1:7)
  d <- mahalanobis_sq(cs$x, cs$center, chol(cs$S))
  expect_length(d, 7L)
  expect_named(d, paste0("doc", 1:7))
})

# --- Invalid input ----------------------------------------------------------

test_that("rejects a centre of the wrong length", {
  cs <- make_case(p = 3L)
  expect_error(
    mahalanobis_sq(cs$x, cs$center[1:2], chol(cs$S)),
    "length 2.*3 columns"
  )
})

test_that("rejects a non-square Cholesky factor", {
  cs <- make_case(p = 3L)
  expect_error(
    mahalanobis_sq(cs$x, cs$center, matrix(1, nrow = 3, ncol = 2)),
    "must be square"
  )
})

test_that("rejects a Cholesky factor of the wrong dimension", {
  cs <- make_case(p = 3L)
  expect_error(
    mahalanobis_sq(cs$x, cs$center, diag(4)),
    "4 x 4.*3 columns"
  )
})

test_that("rejects missing values rather than propagating NA", {
  cs <- make_case(p = 3L)
  R <- chol(cs$S)
  bad <- cs$x
  bad[1, 1] <- NA_real_

  expect_error(mahalanobis_sq(bad, cs$center, R), "missing values")
  expect_error(mahalanobis_sq(cs$x, replace(cs$center, 1, NA), R), "missing values")
})

test_that("rejects a singular Cholesky factor", {
  cs <- make_case(p = 3L)
  singular <- chol(cs$S)
  singular[3, 3] <- 0
  expect_error(mahalanobis_sq(cs$x, cs$center, singular), "singular")
})

test_that("rejects non-numeric input", {
  cs <- make_case(p = 3L)
  expect_error(
    mahalanobis_sq(matrix("a", 2, 3), cs$center, chol(cs$S)),
    "numeric matrix or vector"
  )
})
