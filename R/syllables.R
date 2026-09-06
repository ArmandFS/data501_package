#' Count syllables in words (reference R implementation)
#'
#' Estimates the syllable count of each word by counting maximal groups of
#' vowels, then subtracting a trailing silent "e". This is the standard
#' heuristic behind readability indices such as SMOG and Flesch-Kincaid.
#'
#' The silent-"e" subtraction is skipped for words ending in a consonant
#' followed by "le", where the "e" is syllabic: "table" is two syllables, but
#' "make" is one.
#'
#' This pure-R version exists for two reasons: it documents the algorithm
#' readably, and it acts as an independent oracle in the unit tests for the
#' compiled [count_syllables_cpp()], which must agree with it exactly.
#'
#' @param words Character vector of words.
#'
#' @return Integer vector of syllable counts, the same length as `words`.
#'   Words with no alphabetic characters give 0; any other word gives at
#'   least 1. `NA` input gives `NA_integer_`.
#'
#' @examples
#' count_syllables_r(c("cat", "table", "beautiful"))
#'
#' @seealso [count_syllables_cpp()] for the compiled equivalent.
#' @export
count_syllables_r <- function(words) {
  if (!is.character(words)) {
    stop("`words` must be a character vector.", call. = FALSE)
  }

  vowels <- c("a", "e", "i", "o", "u", "y")

  vapply(words, function(w) {
    if (is.na(w)) return(NA_integer_)

    chars <- strsplit(tolower(w), "", fixed = TRUE)[[1L]]
    chars <- chars[chars %in% letters]
    n <- length(chars)
    if (n == 0L) return(0L)

    is_vowel <- chars %in% vowels

    # Count maximal runs of vowels: a vowel opens a new group only when the
    # preceding character is not itself a vowel.
    prev_vowel <- c(FALSE, is_vowel[-n])
    groups <- sum(is_vowel & !prev_vowel)

    # Trailing silent "e" ("make"), unless it is a syllabic "-le" ("table").
    if (n > 2L && chars[n] == "e") {
      syllabic_le <- chars[n - 1L] == "l" && !chars[n - 2L] %in% vowels
      if (!syllabic_le && !chars[n - 1L] %in% vowels) {
        groups <- groups - 1L
      }
    }

    max(groups, 1L)
  }, integer(1L), USE.NAMES = FALSE)
}
