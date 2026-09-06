#the C++ version gets tested harder than its size suggests: an off-by-one in
#C++ reads memory it doesn't own instead of erroring like R would.

# --- counts worked out by hand ---
#
#comparing the two implementations would still pass if both were wrong the
#same way, so pin some values independently.

test_that("matches syllable counts worked out by hand", {
  expect_equal(count_syllables_cpp("cat"), 1L)
  expect_equal(count_syllables_cpp("beautiful"), 3L)    #eau / i / u
  expect_equal(count_syllables_cpp("make"), 1L)         #silent trailing e
  expect_equal(count_syllables_cpp("table"), 2L)        #syllabic -le
  expect_equal(count_syllables_cpp("queue"), 1L)        #one long vowel run
  expect_equal(count_syllables_cpp("rhythm"), 1L)       #y counts as a vowel
  expect_equal(count_syllables_cpp("happy"), 2L)
  expect_equal(count_syllables_cpp("the"), 1L)          #floor of 1, not 0
})

# --- vs the R version ---

test_that("agrees with the R implementation on a spread of words", {
  words <- c(
    "cat", "dog", "table", "make", "the", "a", "I", "queue", "rhythm", "happy",
    "beautiful", "extraordinary", "incomprehensible", "strength", "through",
    "idea", "area", "being", "seeing", "little", "bottle", "simple", "people",
    "one", "once", "some", "come", "home", "time", "line", "machine",
    "generated", "statistical", "mahalanobis", "stylometric", "syllable"
  )
  expect_equal(count_syllables_cpp(words), count_syllables_r(words))
})

test_that("agrees with the R implementation on random letter strings", {
  #random strings hit combinations a hand-written list wouldn't
  set.seed(7)
  words <- vapply(seq_len(500), function(i) {
    paste(sample(letters, sample(1:12, 1), replace = TRUE), collapse = "")
  }, character(1))
  expect_equal(count_syllables_cpp(words), count_syllables_r(words))
})

test_that("agrees with the R implementation on messy input", {
  messy <- c("don't", "Hello,", "well-known", "  spaced  ", "MiXeD", "CAPS",
             "e", "ee", "le", "ble", "able", "'", "123abc", "abc123")
  expect_equal(count_syllables_cpp(messy), count_syllables_r(messy))
})

# --- edge cases ---

test_that("returns 0 when there are no letters to count", {
  expect_equal(count_syllables_cpp(""), 0L)
  expect_equal(count_syllables_cpp("123"), 0L)
  expect_equal(count_syllables_cpp("!!!"), 0L)
})

test_that("propagates NA as NA_integer_", {
  expect_equal(count_syllables_cpp(NA_character_), NA_integer_)
  expect_equal(count_syllables_cpp(c("cat", NA, "table")), c(1L, NA, 2L))
})

test_that("is case insensitive", {
  expect_equal(count_syllables_cpp("BEAUTIFUL"), count_syllables_cpp("beautiful"))
  expect_equal(count_syllables_cpp("TaBlE"), 2L)
})

test_that("handles very short and very long words", {
  #the silent-e branch reads w[len - 3], so 1-3 letter words are where it
  #would go out of bounds
  short <- c("a", "I", "an", "be", "the", "ate", "eye")
  expect_equal(count_syllables_cpp(short), count_syllables_r(short))

  long <- paste(rep("ba", 500), collapse = "")  #1000 characters
  expect_equal(count_syllables_cpp(long), 500L)
})

test_that("handles an empty input vector", {
  expect_equal(count_syllables_cpp(character(0)), integer(0))
})

# --- things that should hold for any input ---

test_that("returns one count per input element", {
  words <- c("one", "two", "three", "four")
  expect_length(count_syllables_cpp(words), length(words))
  expect_length(count_syllables_cpp(character(0)), 0L)
})

test_that("never returns zero for a word containing a letter", {
  set.seed(11)
  words <- vapply(seq_len(300), function(i) {
    paste(sample(letters, sample(1:10, 1), replace = TRUE), collapse = "")
  }, character(1))
  expect_true(all(count_syllables_cpp(words) >= 1L))
})

test_that("returns an integer vector, not a double", {
  expect_type(count_syllables_cpp(c("cat", "table")), "integer")
})

# --- the R version checks its own input ---

test_that("count_syllables_r() rejects non-character input", {
  expect_error(count_syllables_r(1:3), "must be a character vector")
})
