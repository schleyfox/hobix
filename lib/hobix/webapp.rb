#
# A trimmed-down version of akr's incredibly great WebApp library.
# The documentation is here: <http://cvs.m17n.org/~akr/webapp/doc/index.html>
# All the docs still apply since I only trimmed out undocumented stuff.
#
require 'stringio'
require 'pathname'
require 'zlib'
require 'time'
require 'hobix'
require 'hobix/webapp/urigen'
require 'hobix/webapp/message'
require 'hobix/webapp/htmlform'

class Regexp
  def disable_capture
    re = ''
    self.source.scan(/\\.|[^\\\(]+|\(\?|\(/m) {|s|
      if s == '('
        re << '(?:'
      else
        re << s
      end
    }
    Regexp.new(re, self.options, self.kcode)
  end
end

module Kernel
  def puts( *args )
  end
end

module Hobix
class WebApp
  NameChar = /[-A-Za-z0-9._:]/
  NameExp = /[A-Za-z_:]#{NameChar}*/
  XmlVersionNum = /[a-zA-Z0-9_.:-]+/
  XmlVersionInfo_C = /\s+version\s*=\s*(?:'(#{XmlVersionNum})'|"(#{XmlVersionNum})")/
  XmlVersionInfo = XmlVersionInfo_C.disable_capture
  XmlEncName = /[A-Za-z][A-Za-z0-9._-]*/
  XmlEncodingDecl_C = /\s+encoding\s*=\s*(?:"(#{XmlEncName})"|'(#{XmlEncName})')/
  XmlEncodingDecl = XmlEncodingDecl_C.disable_capture
  XmlSDDecl_C = /\s+standalone\s*=\s*(?:'(yes|no)'|"(yes|no)")/
  XmlSDDecl = XmlSDDecl_C.disable_capture
  XmlDecl_C = /<\?xml#{XmlVersionInfo_C}#{XmlEncodingDecl_C}?#{XmlSDDecl_C}?\s*\?>/
  XmlDecl = /<\?xml#{XmlVersionInfo}#{XmlEncodingDecl}?#{XmlSDDecl}?\s*\?>/
  SystemLiteral_C = /"([^"]*)"|'([^']*)'/
  PubidLiteral_C = %r{"([\sa-zA-Z0-9\-'()+,./:=?;!*\#@$_%]*)"|'([\sa-zA-Z0-9\-()+,./:=?;!*\#@$_%]*)'}
  ExternalID_C = /(?:SYSTEM|PUBLIC\s+#{PubidLiteral_C})(?:\s+#{SystemLiteral_C})?/
  DocType_C = /<!DOCTYPE\s+(#{NameExp})(?:\s+#{ExternalID_C})?\s*(?:\[.*?\]\s*)?>/m
  DocType = DocType_C.disable_capture

  WebAPPDevelopHost = ENV['WEBAPP_DEVELOP_HOST']

  def initialize(manager, request, response) # :nodoc:
    @manager = manager
    @request = request
    @request_header = request.header_object
    @request_body = request.body_object
    @response = response
    @response_header = response.header_object
    @response_body = response.body_object
    @urigen = URIGen.new('http', # xxx: https?
      @request.server_name, @request.server_port,
      File.dirname(@request.script_name), @request.path_info)
  end

  def <<(str) @response_body << str end
  def print(*strs) @response_body.print(*strs) end
  def printf(fmt, *args) @response_body.printf(fmt, *args) end
  def putc(ch) @response_body.putc ch end
  def puts(*strs) @response_body.puts(*strs) end
  def write(str) @response_body.write str end

  def each_request_header(&block) # :yields: field_name, field_body
    @request_header.each(&block)
  end
  def get_request_header(field_name) @request_header[field_name] end

  def request_method() @request.request_method end
  def request_body() @request_body.string end
  def server_name() @request.server_name end
  def server_port() @request.server_port end
  def script_name() @request.script_name end
  def path_info() @request.path_info end
  def query_string() @request.query_string end
  def server_protocol() @request.server_protocol end
  def remote_addr() @request.remote_addr end
  def request_content_type() @request.content_type end
  def request_uri() @request.request_uri end
  def action_uri() @request.action_uri end

  def _GET() 
    unless @_get_vars
      @_get_vars = {}
      query_html_get_application_x_www_form_urlencoded.each do |k, v|
        v.gsub!( /\r\n/, "\n" ) if defined? v.gsub!
        @_get_vars[k] = v
      end
    end
    @_get_vars
  end

  def _POST()
    unless @_post_vars
      @_post_vars = {}
      query_html_post_application_x_www_form_urlencoded.each do |k, v|
        v.gsub!( /\r\n/, "\n" ) if defined? v.gsub!
        @_post_vars[k] = v
      end
    end
    @_post_vars
  end

  def set_header(field_name, field_body) @response_header.set(field_name, field_body) end
  def add_header(field_name, field_body) @response_header.add(field_name, field_body) end
  def remove_header(field_name) @response_header.remove(field_name) end
  def clear_header() @response_header.clear end
  def has_header?(field_name) @response_header.has?(field_name) end
  def get_header(field_name) @response_header[field_name] end
  def each_header(&block) # :yields: field_name, field_body
    @response_header.each(&block)
  end

  def content_type=(media_type)
    @response_header.set 'Content-Type', media_type
  end
  def content_type
    @response_header['Content-Type']
  end

  # returns a Pathname object.
  # _path_ is interpreted as a relative path from the directory
  # which a web application exists.
  #
  # If /home/user/public_html/foo/bar.cgi is a web application which
  # WebApp {} calls, webapp.resource_path("baz") returns a pathname points to
  # /home/user/public_html/foo/baz.
  #
  # _path_ must not have ".." component and must not be absolute.
  # Otherwise ArgumentError is raised.
  def resource_path(arg)
    path = Pathname.new(arg)
    raise ArgumentError, "absolute path: #{arg.inspect}" if !path.relative?
    path.each_filename {|f|
      raise ArgumentError, "path contains .. : #{arg.inspect}" if f == '..'
    }
    @manager.resource_basedir + path
  end

  # call-seq:
  #   open_resource(path)
  #   open_resource(path) {|io| ... }
  #
  # opens _path_ as relative from a web application directory.
  def open_resource(path, &block) 
    resource_path(path).open(&block)
  end

  # call-seq:
  #   send_resource(path)
  #
  # send the resource indicated by _path_.
  # Last-Modified: and If-Modified-Since: header is supported.
  def send_resource(path)
    path = resource_path(path)
    begin
      mtime = path.mtime
    rescue Errno::ENOENT
      send_not_found "Resource not found: #{path}"
      return
    end
    check_last_modified(path.mtime) {
      path.open {|f|
        @response_body << f.read
      }
    }
  end

  def send_not_found(msg)
    @response.status_line = '404 Not Found'
    @response_body << <<End
<html>
  <head><title>404 Not Found</title></head>
  <body>
    <h1>404 Not Found</h1>
    <p>#{msg}</p>
    <hr />
    <small><a href="http://hobix.com/">hobix</a> #{ Hobix::VERSION } / <a href="http://docs.hobix.com">docs</a> / <a href="http://let.us.all.hobix.com">wiki</a> / <a href="http://google.com/search?q=hobix+#{ URI.escape action_uri }">search google for this action</a></small>
  </body>
</html>
End
  end

  def check_last_modified(last_modified)
    if ims = @request_header['If-Modified-Since'] and
       ((ims = Time.httpdate(ims)) rescue nil) and
       last_modified <= ims
      @response.status_line = '304 Not Modified'
      return
    end
    @response_header.set 'Last-Modified', last_modified.httpdate
    yield
  end

  # call-seq:
  #   reluri(:script=>string, :path_info=>string, :query=>query, :fragment=>string) -> URI
  #   make_relative_uri(:script=>string, :path_info=>string, :query=>query, :fragment=>string) -> URI
  # 
  # make_relative_uri returns a relative URI which base URI is the URI the
  # web application is invoked.
  #
  # The argument should be a hash which may have following components.
  # - :script specifies script_name relative from the directory containing
  #   the web application script.
  #   If it is not specified, the web application itself is assumed.
  # - :path_info specifies path_info component for calling web application.
  #   It should begin with a slash.
  #   If it is not specified, "" is assumed.
  # - :query specifies query a component.
  #   It should be a Hash or a WebApp::QueryString.
  # - :fragment specifies a fragment identifier.
  #   If it is not specified, a fragment identifier is not appended to
  #   the result URL.
  #
  # Since the method escapes the components properly,
  # you should specify them in unescaped form.
  #
  # In the example follow, assume that the web application bar.cgi is invoked
  # as http://host/foo/bar.cgi/baz/qux.
  #
  #   webapp.reluri(:path_info=>"/hoge") => URI("../hoge")
  #   webapp.reluri(:path_info=>"/baz/fuga") => URI("fuga")
  #   webapp.reluri(:path_info=>"/baz/") => URI("./")
  #   webapp.reluri(:path_info=>"/") => URI("../")
  #   webapp.reluri() => URI("../../bar.cgi")
  #   webapp.reluri(:script=>"funyo.cgi") => URI("../../funyo.cgi")
  #   webapp.reluri(:script=>"punyo/gunyo.cgi") => URI("../../punyo/gunyo.cgi")
  #   webapp.reluri(:script=>"../genyo.cgi") => URI("../../../genyo.cgi")
  #   webapp.reluri(:fragment=>"sec1") => URI("../../bar.cgi#sec1")
  #)
  #   webapp.reluri(:path_info=>"/h?#o/x y") => URI("../h%3F%23o/x%20y")
  #   webapp.reluri(:script=>"ho%o.cgi") => URI("../../ho%25o.cgi")
  #   webapp.reluri(:fragment=>"sp ce") => URI("../../bar.cgi#sp%20ce")
  #
  def make_relative_uri(hash={})
    @urigen.make_relative_uri(hash)
  end
  alias reluri make_relative_uri

  # call-seq:
  #   make_absolute_uri(:script=>string, :path_info=>string, :query=>query, :fragment=>string) -> URI
  # 
  # make_absolute_uri returns a absolute URI which base URI is the URI of the
  # web application is invoked.
  #
  # The argument is same as make_relative_uri.
  def make_absolute_uri(hash={})
    @urigen.make_absolute_uri(hash)
  end
  alias absuri make_absolute_uri

  # :stopdoc:
  StatusMessage = { # RFC 2616
    100 => 'Continue',
    101 => 'Switching Protocols',
    200 => 'OK',
    201 => 'Created',
    202 => 'Accepted',
    203 => 'Non-Authoritative Information',
    204 => 'No Content',
    205 => 'Reset Content',
    206 => 'Partial Content',
    300 => 'Multiple Choices',
    301 => 'Moved Permanently',
    302 => 'Found',
    303 => 'See Other',
    304 => 'Not Modified',
    305 => 'Use Proxy',
    307 => 'Temporary Redirect',
    400 => 'Bad Request',
    401 => 'Unauthorized',
    402 => 'Payment Required',
    403 => 'Forbidden',
    404 => 'Not Found',
    405 => 'Method Not Allowed',
    406 => 'Not Acceptable',
    407 => 'Proxy Authentication Required',
    408 => 'Request Timeout',
    409 => 'Conflict',
    410 => 'Gone',
    411 => 'Length Required',
    412 => 'Precondition Failed',
    413 => 'Request Entity Too Large',
    414 => 'Request-URI Too Long',
    415 => 'Unsupported Media Type',
    416 => 'Requested Range Not Satisfiable',
    417 => 'Expectation Failed',
    500 => 'Internal Server Error',
    501 => 'Not Implemented',
    502 => 'Bad Gateway',
    503 => 'Service Unavailable',
    504 => 'Gateway Timeout',
    505 => 'HTTP Version Not Supported',
  }
  # :startdoc:

  # setup_redirect makes a status line and a Location header appropriate as
  # redirection.
  #
  # _status_ specifies the status line.
  # It should be a Fixnum 3xx or String '3xx ...'.
  #
  # _uri_ specifies the Location header body.
  # It should be a URI, String or Hash.
  # If a Hash is given, make_absolute_uri is called to convert to URI.
  # If given URI is relative, it is converted as absolute URI.
  def setup_redirection(status, uri)
    case status
    when Fixnum
      if status < 300 || 400 <= status
        raise ArgumentError, "unexpected status: #{status.inspect}"
      end
      status = "#{status} #{StatusMessage[status]}"
    when String
      unless /\A3\d\d(\z| )/ =~ status
        raise ArgumentError, "unexpected status: #{status.inspect}"
      end
      if status.length == 3
        status = "#{status} #{StatusMessage[status.to_i]}"
      end
    else
      raise ArgumentError, "unexpected status: #{status.inspect}"
    end
    case uri
    when URI
      uri = @urigen.base_uri + uri if uri.relative?
    when String
      uri = URI.parse(uri)
      uri = @urigen.base_uri + uri if uri.relative?
    when Hash
      uri = make_absolute_uri(uri)
    else
      raise ArgumentError, "unexpected uri: #{uri.inspect}"
    end
    @response.status_line = status
    @response_header.set 'Location', uri.to_s
  end

  def query_html_get_application_x_www_form_urlencoded
    @request.query_string.decode_as_application_x_www_form_urlencoded
  end

  def query_html_post_application_x_www_form_urlencoded
    if /\Apost\z/i =~ @request.request_method # xxx: should not check?
      q = QueryString.primitive_new_for_raw_query_string(@request.body_object.read)
      if %r|\Amultipart/form-data.*boundary=\"?([^\";,]+)\"?|n.match(request_content_type)
        boundary = $1.dup 
        q.decode_as_multipart_form_data boundary
      else
        q.decode_as_application_x_www_form_urlencoded
      end
    else
      # xxx: warning?
      HTMLFormQuery.new
    end
  end

  class QueryValidationFailure < StandardError
  end

  # QueryString represents a query component of URI.
  class QueryString
    class << self
      alias primitive_new_for_raw_query_string new
      undef new
    end

    def initialize(escaped_query_string)
      @escaped_query_string = escaped_query_string
    end

    def inspect
      "#<#{self.class}: #{@escaped_query_string}>"
    end
    alias to_s inspect
  end

  # :stopdoc:
  def WebApp.make_frozen_string(str)
    raise ArgumentError, "not a string: #{str.inspect}" unless str.respond_to? :to_str
    str = str.to_str
    str = str.dup.freeze unless str.frozen?
    str
  end

  LoadedWebAppProcedures = {}
  def WebApp.load_webapp_procedure(path)
    unless LoadedWebAppProcedures[path]
      begin
        Thread.current[:webapp_delay] = true
        load path, true
        LoadedWebAppProcedures[path] = Thread.current[:webapp_proc]
      ensure
        Thread.current[:webapp_delay] = nil
        Thread.current[:webapp_proc] = nil
      end
    end
    unless LoadedWebAppProcedures[path]
      raise RuntimeError, "not a web application: #{path}"
    end
    LoadedWebAppProcedures[path]
  end

  def WebApp.run_webapp_via_stub(path)
    if Thread.current[:webrick_load_servlet]
      load path, true
      return
    end
    WebApp.load_webapp_procedure(path).call
  end

  class Manager
    def initialize(app_block)
      @app_block = app_block
      @resource_basedir = Pathname.new(eval("__FILE__", app_block)).dirname
    end
    attr_reader :resource_basedir

    # CGI, Esehttpd
    def run_cgi
      setup_request = lambda {|req|
        req.make_request_header_from_cgi_env(ENV)
        if ENV.include?('CONTENT_LENGTH')
          len = ENV['CONTENT_LENGTH'].to_i
          req.body_object << $stdin.read(len)
        end
      }
      output_response = lambda {|res|
        res.output_cgi_status_field($stdout)
        res.output_message($stdout)
      }
      primitive_run(setup_request, output_response)
    end

    # FastCGI
    def run_fcgi
      require 'fcgi'
      FCGI.each_request {|fcgi_request|
        setup_request = lambda {|req|
          req.make_request_header_from_cgi_env(fcgi_request.env)
          if content = fcgi_request.in.read
            req.body_object << content
          end
        }
        output_response =  lambda {|res|
          res.output_cgi_status_field(fcgi_request.out)
          res.output_message(fcgi_request.out)
          fcgi_request.finish
        }
        primitive_run(setup_request, output_response)
      }
    end

    # mod_ruby with Apache::RubyRun
    def run_rbx
      rbx_request = Apache.request
      setup_request = lambda {|req|
        req.make_request_header_from_cgi_env(rbx_request.subprocess_env)
        if content = rbx_request.read
          req.body_object << content
        end
      }
      output_response =  lambda {|res|
        rbx_request.status_line = "#{res.status_line}"
        res.header_object.each {|k, v|
          case k
          when /\AContent-Type\z/i
            rbx_request.content_type = v
          else
            rbx_request.headers_out[k] = v
          end
        }
        rbx_request.write res.body_object.string
      }
      primitive_run(setup_request, output_response)
    end

    # WEBrick with webapp/webrick-servlet.rb
    def run_webrick
      Thread.current[:webrick_load_servlet] = lambda {|webrick_req, webrick_res|
        setup_request = lambda {|req|
          req.make_request_header_from_cgi_env(webrick_req.meta_vars)
          webrick_req.body {|chunk|
            req.body_object << chunk
          }
        }
        output_response =  lambda {|res|
          webrick_res.status = res.status_line.to_i
          res.header_object.each {|k, v|
            webrick_res[k] = v
          }
          webrick_res.body = res.body_object.string
        }
        primitive_run(setup_request, output_response)
      }
    end

    def primitive_run(setup_request, output_response)
      req = Request.new
      res = Response.new
      trap_exception(req, res) {
        setup_request.call(req)
        req.freeze
        req.body_object.rewind
        webapp = WebApp.new(self, req, res)
        @app_block.call(webapp)
        complete_response(webapp, res)
      }
      output_response.call(res)
    end

    def complete_response(webapp, res)
      unless res.header_object.has? 'Content-Type'
        case res.body_object.string
        when /\A\z/
          content_type = nil
        when /\A\211PNG\r\n\032\n/
          content_type = 'image/png'
        when /\A#{XmlDecl_C}\s*#{DocType_C}/io
          charset = $3 || $4
          rootelem = $7
          content_type = make_xml_content_type(rootelem, charset)
        when /\A#{XmlDecl_C}\s*<(#{NameExp})[\s>]/io
          charset = $3 || $4
          rootelem = $7
          content_type = make_xml_content_type(rootelem, charset)
        when /\A<html[\s>]/io
          content_type = 'text/html'
        when /\0/
          content_type = 'application/octet-stream'
        else
          content_type = 'text/plain'
        end
        res.header_object.set 'Content-Type', content_type if content_type
      end
      gzip_content(webapp, res) unless res.header_object.has? 'Content-Encoding'
      unless res.header_object.has? 'Content-Length'
        res.header_object.set 'Content-Length', res.body_object.length.to_s
      end
    end

    def gzip_content(webapp, res, level=nil)
      # xxx: parse the Accept-Encoding field body
      if accept_encoding = webapp.get_request_header('Accept-Encoding') and
         /gzip/ =~ accept_encoding and
         /\A\037\213/ !~ res.body_object.string # already gzipped
        level ||= Zlib::DEFAULT_COMPRESSION
        content = res.body_object.string
        Zlib::GzipWriter.wrap(StringIO.new(gzipped = ''), level) {|gz|
          gz << content
        }
        if gzipped.length < content.length
          content.replace gzipped
          res.header_object.set 'Content-Encoding', 'gzip'
        end
      end
    end

    def make_xml_content_type(rootelem, charset)
      case rootelem
      when /\Ahtml\z/i
        result = 'text/html'
      else
        result = 'application/xml'
      end
      result << "; charset=\"#{charset}\"" if charset
      result
    end

    def trap_exception(req, res)
      begin
        yield
      rescue Exception => e
        if devlopper_host? req.remote_addr
          generate_debug_page(req, res, e)
        else
          generate_error_page(req, res, e)
        end
      end
    end

    def devlopper_host?(addr)
      return true if addr == '127.0.0.1'
      return false if %r{\A(\d+)\.(\d+)\.(\d+)\.(\d+)\z} !~ addr
      addr_arr = [$1.to_i, $2.to_i, $3.to_i, $4.to_i]
      addr_bin = addr_arr.pack("CCCC").unpack("B*")[0]
      case WebAPPDevelopHost
      when %r{\A(\d+)\.(\d+)\.(\d+)\.(\d+)\z}
        dev_arr = [$1.to_i, $2.to_i, $3.to_i, $4.to_i]
        return true if dev_arr == addr_arr
      when %r{\A(\d+)\.(\d+)\.(\d+)\.(\d+)/(\d+)\z}
        dev_arr = [$1.to_i, $2.to_i, $3.to_i, $4.to_i]
        dev_bin = dev_arr.pack("CCCC").unpack("B*")[0]
        dev_len = $5.to_i
        return true if addr_bin[0, dev_len] == dev_bin[0, dev_len]
      end
      return false
    end

    def generate_error_page(req, res, exc)
      backtrace = "#{exc.message} (#{exc.class})\n"
      exc.backtrace.each {|f| backtrace << f << "\n" }
      res.status_line = '500 Internal Server Error'
      header = res.header_object
      header.clear
      header.add 'Content-Type', 'text/html'
      body = res.body_object
      body.rewind
      body.truncate(0)
      body.puts <<'End'
<html><head><title>500 Internal Server Error</title></head>
<body><h1>500 Internal Server Error</h1>
<p>The dynamic page you requested is failed to generate.</p></body>
</html>
End
    end

    def generate_debug_page(req, res, exc)
      backtrace = "#{exc.message} (#{exc.class})\n"
      exc.backtrace.each {|f| backtrace << f << "\n" }
      res.status_line = '500 Internal Server Error'
      header = res.header_object
      header.clear
      header.add 'Content-Type', 'text/plain'
      body = res.body_object
      body.rewind
      body.truncate(0)
      body.puts backtrace
    end
  end
  # :startdoc:
end

# WebApp is a main routine of web application.
# It should be called from a toplevel of a CGI/FastCGI/mod_ruby/WEBrick script.
#
# WebApp is used as follows.
#
#   #!/usr/bin/env ruby
#   
#   require 'webapp'
#   
#   ... class/method definitions ... # run once per process.
#   
#   WebApp {|webapp| # This block runs once per request.
#     ... process a request ...
#   }
#
# WebApp yields with an object of the class WebApp.
# The object contains request and response.
#
# WebApp rise $SAFE to 1.
#
# WebApp catches all kind of exception raised in the block.
# If HTTP connection is made from localhost or a developper host,
# the backtrace is sent back to the browser.
# Otherwise, the backtrace is sent to stderr usually which is redirected to
# error.log.
# The developper hosts are specified by the environment variable 
# WEBAPP_DEVELOP_HOST.
# It may be an IP address such as "111.222.333.444" or
# an network address such as "111.222.333.0/24".
# (An environment variable for CGI can be set by SetEnv directive in Apache.)
#
def self.WebApp(&block) # :yields: webapp
  $SAFE = 1 if $SAFE < 1
  manager = WebApp::Manager.new(block)
  if defined?(Apache::Request) && Apache.request.kind_of?(Apache::Request)
    run = lambda { manager.run_rbx }
  elsif Thread.current[:webrick_load_servlet]
    run = lambda { manager.run_webrick }
  elsif STDIN.respond_to?(:stat) && STDIN.stat.socket? &&
        begin
          # getpeername(FCGI_LISTENSOCK_FILENO) causes ENOTCONN on FastCGI
          # cf. http://www.fastcgi.com/devkit/doc/fcgi-spec.html
          require 'socket'
          sock = Socket.for_fd(0)
          sock.getpeername
          false
        rescue Errno::ENOTCONN
          true
        rescue SystemCallError
          false
        end
    run = lambda { manager.run_fcgi }
  elsif ENV.include?('REQUEST_METHOD')
    run = lambda { manager.run_cgi }
  else
    require 'hobix/webapp/cli'
    run = lambda { manager.run_cli }
  end
  if Thread.current[:webapp_delay]
    Thread.current[:webapp_proc] = run
  else
    run.call
  end
end
end
