require 'hobix/search/dictionary'
require 'hobix/search/vector'

module Hobix
module Search
  module Simple
    class Contents < Array
      def latest_mtime
        latest_mtime = Time.at(0)
        each do |item|
          if(item.mtime > latest_mtime)
            latest_mtime = item.mtime
          end
        end
      end
    end
    
    class Content
      attr_accessor :content, :identifier, :mtime
      def initialize(content, identifier, mtime)
        @content = content
        @identifier = identifier
        @mtime = mtime
      end
    end
    
    SearchResult = Struct.new(:name, :score)
    
    class SearchResult
      # enable sort by score
      def <=>(other)
        self.score <=> other.score
      end
    end
    
    class SearchResults
      attr_reader :warnings
      attr_reader :results
    
    
      def initialize
        @warnings = []
        @results  = {}
      end
    
      def add_warning(txt)
        @warnings << txt
      end
    
      def add_result(name, score)
        @results[name] = SearchResult.new(name, score)
      end
    
      def contains_matches
        !@results.empty?
      end
    end
    
    
    class Searcher
    
      def initialize(dict, document_vectors, cache_file)
        @dict = dict
        @document_vectors = document_vectors
        @cache_file = cache_file
      end
    
      # Return SearchResults based on trying to find the array of
      # +words+ in our document vectors
      #
      # A word beginning '+' _must_ appear in the target documents
      # A word beginning '-' <i>must not</i> appear
      # other words are scored. The documents with the highest
      # scores are returned first
    
      def find_words(words)
        search_results = SearchResults.new
    
        general = Vector.new
        must_match = Vector.new
        must_not_match = Vector.new
        not_found = false
        
        extract_words_for_searcher(words.join(' ')) do |word|
          case word[0]
          when ?+
            word = word[1,99]
            vector = must_match
          when ?-
    	    word = word[1,99]
            vector = must_not_match
          else
    	    vector = general
          end
          
          index = @dict.find(word.downcase)
          if index
            vector.add_word_index(index)
          else
            not_found = true
    	    search_results.add_warning "'#{word}' does not occur in the documents"
          end
        end
    
        if (general.num_bits + must_match.num_bits).zero? 
          search_results.add_warning "No valid search terms given"
        elsif not not_found
          res = []
          @document_vectors.each do |entry, (dvec, mtime)|
            score = dvec.score_against(must_match, must_not_match, general)
            res << [ entry, score ] if score > 0
          end
          
          res.sort {|a,b| b[1] <=> a[1] }.each {|name, score|
            search_results.add_result(name, score)
          }
          
          search_results.add_warning "No matches" unless search_results.contains_matches
        end
        search_results
      end
          
          
      # Serialization support. At some point we'll need to do incremental indexing. 
      # For now, however, the following seems to work fairly effectively
      # on 1000 entry blogs, so I'll defer the change until later.
      def Searcher.load(cache_file, wash=false)
        dict = document_vectors = nil
        modified = false
        loaded   = false
        begin
          File.open(cache_file, "r") do |f| 
            unless wash
              dict = Marshal.load(f)
              document_vectors = Marshal.load(f)
              loaded = true
            end
          end
        rescue
        ;
        end
    
        unless loaded
          dict = Dictionary.new
          document_vectors = {}
          modified = true
        end
        
        s = Searcher.new(dict, document_vectors, cache_file)
        s.dump if modified
        s
      end
    
      def dump
        File.open(@cache_file, "w") do |fileInstance|
          Marshal.dump(@dict, fileInstance)
          Marshal.dump(@document_vectors, fileInstance)
        end
      end
    
      def extract_words_for_searcher(text)
        text.scan(/[-+]?\w[\-\w:\\]{2,}/) do |word|
          yield word
        end
      end
    
      def has_entry? id, mtime
        dvec = @document_vectors[id]
        return true if dvec and dvec.at.to_i >= mtime.to_i
      end

      # Create a new dictionary and document vectors from
      # a blog archive
    
      def catalog(entry)
        unless has_entry? entry.identifier, entry.mtime
          vector = Vector.new
          vector.at = entry.mtime
          extract_words_for_searcher(entry.content.downcase) do |word|
            word_index = @dict.add_word(word)
            if word_index
              vector.add_word_index(word_index) 
            end
          end
          @document_vectors[entry.identifier] = vector
        end
      end
    end
  end
end
end
