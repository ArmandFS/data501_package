#' Validate the inputs shared by the angular functions
#'
#' Mirrors the checks in [mahalanobis_sq()] so the two distance methods reject
#' the same mistakes with the same wording.
#'
#' @param x Numeric matrix or vector.
#' @param y Numeric vector.
#' @return `x` as a numeric matrix.
#' @noRd
.check_angular_input <- function(x, y) {
  if (is.vector(x) && !is.list(x)) {
    x <- matrix(x, nrow = 1L, dimnames = list(NULL, names(x)))
  }
  if (!is.matrix(x) || !is.numeric(x)) {
    stop("`x` must be a numeric matrix or vector.", call. = FALSE)
  }
  if (!is.numeric(y) || !is.null(dim(y))) {
    stop("`y` must be a numeric vector.", call. = FALSE)
  }
  if (length(y) != ncol(x)) {
    stop(sprintf(
      "`y` has length %d but `x` has %d columns.", length(y), ncol(x)
    ), call. = FALSE)
  }
  if (anyNA(x) || anyNA(y)) {
    stop("`x` and `y` must not contain missing values.", call. = FALSE)
  }
  x
}

#' Cosine similarity between each row of `x` and a reference vector
#'
#' The cosine of the angle between two feature vectors: 1 when they point the
#' same way, 0 when they are orthogonal, -1 when they oppose. Because it depends
#' only on direction, it ignores how large the vectors are.
#'
#' @param x Numeric matrix with one row per observation and one column per
#'   feature, or a numeric vector treated as a single observation.
#' @param y Numeric vector of length `ncol(x)`, the reference direction.
#'
#' @return Numeric vector in `[-1, 1]`, one value per row of `x`, named with the
#'   rownames of `x` when it has any.
#'
#' @examples
#' # 32 / sqrt(14 * 77)
#' cosine_sim(c(1, 2, 3), c(4, 5, 6))
#'
#' # a right angle, whatever the lengths
#' cosine_sim(c(1, 0), c(0, 5))
#'
#' @references
#' Salton, G., Wong, A., & Yang, C. S. (1975). A vector space model for
#' automatic indexing. \emph{Communications of the ACM}, 18(11), 613--620.
#' \doi{10.1145/361219.361220}
#'
#' @seealso [angular_dist()]
#' @export
cosine_sim <- function(x, y) {
  x <- .check_angular_input(x, y)

  nx <- sqrt(rowSums(x * x))
  ny <- sqrt(sum(y * y))

  #a zero vector has no direction, so the angle is undefined. Erroring matches
  #how mahalanobis_sq() treats a singular Cholesky factor.
  if (ny < .Machine$double.eps) {
    stop("`y` has zero length; the angle is undefined.", call. = FALSE)
  }
  zero <- nx < .Machine$double.eps
  if (any(zero)) {
    stop(sprintf(
      "row(s) %s of `x` have zero length; the angle is undefined.",
      paste(which(zero), collapse = ", ")
    ), call. = FALSE)
  }

  cs <- as.vector(x %*% y) / (nx * ny)

  #comparing a vector with itself can float to 1 + 2.2e-16, and acos() of
  #anything above 1 is NaN
  cs <- pmin(pmax(cs, -1), 1)

  names(cs) <- rownames(x)
  cs
}

#' Angular distance between each row of `x` and a reference vector
#'
#' The angle between two feature vectors, rescaled to `[0, 1]`: 0 when they
#' point the same way, 0.5 when they are orthogonal, 1 when they oppose.
#'
#' @details
#' Dividing the angle by `pi` rather than reporting `1 - cos(theta)` is
#' deliberate. `acos(cos_sim) / pi` satisfies the triangle inequality and is
#' therefore a true metric, whereas cosine distance is not. With
#' `a = (1, 0)`, `b = (1, 1)` and `c = (0, 1)`, cosine distance gives
#' `d(a, c) = 1` against `d(a, b) + d(b, c) = 0.586`, a violation; the angular
#' distance gives `0.5` against `0.5`, which holds.
#'
#' Cosine-based measures ignore vector length, so raw stylometric features --
#' which sit on very different scales -- must be divided by the reference
#' standard deviations before the angle means anything. Note that subtracting
#' the reference mean as well would move the reference to the origin and leave
#' the angle undefined, so [build_profile()] standardises by scale only. The
#' result measures mismatch in the *shape* of a document's feature profile,
#' which is what makes it complementary to [mahalanobis_sq()] rather than a
#' restatement of it.
#'
#' @param x Numeric matrix with one row per observation and one column per
#'   feature, or a numeric vector treated as a single observation.
#' @param y Numeric vector of length `ncol(x)`, the reference direction.
#'
#' @return Numeric vector in `[0, 1]`, one value per row of `x`, named with the
#'   rownames of `x` when it has any.
#'
#' @examples
#' angular_dist(c(1, 0), c(1, 0))   # identical directions -> 0
#' angular_dist(c(1, 0), c(1, 1))   # 45 degrees           -> 0.25
#' angular_dist(c(1, 0), c(0, 1))   # orthogonal           -> 0.5
#' angular_dist(c(1, 0), c(-1, 0))  # opposing             -> 1
#'
#' @references
#' van Dongen, S., & Enright, A. J. (2012). Metric distances derived from
#' cosine similarity and Pearson and Spearman correlations.
#' \emph{arXiv:1208.3145}. \doi{10.48550/arXiv.1208.3145}
#'
#' @seealso [cosine_sim()], [mahalanobis_sq()]
#' @export
angular_dist <- function(x, y) {
  acos(cosine_sim(x, y)) / pi
}
