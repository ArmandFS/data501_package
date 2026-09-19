#angles are one of the few things that can be checked against exact values
#known in advance: a right angle is a right angle whatever the implementation.

# --- certified values ---
#
#these come from geometry, not from running the function, so they would catch
#the code being wrong from the very first commit.

test_that("matches angles worked out by hand", {
  expect_equal(angular_dist(c(1, 0), c(1, 0)),  0)      #identical
  expect_equal(angular_dist(c(1, 0), c(1, 1)),  0.25)   #45 degrees
  expect_equal(angular_dist(c(1, 0), c(0, 1)),  0.5)    #orthogonal
  expect_equal(angular_dist(c(1, 0), c(-1, 0)), 1)      #opposing
})

test_that("matches a 60 degree angle to within floating point tolerance", {
  #acos(1/2) / pi is exactly 1/3, but neither side is exact in binary
  expect_equal(angular_dist(c(1, 0), c(1, sqrt(3))), 1 / 3, tolerance = 1e-12)
})

test_that("cosine similarity matches a value computed by hand", {
  #32 / sqrt(14 * 77)
  expect_equal(cosine_sim(c(1, 2, 3), c(4, 5, 6)), 0.9746318, tolerance = 1e-7)
})

# --- identities that must hold ---

test_that("ignores the length of either vector", {
  #this is the defining property: cosine measures direction, not magnitude
  expect_equal(angular_dist(c(1, 0), c(1, 1)),
               angular_dist(c(50, 0), c(0.02, 0.02)))
})

test_that("is symmetric", {
  a <- c(2, 3, 5)
  b <- c(1, 4, 9)
  expect_equal(angular_dist(a, b), angular_dist(b, a))
})

test_that("satisfies the triangle inequality where cosine distance does not", {
  #this is the whole reason for dividing by pi rather than using 1 - cos
  a <- c(1, 0); b <- c(1, 1); cc <- c(0, 1)

  expect_true(angular_dist(a, cc) <= angular_dist(a, b) + angular_dist(b, cc))

  cos_d <- function(x, y) 1 - cosine_sim(x, y)
  expect_true(cos_d(a, cc) > cos_d(a, b) + cos_d(b, cc))
})

test_that("stays in [0, 1] and never returns NaN comparing a vector with itself", {
  #this vector's self-similarity floats to 1 + 2.2e-16, and acos() of anything
  #above 1 is NaN, so the clamp in cosine_sim() is load-bearing
  v <- c(20.13, 0.84, 0.31, 0.19, 0.55)
  expect_false(is.nan(angular_dist(v, v)))
  expect_equal(angular_dist(v, v), 0)

  set.seed(3)
  x <- matrix(stats::rnorm(60L), ncol = 3L)
  d <- angular_dist(x, c(1, 2, 3))
  expect_true(all(d >= 0 & d <= 1))
})

test_that("preserves rownames and returns one distance per row", {
  x <- matrix(1:6, nrow = 3L, dimnames = list(paste0("doc", 1:3), NULL))
  d <- angular_dist(x, c(1, 1))
  expect_length(d, 3L)
  expect_named(d, paste0("doc", 1:3))
})

# --- bad input ---

test_that("rejects a reference vector of the wrong length", {
  expect_error(angular_dist(matrix(1, nrow = 2L, ncol = 3L), c(1, 2)),
               "length 2.*3 columns")
})

test_that("rejects missing values rather than propagating NA", {
  expect_error(angular_dist(c(1, NA, 3), c(1, 2, 3)), "missing values")
  expect_error(angular_dist(c(1, 2, 3), c(1, NA, 3)), "missing values")
})

test_that("rejects a zero-length vector, whose direction is undefined", {
  expect_error(angular_dist(c(0, 0), c(1, 1)), "zero length")
  expect_error(angular_dist(c(1, 1), c(0, 0)), "zero length")
})

test_that("rejects non-numeric input", {
  expect_error(angular_dist(matrix("a", nrow = 2L, ncol = 2L), c(1, 1)),
               "numeric matrix or vector")
})
