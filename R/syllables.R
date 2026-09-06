#' Count syllables in words (R version)
#'
#' Counts groups of vowels, then drops a trailing silent "e". Words ending in
#' a consonant plus "le" keep the "e", so "table" is 2 but "make" is 1.
#'
#' Used as the reference for [count_syllables_cpp()] in the unit tests.
#'
#' @param words Character vector of words.
#'
#' @return Integer vector of syllable counts, same length as `words`. Words
#'   with no letters give 0, anything else gives at least 1, `NA` gives `NA`.
#'
#' @examples
#' count_syllables_r(c("cat", "table", "beautiful"))
#'
#' @seealso [count_syllables_cpp()]
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

    #a vowel only opens a new group if the one before it wasn't a vowel
    prev_vowel <- c(FALSE, is_vowel[-n])
    groups <- sum(is_vowel & !prev_vowel)

    #silent "e" as in "make", but not the "-le" in "table"
    if (n > 2L && chars[n] == "e") {
      syllabic_le <- chars[n - 1L] == "l" && !chars[n - 2L] %in% vowels
      if (!syllabic_le && !chars[n - 1L] %in% vowels) {
        groups <- groups - 1L
      }
    }

    max(groups, 1L)
  }, integer(1L), USE.NAMES = FALSE)
}
