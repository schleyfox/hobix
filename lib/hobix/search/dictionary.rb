# Maintain a dictionary mapping words to consecutive integers (the
# first unique word is 0, the second is 1 and so on)

require 'hobix/search/porter_stemmer'
module Hobix
module Search
  module Simple
  class Dictionary
    STOP_WORDS = {
      "a" => 1,
      "again" => 1,
      "all" => 1,
      "along" => 1,
      "also" => 1,
      "an" => 1,
      "and" => 1,
      "arialhelvetica" => 1,
      "as" => 1,
      "at" => 1,
      "but" => 1,
      "by" => 1,
      "came" => 1,
      "can" => 1,
      "cant" => 1,
      "couldnt" => 1,
      "did" => 1,
      "didn" => 1,
      "didnt" => 1,
      "do" => 1,
      "doesnt" => 1,
      "dont" => 1,
      "entrytitledetail" => 1,
      "ever" => 1,
      "first" => 1,
      "fontvariant" => 1,
      "from" => 1,
      "have" => 1,
      "her" => 1,
      "here" => 1,
      "him" => 1,
      "how" => 1,
      "i" => 1,
      "if" => 1,
      "in" => 1,
      "into" => 1,
      "is" => 1,
      "isnt" => 1,
      "it" => 1,
      "itll" => 1,
      "just" => 1,
      "last" => 1,
      "least" => 1,
      "like" => 1,
      "most" => 1,
      "my" => 1,
      "new" => 1,
      "no" => 1,
      "not" => 1,
      "now" => 1,
      "of" => 1,
      "on" => 1,
      "or" => 1,
      "should" => 1,
      "sidebartitl" => 1,
      "sinc" => 1,
      "so" => 1,
      "some" => 1,
      "textdecoration" => 1,
      "th" => 1,
      "than" => 1,
      "that" => 1,
      "the" => 1,
      "their" => 1,
      "then" => 1,
      "those" => 1,
      "to" => 1,
      "told" => 1,
      "too" => 1,
      "true" => 1,
      "try" => 1,
      "until" => 1,
      "url" => 1,
      "us" => 1,
      "were" => 1,
      "when" => 1,
      "whether" => 1,
      "while" => 1,
      "with" => 1,
      "within" => 1,
      "yes" => 1,
      "you" => 1,
      "youll" => 1,
      }
    
      def initialize
        @words = {}
      end
    
      def add_word(word)
        word = Stemmable::stem_porter(word)
        if STOP_WORDS[word]
          nil
        else
          @words[word] ||= @words.size
        end
      end
    
      def find(word)
        word = Stemmable::stem_porter(word)
        if STOP_WORDS[word]
          nil
        else
          @words[word]
        end
      end
    
      def size
        @words.size
      end
    
      def dump
        puts @words.keys.sort
      end

    end
  end
end
end
