#include <Rcpp.h>
using namespace Rcpp;

// Is `c` an ASCII vowel? "y" is treated as a vowel so that words such as
// "happy" and "rhythm" receive a syllable.
static inline bool is_vowel(char c) {
  return c == 'a' || c == 'e' || c == 'i' || c == 'o' || c == 'u' || c == 'y';
}

static inline bool is_alpha(char c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

static inline char to_lower(char c) {
  return (c >= 'A' && c <= 'Z') ? static_cast<char>(c - 'A' + 'a') : c;
}

//' Count syllables in words (compiled implementation)
//'
//' Compiled equivalent of [count_syllables_r()], using the same vowel-group
//' heuristic with the same silent-"e" and syllabic-"-le" rules. The two
//' functions must agree on every input; the unit tests enforce this by
//' differential testing.
//'
//' Syllable counting is a character-by-character scan over every word of every
//' document, which is the shape of problem where R's vectorisation gives
//' nothing and the interpreter overhead dominates. Moving the inner loop to
//' C++ removes that overhead; see the package vignette for a benchmark.
//'
//' @param words Character vector of words.
//'
//' @return Integer vector of syllable counts, the same length as `words`.
//'   Words with no alphabetic characters give 0; any other word gives at
//'   least 1. `NA` input gives `NA_integer_`.
//'
//' @examples
//' count_syllables_cpp(c("cat", "table", "beautiful"))
//'
//' @seealso [count_syllables_r()] for the reference R implementation.
//' @export
// [[Rcpp::export]]
IntegerVector count_syllables_cpp(CharacterVector words) {
  R_xlen_t n = words.size();
  IntegerVector out(n);

  for (R_xlen_t i = 0; i < n; ++i) {
    if (CharacterVector::is_na(words[i])) {
      out[i] = NA_INTEGER;
      continue;
    }

    std::string raw = as<std::string>(words[i]);

    // Keep alphabetic characters only, lower-cased, mirroring the R version.
    std::string w;
    w.reserve(raw.size());
    for (std::size_t k = 0; k < raw.size(); ++k) {
      if (is_alpha(raw[k])) w.push_back(to_lower(raw[k]));
    }

    std::size_t len = w.size();
    if (len == 0) {
      out[i] = 0;
      continue;
    }

    // Count maximal runs of vowels.
    int groups = 0;
    bool prev_vowel = false;
    for (std::size_t k = 0; k < len; ++k) {
      bool v = is_vowel(w[k]);
      if (v && !prev_vowel) ++groups;
      prev_vowel = v;
    }

    // Trailing silent "e" ("make"), unless it is a syllabic "-le" ("table").
    if (len > 2 && w[len - 1] == 'e') {
      bool syllabic_le = (w[len - 2] == 'l') && !is_vowel(w[len - 3]);
      if (!syllabic_le && !is_vowel(w[len - 2])) --groups;
    }

    out[i] = groups < 1 ? 1 : groups;
  }

  return out;
}
