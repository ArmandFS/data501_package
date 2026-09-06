#' styloprofile: Stylometric Reference Profiles and Outlier Scoring
#'
#' Builds a statistical reference profile of human-authored writing from a small
#' set of interpretable stylometric features, then scores new documents against
#' that profile with a regularised Mahalanobis distance.
#'
#' The package deliberately avoids framing detection as binary classification.
#' A high score means a document is unusual *relative to the reference corpus*,
#' not that it was machine-generated. See the package README for the fairness
#' caveats that follow from this.
#'
#' @references
#' Froehling, L., & Zubiaga, A. (2021). Feature-based detection of automated
#' language models: Tackling GPT-2, GPT-3 and Grover. \emph{PeerJ Computer
#' Science}, 7, e443.
#'
#' Mahalanobis, P. C. (1936). On the generalised distance in statistics.
#' \emph{Proceedings of the National Institute of Sciences of India}, 2(1), 49--55.
#'
#' @useDynLib styloprofile, .registration = TRUE
#' @importFrom Rcpp sourceCpp
#' @keywords internal
"_PACKAGE"
