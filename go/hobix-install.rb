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
sharepath = c['prefix'] + '/share/hobix'
def die( msg ); puts msg; exit; end
def check_hobix_version( path, version )
    installed = nil
    hobixfile = File.join( path, 'hobix.rb' )
    if File.exists? hobixfile
        File.open( hobixfile ) do |f|
            f.grep( /VERSION\s+=\s+'([^']+)'/ ) do |line|
                installed = $1
            end
        end
    end
    if installed == version
        die( "* you are already up-to-date * hobix v#{ installed } installed *" )
    else
        puts "* upgrading from hobix v#{ installed } to the latest v#{ version }"
    end
end
def clean_dir( sucmd, to_dir )
    rm = "rm -rf #{ to_dir }"
    mk = "mkdir #{ to_dir }"
    if sucmd == 'su'
        `su root -c #{ rm }`
        `su root -c #{ mk }`
    elsif sucmd == 'sudo'
        `sudo #{ rm }`
        `sudo #{ mk }`
    else
        require 'fileutils'
        FileUtils.rm_rf to_dir
        FileUtils.mkdir_p to_dir
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
def ri_install( sucmd, libdir )
    begin
        require 'rdoc/rdoc'
        ri_site = true
        if RDOC_VERSION =~ /^0\./
            require 'rdoc/options'
            unless Options::OptionList::OPTION_LIST.assoc('--ri-site')
                ri_site = false
            end
        end
        if ri_site
            ricmd = "rdoc --ri-site --all \"#{ libdir }\""
            if sucmd == 'su'
                `su root -c '#{ ricmd }'`
            elsif sucmd == 'sudo'
                `sudo #{ ricmd }`
            else
                RDoc::RDoc.new.document(["--ri-site", "--all", libdir])
            end
        end
    rescue
        puts "** Unable to install Ri documentation for Hobix **"
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
execs = {}
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
    case action
    when 'libpath'
        check_hobix_version( conf[action], den['version'] )
    when 'installing'
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
            case attname
            when /^bin\//
                attfile = $'
                if c['host'] =~ /mswin32/ 
                    batfile = File.join( TMPDIR, attname + ".bat" )
                    File.open( batfile, 'wb' ) do |out|
                        out << "@echo off\r\n\"#{ conf['binpath'] }/ruby.exe\" \"#{ conf['binpath'] }/#{ attfile }\" %1 %2 %3 %4 %5 %6 %7 %8 %9\r\n"
                    end
                    execs[attfile] = File.join( conf['binpath'], attfile + ".bat" )
                else
                    filebin.gsub!( /\A#!.+$/, "#!#{ rubypath }" )
                    execs[attfile] = File.join( conf['binpath'], attfile )
                end
            when "lib/hobix.rb"
                filebin.gsub!( /^(\s*)SHARE_PATH = (.*)$/, "\\1SHARE_PATH = #{ sharepath.dump }" )
            end
            fileloc = File.join( TMPDIR, attname )
            File.open( fileloc, 'wb' ) do |out|
                out << filebin
            end
        end
        copy_dir( conf['sucmd'], File.join( TMPDIR, 'lib' ), conf['libpath'] )
        clean_dir( conf['sucmd'], sharepath )
        copy_dir( conf['sucmd'], File.join( TMPDIR, 'share' ), sharepath )
        copy_dir( conf['sucmd'], File.join( TMPDIR, 'bin' ), conf['binpath'], 0755 )
        ri_install( conf['sucmd'], File.join( TMPDIR, 'lib' ) )
    when 'setup'
        # Load new Hobix classes
        if conf['setup'].to_s.downcase != 'n'
            require 'hobix/commandline'
            cmdline = Class.new
            cmdline.extend Hobix::CommandLine
            puts "# Configuration stored in #{ Hobix::CommandLine::RC }"
            cmdline.login
            cmdline.setup_blogs
        end
    end
    puts
end


