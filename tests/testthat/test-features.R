#following the same principle as the rest of the suite: an expected value has
#to come from somewhere other than reading stylo_features()'s own code.
#mean_sentence_length and conj_rate are counted by hand; cv_word_length is
#re-derived from its documented formula (sd/mean), not read off the
#implementation; prop_polysyllabic chains off the syllable counts already
#hand-pinned in test-syllables.R (cat, the, beautiful, happy); and
#vocab_sophistication is checked only at its 0/1 boundaries, using words so
#obviously common or so obviously obscure that the exact contents of the
#internal word band (noted in R/features.R as liable to change later) don't
#matter.

test_that("mean_sentence_length and conj_rate count by hand on a conjunction-free document", {
  #"one".."ten": 10 tokens over 2 sentences, no conjunctions among them
  f <- stylo_features("One two three four five. Six seven eight nine ten.")
  expect_equal(unname(f[, "mean_sentence_length"]), 5)
  expect_equal(unname(f[, "conj_rate"]), 0)
})

test_that("conj_rate counts a coordinating and a subordinating conjunction", {
  #"because" (subordinating) and "and" (coordinating), 9 tokens, 1 sentence
  f <- stylo_features("I left because it rained and I was cold.")
  expect_equal(unname(f[, "mean_sentence_length"]), 9)
  expect_equal(unname(f[, "conj_rate"]), 2)
})

test_that("cv_word_length matches its documented formula, sd over mean", {
  f <- stylo_features("a bb ccc dddd.")
  word_len <- c(1, 2, 3, 4)
  expect_equal(unname(f[, "cv_word_length"]), sd(word_len) / mean(word_len))
})

test_that("prop_polysyllabic agrees with the syllable counts pinned in test-syllables.R", {
  #the=1, cat=1, is=1, and=1 (all single vowel groups); beautiful=3, happy=2
  #(the, cat, beautiful and happy are hand-pinned anchors in test-syllables.R)
  f <- stylo_features("The cat is beautiful and happy.")
  expect_equal(unname(f[, "mean_sentence_length"]), 6)
  expect_equal(unname(f[, "conj_rate"]), 1)
  expect_equal(unname(f[, "prop_polysyllabic"]), 1 / 6)
})

test_that("vocab_sophistication is 0 for a document of only common function words", {
  f <- stylo_features("It is the one and the same.")
  expect_equal(unname(f[, "vocab_sophistication"]), 0)
})

test_that("vocab_sophistication is 1 for a document of only obscure technical words", {
  f <- stylo_features("Juxtaposition deoxyribonucleic photosynthesis onomatopoeia.")
  expect_equal(unname(f[, "vocab_sophistication"]), 1)
})

test_that("a single-token document gets cv_word_length 0, not NA", {
  f <- stylo_features("Hello.")
  expect_equal(unname(f[, "cv_word_length"]), 0)
  expect_false(anyNA(f))
})

test_that("a document with no tokens returns a row of NA", {
  f <- stylo_features("")
  expect_true(all(is.na(f[1, ])))
})

test_that("an NA document returns a row of NA without erroring, and doesn't affect other rows", {
  f <- stylo_features(c(NA_character_, "a word"))
  expect_true(all(is.na(f[1, ])))
  expect_false(anyNA(f[2, ]))
})

test_that("a document with no sentence-final punctuation is one sentence, not a division by zero", {
  f <- stylo_features("hello world")
  expect_equal(unname(f[, "mean_sentence_length"]), 2)
})

test_that("returns the five documented feature columns, in order", {
  f <- stylo_features("A simple test sentence.")
  expect_equal(colnames(f),
               c("mean_sentence_length", "conj_rate", "cv_word_length",
                 "prop_polysyllabic", "vocab_sophistication"))
})

test_that("row names are carried over from names(text)", {
  f <- stylo_features(c(a = "One sentence here.", b = "Another one here."))
  expect_equal(rownames(f), c("a", "b"))
})

test_that("rejects non-character input", {
  expect_error(stylo_features(123), "character vector")
})

test_that("rejects zero-length input", {
  expect_error(stylo_features(character(0)), "at least one document")
})
