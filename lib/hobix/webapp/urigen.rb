require 'uri'

module Hobix
class WebApp
  # :stopdoc:
  class URIGen
    def initialize(scheme, server_name, server_port, script_name, path_info)
      @scheme = scheme
      @server_name = server_name
      @server_port = server_port
      @script_name = script_name
      @path_info = path_info
      uri = "#{scheme}://#{server_name}:#{server_port}"
      uri << script_name.gsub(%r{[^/]+}) {|segment| pchar_escape(segment) }
      uri << path_info.gsub(%r{[^/]+}) {|segment| pchar_escape(segment) }
      @base_uri = URI.parse(uri)
    end
    attr_reader :base_uri

    def make_relative_uri(hash)
      script = nil
      path_info = nil
      query = nil
      fragment = nil
      hash.each_pair {|k,v|
        case k
        when :script then script = v
        when :path_info then path_info = v
        when :query then query = v
        when :fragment then fragment = v
        else
          raise ArgumentError, "unexpected: #{k} => #{v}"
        end
      }

      if !script
        script = @script_name
      elsif %r{\A/} !~ script
        script = @script_name.sub(%r{[^/]*\z}) { script }
        while script.sub!(%r{/[^/]*/\.\.(?=/|\z)}, '')
        end
        script.sub!(%r{\A/\.\.(?=/|\z)}, '')
      end

      path_info = '/' + path_info if %r{\A[^/]} =~ path_info

      dst = "#{script}#{path_info}"
      dst.sub!(%r{\A/}, '')
      dst.sub!(%r{[^/]*\z}, '')
      dst_basename = $&

      src = "#{@script_name}#{@path_info}"
      src.sub!(%r{\A/}, '')
      src.sub!(%r{[^/]*\z}, '')

      while src[%r{\A[^/]*/}] == dst[%r{\A[^/]*/}]
        if $~
          src.sub!(%r{\A[^/]*/}, '')
          dst.sub!(%r{\A[^/]*/}, '')
        else
          break
        end
      end

      rel_path = '../' * src.count('/')
      rel_path << dst << dst_basename
      rel_path = './' if rel_path.empty?

      rel_path.gsub!(%r{[^/]+}) {|segment| pchar_escape(segment) }
      if /\A[A-Za-z][A-Za-z0-9+\-.]*:/ =~ rel_path # It seems absolute URI.
        rel_path.sub!(/:/, '%3A')
      end

      if query
        case query
        when QueryString
          query = query.instance_eval { @escaped_query_string }
        when Hash
          query = query.map {|k, v|
            case v
            when String
              "#{form_escape(k)}=#{form_escape(v)}"
            when Array
              v.map {|e|
                unless String === e
                  raise ArgumentError, "unexpected query value: #{e.inspect}"
                end
                "#{form_escape(k)}=#{form_escape(e)}"
              }
            else
              raise ArgumentError, "unexpected query value: #{v.inspect}"
            end
          }.join(';')
        else
          raise ArgumentError, "unexpected query: #{query.inspect}"
        end
        unless query.empty?
          query = '?' + uric_escape(query)
        end
      else
        query = ''
      end

      if fragment
        fragment = "#" + uric_escape(fragment)
      else
        fragment = ''
      end

      URI.parse(rel_path + query + fragment)
    end

    def make_absolute_uri(hash)
      @base_uri + make_relative_uri(hash)
    end

    Alpha = 'a-zA-Z'
    Digit = '0-9'
    AlphaNum = Alpha + Digit
    Mark = '\-_.!~*\'()'
    Unreserved = AlphaNum + Mark
    PChar = Unreserved + ':@&=+$,'
    def pchar_escape(s)
      s.gsub(/[^#{PChar}]/on) {|c| sprintf("%%%02X", c[0]) }
    end

    Reserved = ';/?:@&=+$,'
    Uric = Reserved + Unreserved
    def uric_escape(s)
      s.gsub(/[^#{Uric}]/on) {|c| sprintf("%%%02X", c[0]) }
    end

    def form_escape(s)
      s.gsub(/[#{Reserved}\x00-\x1f\x7f-\xff]/on) {|c|
        sprintf("%%%02X", c[0])
      }.gsub(/ /on) { '+' }
    end
  end
  # :startdoc:
end
end
