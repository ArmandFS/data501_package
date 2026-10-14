#' @details
#' `plot.stylo_profile()` draws the same `center`/`scale` table
#' `print.stylo_profile()` prints, one small panel per feature, because a
#' profile stores only those summary statistics -- not the documents it was
#' built from -- and features differ too much in scale (`mean_sentence_length`
#' is tens; `vocab_sophistication` is a proportion) to share one axis.
#'
#' @param y Ignored; present for consistency with the \code{plot} generic.
#' @rdname build_profile
#' @export
plot.stylo_profile <- function(x, y = NULL, ...) {
  p <- x$p
  op <- graphics::par(mfrow = c(ceiling(p / 2), min(p, 2L)),
                      mar = c(2, 4, 2, 1))
  on.exit(graphics::par(op))

  for (i in seq_len(p)) {
    feat <- x$features[i]
    mid  <- x$center[i]
    half <- x$scale[i]

    graphics::plot(1, mid,
                   xlim = c(0.5, 1.5),
                   ylim = c(mid - 1.5 * half, mid + 1.5 * half),
                   xaxt = "n", xlab = "", ylab = "", main = feat,
                   pch = 16, cex = 1.5)
    #whiskers at center +/- one reference standard deviation
    graphics::arrows(1, mid - half, 1, mid + half,
                     angle = 90, code = 3, length = 0.05)
  }
  invisible(x)
}

#' @details
#' `plot.stylo_score()` draws a histogram of the scores with the same
#' flagging cut-off `summary.stylo_score()` reports -- the chi-squared 95%
#' point for `"mahalanobis"`, or the reference corpus's own 95th percentile
#' angle for `"angular"` -- so the picture and the printed summary always
#' agree.
#'
#' @rdname score
#' @export
plot.stylo_score <- function(x, ...) {
  d <- as.numeric(x)
  method <- attr(x, "method")

  cutoff <- if (method == "mahalanobis") {
    stats::qchisq(0.95, df = attr(x, "p"))
  } else {
    attr(x, "angular_ref")
  }

  graphics::hist(d,
                 main = sprintf("%s distance", method),
                 xlab = sprintf("%s distance to the reference profile", method),
                 col = "grey85", border = "white")
  graphics::abline(v = cutoff, col = "firebrick", lwd = 2, lty = 2)
  graphics::legend("topright", legend = "95% cut-off", bty = "n",
                   col = "firebrick", lwd = 2, lty = 2)
  invisible(x)
}
