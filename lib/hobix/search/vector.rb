# Maintain a vector of words, where a word is represented by
# its index in our Dictionary
#
module Hobix
module Search
  module Simple
    class Vector
    
      attr_accessor :at
      attr_reader :num_bits, :max_bit, :bits
    
      def initialize
    #    @bits = []
        @bits = 0
        @max_bit = -1
        @num_bits = 0
      end
    
      def add_word_index(index)
        if @bits[index].zero?
          @bits += (1 << index)
          @num_bits += 1
          @max_bit = index if @max_bit < index
        end
      end
    
      def dot(vector)
        # We only need to calculate up to the end of the shortest vector
        limit = @max_bit
    # Commenting out the next line makes this vector the dominant
    # one when doing the comparison
        limit = vector.max_bit if limit > vector.max_bit
    
        # because both vectors have just ones or zeros in them,
        # we can pre-calculate the AnBn component
        # The vector's magnitude is Sqrt(num set bits)
        factor = Math.sqrt(1.0/@num_bits) * Math.sqrt(1.0/vector.num_bits)
    
        count = 0
        (limit+1).times {|i| count += 1 if @bits[i] ==1 && vector.bits[i] == 1}
    
        factor * count
      end
    
      # We're a document's vector, and we're being matched against
      # three other vectors:
      # 1. A list of <i>must match</i> words
      # 2. A list of <i>must not match</i> words
      # 3. A list of general words. The score we return
      #    is the number of these that we match
      
      def score_against(must_match, must_not_match, general)
        # Eliminate if any _must_not_match_ words found
        unless must_not_match.num_bits.zero?
          return 0 unless (@bits & must_not_match.bits).zero?
        end
    
        # If the match was entirely negative, then we know we're passed at
        # this point
    
        if must_match.num_bits.zero? and general.num_bits.zero?
          return 1
        end
    
        count = 0
    
        # Eliminate unless all _must_match_ words found
    
        unless must_match.num_bits.zero?
          return 0 unless (@bits & must_match.bits) == must_match.bits
          count = 1
        end
    
        # finally score on the rest
        common = general.bits & @bits
        count += count_bits(common, @max_bit+1) unless common.zero?
        count
      end
    
      private
    
      def count_bits(word, max_bit)
        res = 0
        ((max_bit+29)/30).times do |offset|
          x = (word >> (offset*30)) & 0x3fffffff
          next if x.zero?
          x = x - ((x >> 1) & 0x55555555)
          x = (x & 0x33333333) + ((x >> 2) & 0x33333333)
          x = (x + (x >> 4)) & 0x0f0f0f0f;
          x = x + (x >> 8)
          x = x + (x >> 16)
          res += x & 0x3f
        end
        res
      end
    
    end
  end
end
end
