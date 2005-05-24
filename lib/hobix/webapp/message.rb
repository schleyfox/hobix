module Hobix
class WebApp
  # :stopdoc:
  class Header
    def Header.capitalize_field_name(field_name)
      field_name.gsub(/[A-Za-z]+/) {|s| s.capitalize }
    end

    def initialize
      @fields = []
    end

    def freeze
      @fields.freeze
      super
    end

    def dup
      result = Header.new
      @fields.each {|_, k, v|
        result.add(k, v)
      }
      result
    end

    def clear
      @fields.clear
    end

    def remove(field_name)
      k1 = field_name.downcase
      @fields.reject! {|k2, _, _| k1 == k2 }
      nil
    end

    def add(field_name, field_body)
      field_name = WebApp.make_frozen_string(field_name)
      field_body = WebApp.make_frozen_string(field_body)
      @fields << [field_name.downcase.freeze, field_name, field_body]
    end

    def set(field_name, field_body)
      field_name = WebApp.make_frozen_string(field_name)
      remove(field_name)
      add(field_name, field_body)
    end

    def has?(field_name)
      @fields.assoc(field_name.downcase) != nil
    end

    def [](field_name)
      k1 = field_name.downcase
      @fields.each {|k2, field_name, field_body|
        return field_body.dup if k1 == k2
      }
      nil
    end

    def lookup_all(field_name)
      k1 = field_name.downcase
      result = []
      @fields.each {|k2, field_name, field_body|
        result << field_body.dup if k1 == k2
      }
      result
    end

    def each
      @fields.each {|_, field_name, field_body|
        field_name = field_name.dup
        field_body = field_body.dup
        yield field_name, field_body
      }
    end
  end

  class Message
    def initialize(header={}, body='')
      @header_object = Header.new
      case header
      when Hash
        header.each_pair {|k, v|
          raise ArgumentError, "unexpected header field name: #{k.inspect}" unless k.respond_to? :to_str
          raise ArgumentError, "unexpected header field body: #{v.inspect}" unless v.respond_to? :to_str
          @header_object.add k.to_str, v.to_str
        }
      when Array
        header.each {|k, v|
          raise ArgumentError, "unexpected header field name: #{k.inspect}" unless k.respond_to? :to_str
          raise ArgumentError, "unexpected header field body: #{v.inspect}" unless v.respond_to? :to_str
          @header_object.add k.to_str, v.to_str
        }
      else
        raise ArgumentError, "unexpected header argument: #{header.inspect}"
      end
      raise ArgumentError, "unexpected body: #{body.inspect}" unless body.respond_to? :to_str
      @body_object = StringIO.new(body.to_str)
    end
    attr_reader :header_object, :body_object

    def freeze
      @header_object.freeze
      @body_object.string.freeze
      super
    end

    def output_header(out)
      @header_object.each {|k, v|
        out << "#{k}: #{v}\n"
      }
    end

    def output_body(out)
      out << @body_object.string
    end

    def output_message(out)
      output_header(out)
      out << "\n"
      output_body(out)
    end
  end

  class Request < Message
    def initialize(request_line=nil, header={}, body='')
      @request_line = request_line
      super header, body
    end
    attr_reader :request_method,
                :server_name, :server_port,
                :script_name, :path_info,
                :query_string,
                :server_protocol,
                :remote_addr, :content_type, :request_uri, :action_uri

    def make_request_header_from_cgi_env(env)
      env.each {|k, v|
        next if /\AHTTP_/ !~ k
        k = Header.capitalize_field_name($')
        k.gsub!(/_/, '-')
        @header_object.add k, v
      }
      @request_method = env['REQUEST_METHOD']
      @server_name = env['SERVER_NAME'] || ''
      @server_port = env['SERVER_PORT'].to_i
      @script_name = env['SCRIPT_NAME'] || ''
      @path_info = env['PATH_INFO'] || ''
      @query_string = QueryString.primitive_new_for_raw_query_string(env['QUERY_STRING'] || '')
      @server_protocol = env['SERVER_PROTOCOL'] || ''
      @remote_addr = env['REMOTE_ADDR'] || ''
      @content_type = env['CONTENT_TYPE'] || ''

      # non-standard:
      @request_uri = env['REQUEST_URI'] # Apache

      # hobix action uri
      @action_uri = ( env['PATH_INFO'] || env['REQUEST_URI'] ).
        gsub( /^(#{ Regexp::quote( File::dirname( @script_name ) ) })?\/*/, '' ).
        gsub( /\?.+$/, '' )
    end
  end

  class Response < Message
    def initialize(status_line='200 OK', header={}, body='')
      @status_line = status_line
      super header, body
    end
    attr_accessor :status_line

    def output_cgi_status_field(out)
      out << "Status: #{self.status_line}\n"
    end
  end
  # :startdoc:
end
end
