#' Squared Mahalanobis distance via a Cholesky factor
#'
#' Computes the squared Mahalanobis distance
#' \eqn{D^2(x) = (x - \mu)^\top \Sigma^{-1} (x - \mu)} for each row of `x`,
#' given the centre \eqn{\mu} and the upper-triangular Cholesky factor
#' \eqn{R} of \eqn{\Sigma}, where \eqn{\Sigma = R^\top R} (Mahalanobis, 1936).
#'
#' @section Why the Cholesky factor:
#' The textbook formulation inverts the covariance matrix. That is both slower
#' and less numerically stable than solving the triangular system directly:
#' writing \eqn{z = R^{-\top}(x - \mu)} gives \eqn{D^2 = z^\top z}, which needs
#' only a back-substitution. Factorising once costs \eqn{O(p^3)} and is then
#' reused across every document at \eqn{O(p^2)} each, and the condition number
#' of the triangular solve is the square root of that of the explicit inverse.
#' Passing the factor in, rather than the covariance, means a
#' [stylo_profile][build_profile] factorises its covariance once at
#' construction time and never again.
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
#' @references
#' Mahalanobis, P. C. (1936). On the generalised distance in statistics.
#' \emph{Proceedings of the National Institute of Sciences of India}, 2(1), 49--55.
#'
#' @examples
#' set.seed(1)
#' m <- matrix(rnorm(200), ncol = 2)
#' R <- chol(cov(m))
#' d <- mahalanobis_sq(m, colMeans(m), R)
#'
#' # Agrees with the base R implementation.
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

  # Centre each observation, then solve R^T z = (x - mu) by forward
  # substitution. Columns of `centred` are observations, so one triangular
  # solve handles the whole matrix at once.
  centred <- t(x) - center
  z <- backsolve(chol_cov, centred, transpose = TRUE)

  d2 <- colSums(z * z)

  # Round-off can push a distance of exactly zero to a tiny negative number.
  d2[d2 < 0] <- 0

  names(d2) <- rownames(x)
  d2
}
