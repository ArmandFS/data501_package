#' Squared Mahalanobis distance via a Cholesky factor
#'
#' Computes the squared Mahalanobis distance for each row of `x`. Takes the
#' Cholesky factor rather than the covariance so that a reference profile can
#' factorise once and reuse it for every call.
#'
#' @param x Numeric matrix with one row per observation and one column per
#'   feature, or a numeric vector treated as a single observation.
#' @param center Numeric vector of length `ncol(x)`, the reference mean.
#' @param chol_cov Upper-triangular `p x p` Cholesky factor of the covariance,
#'   as returned by [chol()].
#'
#' @return Numeric vector of squared distances, one per row of `x`, named with
#'   the rownames of `x` when it has any.
#'
#' @examples
#' set.seed(1)
#' m <- matrix(rnorm(200), ncol = 2)
#' R <- chol(cov(m))
#' d <- mahalanobis_sq(m, colMeans(m), R)
#'
#' # same answer as base R
#' all.equal(d, mahalanobis(m, colMeans(m), cov(m)), check.attributes = FALSE)
#'
#' @export
mahalanobis_sq <- function(x, center, chol_cov) {
  if (is.vector(x) && !is.list(x)) {
    x <- matrix(x, nrow = 1L, dimnames = list(NULL, names(x)))
  }
  if (!is.matrix(x) || !is.numeric(x)) {
    stop("`x` must be a numeric matrix or vector.", call. = FALSE)
  }
  if (!is.numeric(center)) {
    stop("`center` must be numeric.", call. = FALSE)
  }
  if (!is.matrix(chol_cov) || !is.numeric(chol_cov)) {
    stop("`chol_cov` must be a numeric matrix.", call. = FALSE)
  }

  p <- ncol(x)
  if (length(center) != p) {
    stop(sprintf(
      "`center` has length %d but `x` has %d columns.", length(center), p
    ), call. = FALSE)
  }
  if (nrow(chol_cov) != ncol(chol_cov)) {
    stop("`chol_cov` must be square.", call. = FALSE)
  }
  if (nrow(chol_cov) != p) {
    stop(sprintf(
      "`chol_cov` is %d x %d but `x` has %d columns.",
      nrow(chol_cov), ncol(chol_cov), p
    ), call. = FALSE)
  }
  if (anyNA(x) || anyNA(center) || anyNA(chol_cov)) {
    stop("`x`, `center` and `chol_cov` must not contain missing values.",
         call. = FALSE)
  }
  if (any(abs(diag(chol_cov)) < .Machine$double.eps)) {
    stop("`chol_cov` is singular; the covariance is not positive definite.",
         call. = FALSE)
  }

  #solve R^T z = (x - mu) instead of inverting. Observations are columns
  #here so one call handles the whole matrix.
  centred <- t(x) - center
  z <- backsolve(chol_cov, centred, transpose = TRUE)

  d2 <- colSums(z * z)

  #rounding can push an exact zero slightly negative
  d2[d2 < 0] <- 0

  names(d2) <- rownames(x)
  d2
}
