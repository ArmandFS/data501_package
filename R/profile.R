#' Build a reference profile from a corpus
#'
#' Summarises a corpus of human-authored documents into the quantities both
#' distance methods need: a centre, a per-feature scale, and a Cholesky factor
#' of the covariance. Factorising once here is what lets [mahalanobis_sq()]
#' score any number of later documents without re-factorising.
#'
#' @details
#' A high score against a profile means a document is unusual *relative to the
#' corpus the profile was built from*. It is not evidence that the document was
#' machine-generated, and the choice of reference corpus encodes whatever biases
#' that corpus carries.
#'
#' @param x Either a character vector of documents, which is passed through
#'   [stylo_features()], or a numeric feature matrix with one row per document.
#' @param shrink Numeric in `[0, 1)`. Shrinks the sample covariance toward a
#'   scaled identity before factorising, which keeps the factor well conditioned
#'   when the features are strongly correlated. `0` leaves the covariance alone.
#' @param verbose Logical. Report how many documents the profile was built from,
#'   and how many were dropped for missing features.
#'
#' @return An object of class `stylo_profile`: a list with elements `center`,
#'   `scale`, `chol_cov`, `angular_ref`, `n`, `p`, `features` and `call`.
#'
#' @examples
#' set.seed(1)
#' m <- matrix(rnorm(200), ncol = 4,
#'             dimnames = list(NULL, paste0("f", 1:4)))
#' p <- build_profile(m)
#' p
#'
#' @seealso [score()], [mahalanobis_sq()], [angular_dist()]
#' @export
build_profile <- function(x, shrink = 0, verbose = TRUE) {
  if (is.character(x)) {
    x <- stylo_features(x)
  }
  if (!is.matrix(x) || !is.numeric(x)) {
    stop("`x` must be a character vector of documents or a numeric matrix.",
         call. = FALSE)
  }
  if (!is.numeric(shrink) || length(shrink) != 1L ||
      is.na(shrink) || shrink < 0 || shrink >= 1) {
    stop("`shrink` must be a single number in [0, 1).", call. = FALSE)
  }

  #stylo_features() returns a row of NAs for a document with no tokens, and a
  #single NA would propagate through the whole covariance
  keep <- stats::complete.cases(x)
  dropped <- sum(!keep)
  if (dropped > 0L) {
    x <- x[keep, , drop = FALSE]
    if (verbose) {
      message(sprintf("Dropped %d document(s) with missing features.", dropped))
    }
  }

  n <- nrow(x)
  p <- ncol(x)
  if (n <= p) {
    stop(sprintf(
      "need more documents (%d) than features (%d) to estimate a covariance.",
      n, p
    ), call. = FALSE)
  }

  center <- colMeans(x)
  scale <- apply(x, 2L, stats::sd)

  flat <- scale < .Machine$double.eps
  if (any(flat)) {
    stop(sprintf(
      "feature(s) %s have zero variance; they cannot be standardised.",
      paste(colnames(x)[flat], collapse = ", ")
    ), call. = FALSE)
  }

  S <- stats::cov(x)
  if (shrink > 0) {
    S <- (1 - shrink) * S + shrink * mean(diag(S)) * diag(p)
  }

  #the angle has no reference distribution the way the squared Mahalanobis
  #distance has chi-squared, so record where the reference documents
  #themselves sit. Without this a cut-off would have to be read off the very
  #scores being judged, which is circular.
  z <- sweep(x, 2L, scale, "/")
  angular_ref <- stats::quantile(
    as.numeric(angular_dist(z, center / scale)), 0.95, names = FALSE
  )

  out <- list(
    center = center,
    scale = scale,
    chol_cov = chol(S),
    angular_ref = angular_ref,
    n = n,
    p = p,
    features = colnames(x),
    call = match.call()
  )
  class(out) <- "stylo_profile"

  if (verbose) {
    message(sprintf("Profile built from %d documents on %d features.", n, p))
  }
  out
}

#' @param ... Ignored.
#' @rdname build_profile
#' @export
print.stylo_profile <- function(x, ...) {
  cat("<stylo_profile>\n")
  cat(sprintf("  %d documents, %d features\n", x$n, x$p))
  cat("\n")
  print(round(rbind(center = x$center, scale = x$scale), 4L))
  invisible(x)
}

#' @param object A `stylo_profile`.
#' @rdname build_profile
#' @export
summary.stylo_profile <- function(object, ...) {
  #kappa() estimates the condition number of the factor; the covariance it
  #came from is the square of that. A large value is the warning sign that
  #the features are close to collinear and the distances are dominated by
  #estimation noise in the smallest eigenvalue.
  cond <- kappa(object$chol_cov, exact = TRUE)^2

  out <- list(
    n = object$n,
    p = object$p,
    features = object$features,
    stats = data.frame(
      mean = as.vector(object$center),
      sd = as.vector(object$scale),
      row.names = object$features
    ),
    condition = cond,
    call = object$call
  )
  class(out) <- "summary.stylo_profile"
  out
}

#' @rdname build_profile
#' @export
print.summary.stylo_profile <- function(x, ...) {
  cat("Reference profile\n\n")
  cat(sprintf("Documents: %d\nFeatures:  %d\n\n", x$n, x$p))
  print(round(x$stats, 4L))
  cat(sprintf("\nCovariance condition number: %.1f\n", x$condition))
  if (x$condition > 1000) {
    cat("The features are close to collinear; consider build_profile(shrink=).\n")
  }
  invisible(x)
}
