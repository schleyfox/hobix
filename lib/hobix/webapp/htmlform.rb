module Hobix
class WebApp
  class QueryString
    # decode self as application/x-www-form-urlencoded and returns
    # HTMLFormQuery object.
    def decode_as_application_x_www_form_urlencoded
      # xxx: warning if invalid?
      pairs = []
      @escaped_query_string.scan(/([^&;=]*)=([^&;]*)/) {|key, val|
        key.gsub!(/\+/, ' ')
        key.gsub!(/%([0-9A-F][0-9A-F])/i) { [$1].pack("H*") }
        val.gsub!(/\+/, ' ')
        val.gsub!(/%([0-9A-F][0-9A-F])/i) { [$1].pack("H*") }
        pairs << [key.freeze, val.freeze]
      }
      HTMLFormQuery.new(pairs)
    end
    # decode self as multipart/form-data and returns
    # HTMLFormQuery object.
    def decode_as_multipart_form_data( boundary )
      # xxx: warning if invalid?
      require 'tempfile'
      pairs = []
      boundary = "--" + boundary
      eol = "\015\012"
      str = @escaped_query_string.gsub( /(?:\r?\n|\A)#{ Regexp::quote( boundary ) }--#{ eol }.*/m, '' )
      str.split( /(?:\r?\n|\A)#{ Regexp::quote( boundary ) }#{ eol }/m ).each do |part|
          headers = {}
          header, value = part.split( "#{eol}#{eol}", 2 )
          next unless header and value
          field_name, field_data = nil, {}
          if header =~ /Content-Disposition: form-data;.*(?:\sname="([^"]+)")/m
              field_name = $1
          end
          if header =~ /Content-Disposition: form-data;.*(?:\sfilename="([^"]+)")/m
              body = Tempfile.new( "WebApp" )
              body.binmode if defined? body.binmode
              body.print value
              body.rewind
              field_data = {'filename' => $1, 'tempfile' => body}
              field_data['type'] = $1 if header =~ /Content-Type: (.+?)(?:#{ eol }|\Z)/m
          else
              field_data = value.gsub( /#{ eol }\Z/, '' )
          end
          pairs << [field_name, field_data]
      end
      HTMLFormQuery.new(pairs)
    end
  end

  # HTMLFormQuery represents a query submitted by HTML form. 
  class HTMLFormQuery

    def HTMLFormQuery.each_string_key_pair(arg, &block) # :nodoc:
      if arg.respond_to? :to_ary
        arg = arg.to_ary
        if arg.length == 2 && arg.first.respond_to?(:to_str)
          yield WebApp.make_frozen_string(arg.first), arg.last
        else
          arg.each {|elt|
            HTMLFormQuery.each_string_key_pair(elt, &block)
          }
        end
      elsif arg.respond_to? :to_pair
        arg.each_pair {|key, val|
          yield WebApp.make_frozen_string(key), val
        }
      else
        raise ArgumentError, "non-pairs argument: #{arg.inspect}"
      end
    end

    def initialize(*args)
      @param = []
      HTMLFormQuery.each_string_key_pair(args) {|key, val|
        @param << [key, val]
      }
      @param.freeze
    end

    def each
      @param.each {|key, val|
        yield key.dup, val.dup
      }
    end

    def [](key)
      if pair = @param.assoc(key)
        return pair.last.dup
      end
      return nil
    end

    def lookup_all(key)
      result = []
      @param.each {|k, val|
        result << val if k == key
      }
      return result
    end

    def keys
      @param.map {|key, val| key }.uniq
    end
  end
end
end
