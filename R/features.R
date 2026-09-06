#conjunctions are a closed class, so listing them avoids needing a POS tagger
.conjunctions <- c(
  # coordinating
  "and", "but", "or", "nor", "for", "yet", "so",
  # subordinating
  "after", "although", "as", "because", "before", "even", "if", "once",
  "since", "than", "that", "though", "unless", "until", "when", "whenever",
  "where", "whereas", "wherever", "whether", "while"
)

#the most frequent words of written English. vocab_sophistication is the
#proportion of a document's tokens falling outside this band.
.common_words <- c(
  "a", "able", "about", "above", "across", "add", "after", "afternoon",
  "again", "against", "age", "ago", "air", "all", "allow", "almost", "along",
  "also", "although", "always", "am", "among", "amongst", "an", "and",
  "another", "any", "anyone", "anything", "appear", "are", "area", "around",
  "art", "as", "at", "autumn", "away", "back", "bad", "be", "because",
  "become", "been", "before", "begin", "behind", "being", "believe", "below",
  "beside", "best", "better", "between", "beyond", "big", "black", "blue",
  "body", "book", "both", "boy", "bring", "build", "business", "but", "buy",
  "by", "came", "can", "cannot", "car", "case", "change", "child",
  "children", "city", "clear", "close", "cold", "college", "come",
  "community", "company", "consider", "continue", "could", "country",
  "create", "cut", "dare", "day", "death", "decide", "did", "die",
  "different", "do", "does", "doing", "done", "door", "down", "during",
  "each", "earlier", "early", "education", "effect", "eight", "either",
  "end", "enough", "even", "evening", "every", "everyone", "everything",
  "example", "expect", "experience", "eye", "face", "fact", "fall", "family",
  "far", "father", "feel", "felt", "few", "field", "first", "five", "follow",
  "food", "foot", "for", "force", "found", "four", "free", "friday",
  "friend", "from", "full", "game", "get", "girl", "give", "given", "go",
  "goes", "going", "gone", "good", "got", "government", "great", "green",
  "group", "grow", "guy", "had", "half", "hand", "hard", "has", "have",
  "having", "he", "head", "health", "hear", "heart", "heavy", "help", "her",
  "here", "hers", "herself", "high", "him", "himself", "his", "history",
  "hold", "home", "hot", "hour", "house", "how", "however", "i", "idea",
  "if", "important", "in", "include", "information", "interest", "into",
  "is", "issue", "it", "its", "itself", "job", "just", "keep", "kept", "kid",
  "kill", "kind", "know", "known", "large", "last", "late", "later", "law",
  "lead", "learn", "least", "leave", "left", "less", "let", "level", "life",
  "light", "like", "line", "little", "live", "long", "look", "lose", "lot",
  "love", "low", "made", "make", "man", "many", "market", "may", "maybe",
  "me", "mean", "meet", "member", "might", "mine", "minute", "moment",
  "monday", "money", "month", "more", "morning", "most", "mother", "move",
  "much", "music", "must", "my", "myself", "name", "nation", "near", "need",
  "neither", "never", "new", "next", "night", "nine", "no", "nobody", "none",
  "nor", "not", "nothing", "now", "number", "of", "off", "offer", "office",
  "often", "old", "on", "one", "only", "onto", "open", "or", "other",
  "others", "ought", "our", "ours", "ourselves", "out", "over", "own",
  "paper", "part", "party", "pass", "past", "pay", "people", "per",
  "perhaps", "person", "place", "plan", "play", "point", "policy",
  "possible", "power", "president", "problem", "process", "program",
  "provide", "public", "pull", "put", "question", "quite", "raise", "rather",
  "reach", "read", "real", "really", "reason", "recent", "red", "remain",
  "remember", "report", "require", "research", "result", "right", "road",
  "room", "run", "said", "same", "saturday", "say", "saying", "school",
  "second", "see", "seem", "seen", "sell", "send", "sense", "serve",
  "service", "set", "seven", "several", "shall", "she", "should", "show",
  "side", "since", "sit", "six", "small", "so", "some", "somebody",
  "someone", "something", "sometimes", "soon", "speak", "special", "spend",
  "spring", "stand", "start", "state", "stay", "still", "stop", "story",
  "street", "strong", "student", "study", "such", "suggest", "summer",
  "sunday", "sure", "system", "table", "take", "taken", "talk", "team",
  "ten", "than", "that", "the", "their", "theirs", "them", "themselves",
  "then", "there", "therefore", "these", "they", "thing", "things", "think",
  "third", "this", "though", "thought", "three", "through", "thursday",
  "time", "to", "today", "together", "told", "tomorrow", "too", "took",
  "top", "toward", "towards", "town", "true", "tuesday", "turn", "two",
  "under", "understand", "unless", "until", "unto", "up", "upon", "us",
  "use", "used", "very", "via", "voice", "wait", "walk", "want", "war",
  "was", "watch", "water", "way", "we", "wednesday", "week", "well", "went",
  "were", "what", "whatever", "when", "whenever", "where", "wherever",
  "whether", "which", "while", "white", "who", "whoever", "whole", "whom",
  "whose", "why", "will", "win", "winter", "with", "within", "without",
  "woman", "word", "work", "world", "would", "write", "year", "yes",
  "yesterday", "yet", "you", "young", "your", "yours", "yourself"
)

#' Split text into sentences
#'
#' Splits on sentence-final punctuation. Abbreviations like "Dr." will
#' over-split, but it does so consistently for every document.
#'
#' @param txt A single character string.
#' @return Character vector of non-empty sentences.
#' @noRd
.split_sentences <- function(txt) {
  parts <- strsplit(txt, "(?<=[.!?])\\s+", perl = TRUE)[[1L]]
  parts <- trimws(parts)
  parts[nzchar(parts)]
}

#' Split text into lower-case word tokens
#'
#' @param txt A single character string.
#' @return Character vector of tokens containing at least one letter.
#' @noRd
.tokenise <- function(txt) {
  toks <- strsplit(tolower(txt), "[^a-z']+", perl = TRUE)[[1L]]
  toks <- gsub("^'+|'+$", "", toks)
  toks[nzchar(toks)]
}

#' Extract stylometric features from documents
#'
#' Computes five interpretable features per document. Each is a rate,
#' proportion or ratio, so documents of different lengths stay comparable.
#'
#' @section Features:
#' \describe{
#'   \item{`mean_sentence_length`}{Word tokens per sentence.}
#'   \item{`conj_rate`}{Conjunctions per sentence.}
#'   \item{`cv_word_length`}{Coefficient of variation of word length, i.e.
#'     the standard deviation over the mean. Dividing by the mean is what
#'     stops this just measuring who uses longer words.}
#'   \item{`prop_polysyllabic`}{Proportion of tokens with 3+ syllables.}
#'   \item{`vocab_sophistication`}{Proportion of tokens outside a band of
#'     common English words.}
#' }
#'
#' @param text Character vector of documents, one document per element.
#'
#' @return Numeric matrix with one row per document and five named feature
#'   columns. Row names are carried over from `names(text)` when present.
#'   A document with no word tokens yields a row of `NA`s.
#'
#' @examples
#' stylo_features(c(
#'   "The cat sat. It was quiet, and nobody moved.",
#'   "Consequently, the extraordinary ramifications remained incomprehensible."
#' ))
#'
#' @export
stylo_features <- function(text) {
  if (!is.character(text)) {
    stop("`text` must be a character vector.", call. = FALSE)
  }
  if (length(text) == 0L) {
    stop("`text` must contain at least one document.", call. = FALSE)
  }

  feature_names <- c("mean_sentence_length", "conj_rate", "cv_word_length",
                     "prop_polysyllabic", "vocab_sophistication")

  out <- vapply(text, function(txt) {
    if (is.na(txt)) return(rep(NA_real_, 5L))

    sentences <- .split_sentences(txt)
    tokens <- .tokenise(txt)

    n_tokens <- length(tokens)
    n_sentences <- max(length(sentences), 1L)
    if (n_tokens == 0L) return(rep(NA_real_, 5L))

    word_len <- nchar(tokens)
    mean_len <- mean(word_len)

    #one token has no spread, so report 0 rather than the NA sd() gives
    cv <- if (n_tokens < 2L || mean_len == 0) 0 else stats::sd(word_len) / mean_len

    syl <- count_syllables_cpp(tokens)

    c(
      n_tokens / n_sentences,
      sum(tokens %in% .conjunctions) / n_sentences,
      cv,
      mean(syl >= 3L),
      mean(!tokens %in% .common_words)
    )
  }, numeric(5L), USE.NAMES = FALSE)

  out <- t(out)
  colnames(out) <- feature_names
  rownames(out) <- names(text)
  out
}
