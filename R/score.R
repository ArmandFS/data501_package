#' Score documents against a reference profile
#'
#' One entry point for both distance methods, so switching between them is a
#' change of argument rather than a change of call.
#'
#' @details
#' The two methods answer different questions. `"mahalanobis"` measures how far
#' a document sits from the centre once the spread and correlation of the
#' features are accounted for, so it responds to a document being extreme.
#' `"angular"` divides each feature by its reference standard deviation and then
#' measures the angle to the reference direction, so it responds to the
#' *proportions* between features being wrong even when nothing is extreme.
#'
#' Scaling but not centring is deliberate: subtracting the centre would place
#' the reference at the origin, where a direction, and so an angle, does not
#' exist. See [angular_dist()].
#'
#' @param x Either a character vector of documents, which is passed through
#'   [stylo_features()], or a numeric feature matrix with one row per document.
#'   A bare numeric vector is treated as a single document.
#' @param profile A `stylo_profile` from [build_profile()].
#' @param method Either `"mahalanobis"` (squared Mahalanobis distance) or
#'   `"angular"` (angular distance in `[0, 1]`).
#'
#' @return Numeric vector of distances, one per document.
#'
#' @examples
#' set.seed(1)
#' m <- matrix(rnorm(200), ncol = 4)
#' p <- build_profile(m, verbose = FALSE)
#'
#' score(m[1:3, ], p, "mahalanobis")
#' score(m[1:3, ], p, "angular")
#'
#' @seealso [build_profile()], [mahalanobis_sq()], [angular_dist()]
#' @export
score <- function(x, profile, method = c("mahalanobis", "angular")) {
  method <- match.arg(method)

  if (!inherits(profile, "stylo_profile")) {
    stop("`profile` must be a stylo_profile from build_profile().",
         call. = FALSE)
  }
  if (is.character(x)) {
    x <- stylo_features(x)
  }
  if (is.vector(x) && !is.list(x)) {
    x <- matrix(x, nrow = 1L, dimnames = list(NULL, names(x)))
  }
  if (!is.matrix(x) || !is.numeric(x)) {
    stop("`x` must be a character vector of documents, a numeric matrix, ",
         "or a numeric vector.", call. = FALSE)
  }
  if (ncol(x) != profile$p) {
    stop(sprintf(
      "`x` has %d columns but the profile was built on %d features.",
      ncol(x), profile$p
    ), call. = FALSE)
  }

  d <- switch(method,
    mahalanobis = mahalanobis_sq(x, profile$center, profile$chol_cov),
    angular = angular_dist(
      sweep(x, 2L, profile$scale, "/"),
      profile$center / profile$scale
    )
  )

  structure(d,
            class = "stylo_score",
            method = method,
            n_reference = profile$n,
            p = profile$p,
            angular_ref = profile$angular_ref,
            features = profile$features)
}

#' @param object A `stylo_score`, as returned by `score()`.
#' @param n Number of scores to show before truncating.
#' @param ... Ignored.
#' @rdname score
#' @export
print.stylo_score <- function(x, n = 6L, ...) {
  d <- unclass(x)
  attributes(d) <- list(names = names(x))

  cat(sprintf("%d document(s) scored by %s distance\n",
              length(d), attr(x, "method")))
  cat(sprintf("against a profile of %d reference documents on %d features\n\n",
              attr(x, "n_reference"), attr(x, "p")))

  print(round(utils::head(d, n), 4L))
  if (length(d) > n) {
    cat(sprintf("... %d more\n", length(d) - n))
  }
  invisible(x)
}

#' @rdname score
#' @export
summary.stylo_score <- function(object, ...) {
  d <- as.numeric(object)
  method <- attr(object, "method")

  #for the squared Mahalanobis distance the reference distribution under
  #multivariate normality is chi-squared on p degrees of freedom. The angle
  #has no such distribution, so the cut-off is the 95th percentile of the
  #reference documents' own distances, recorded when the profile was built.
  #Both cut-offs come from the reference corpus, never from the scores being
  #judged, so the flagged proportion is free to differ from 5 per cent.
  cutoff <- if (method == "mahalanobis") {
    stats::qchisq(0.95, df = attr(object, "p"))
  } else {
    attr(object, "angular_ref")
  }

  out <- list(
    n = length(d),
    method = method,
    n_reference = attr(object, "n_reference"),
    p = attr(object, "p"),
    quantiles = stats::quantile(d, c(0, 0.25, 0.5, 0.75, 1)),
    mean = mean(d),
    cutoff = cutoff,
    n_flagged = sum(d > cutoff),
    principled = method == "mahalanobis"
  )
  class(out) <- "summary.stylo_score"
  out
}

#' @rdname score
#' @export
print.summary.stylo_score <- function(x, ...) {
  cat(sprintf("Scores for %d document(s), %s distance\n", x$n, x$method))
  cat(sprintf("Reference profile: %d documents, %d features\n\n",
              x$n_reference, x$p))

  print(round(x$quantiles, 4L))
  cat(sprintf("\nMean: %.4f\n", x$mean))

  basis <- if (x$principled) {
    sprintf("chi-squared(%d) 95%%", x$p)
  } else {
    "95th percentile of the reference corpus"
  }
  cat(sprintf("\nFlagged above %.4f (%s): %d of %d (%.1f%%)\n",
              x$cutoff, basis, x$n_flagged, x$n, 100 * x$n_flagged / x$n))
  cat("\nA flagged document is unusual relative to the reference corpus.\n")
  cat("It is not evidence that the document was machine-generated.\n")
  invisible(x)
}
