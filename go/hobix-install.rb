#!/usr/local/bin/ruby
#
#                                         |    | .
#                                       * |/\()|)|>< *
#
#                             .[ there goes your wife and kids ].
#
#
# To install Hobix from this location:
#
#   ruby -ropen-uri -e 'eval(open("http://go.hobix.com/").read)'
#
# If you have a web proxy, set your HTTP_PROXY environment variable
# to your proxy.
#
require 'base64'
require 'rbconfig'
require 'yaml'
require 'zlib'

c = ::Config::CONFIG
rubypath = c['bindir'] + '/' + c['ruby_install_name']
def die( msg ); puts msg; exit; end
def check_hobix_version( path, version )
    begin
        require File.join( path, 'hobix' )
    rescue LoadError
    end
    begin
        if Hobix::VERSION == version
            die( "* you are already up-to-date * hobix v#{ Hobix::VERSION } installed *" )
        else
            puts "* upgrading from hobix v#{ Hobix::VERSION } to the latest v#{ version }"
        end
    rescue NameError
    end
end
def copy_dir( sucmd, from_dir, to_dir, mode = nil )
    cp = "cp -r #{ from_dir }/* #{ to_dir }"
    Dir[File.join(from_dir, '*')].each { |f| File.chmod mode, f } if mode
    if sucmd == 'su'
        `su root -c '#{ cp }'`
    elsif sucmd == 'sudo'
        `sudo #{ cp }`
    else
        require 'fileutils'
        FileUtils.cp_r Dir.glob( "#{ from_dir }/*" ), to_dir
    end
end
def open_try_gzip( uri, gzip_on = true )
    opts = {}
    opts['Accept-Encoding'] = 'gzip' if gzip_on
    URI::parse( uri ).open( opts ) do |o|
        if o.content_encoding.include?( "gzip" )
            puts "# Beginning gzip transmission."
            Zlib::GzipReader.wrap( o ) do |ogz|
                yield ogz
            end
        else
            puts "# Beginning base64 transmission."
            yield o
        end
    end
end

# Web root
GO_HOBIX = 'http://go.hobix.com/'

# Tempdir
TMPDIR = File.join( ENV['TMPDIR']||ENV['TMP']||ENV['TEMP']||'/tmp', Time.now.strftime( 'hobix_%Y-%m-%d_%H-%M-%S' ) )

# Move through intro screens
puts "# Readying install..."
stream = open_try_gzip( GO_HOBIX + "hobix-install.yaml", c['host'] !~ /mswin32/ ) do |yml| 
    YAML::load_stream( yml )
end
den, attached = stream.documents

conf = {}
den['setup'].each do |action, screen|
    print screen.gsub( /CONFIG\['(\w+)'\]/ ) { conf[action] = c[$1] }.
                 gsub( /^CONF$/ ) { conf.to_yaml }
    break if action == 'complete'
    answer = gets.strip
    if ['welcome', 'installing'].include? action 
        answer.downcase!
        die( "* not a problem * a pleasant day to you *" ) if answer == 'n'
    elsif answer != ''
        conf[action] = answer
    end
    if action == 'libpath'
        check_hobix_version( conf[action], den['version'] )
    elsif action == 'installing'
        puts
        require 'ftools'
        attached.each do |attname, att64|
            puts "creating #{ attname } (#{ att64.length / 1000 }k)..."
            filebin = if Object::const_defined? "Base64"
                          Base64::decode64( att64 )
                      else
                          decode64( att64 )
                      end
            File.makedirs( File.join( TMPDIR, File.dirname( attname ) ) )
            if attname =~ /^bin\/\w+$/
                if c['host'] =~ /mswin32/ 
                    attname += ".rb"
                else
                    filebin.gsub!( /\A#!.+$/, "#!#{ rubypath }" )
                end
            end
            fileloc = File.join( TMPDIR, attname )
            File.open( fileloc, 'wb' ) do |out|
                out << filebin
            end
        end
        copy_dir( conf['sucmd'], File.join( TMPDIR, 'lib' ), conf['libpath'] )
        copy_dir( conf['sucmd'], File.join( TMPDIR, 'bin' ), conf['binpath'], 0755 )
    end
    puts
end

