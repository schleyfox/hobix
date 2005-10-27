require 'base64'
require 'yaml'

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
    installed
end
def dir_to_base64( *dirs )
    attached = {}
    dirs.collect do |dirglob|
        Dir.glob(dirglob)
    end.flatten.each do |item| 
        next if item.include?("CVS") or File.directory? item
        attached[item.gsub( /^.*(lib|bin|share)\//, '\1/' )] = Base64::encode64( File.read( item ) )
    end
    attached
end
attached = dir_to_base64( '../RedCloth-3.0.3/lib/redcloth.rb', 'lib/**/*.rb', 'bin/**/*', 'share/**/*' )
hobix_install_yaml =<<EOY
version: #{ check_hobix_version( 'lib', 'hobix.rb' ) }
setup:
- - welcome
  - |-
    #
                                       _               
        .        ()_'() ``,``-`-`.    (*`
           *    (      )       , \\`       .
         __ _. (  ^  ^  )  `'      .`  _ __  __
        /  ^  ^ )      (   .,___,   ,;/ ^  `'
       ````````` U|  |U . |      |. |^`````````
               >_`  -| |^ |      |^ |
                 `---' ^^^'      ^^^'

                  you slow elephant.

                  but you got hobix.

                        ahee.

    # halloo!! ready to install the very latest hobix??
    # DON'T BE 'FRAIDY!! nothing scary AT ALL!! (hobix is
    # whizzzy cool and /everyone/ is holding your hand.)

    + ready to go + [Y/n] ?

- - sitelibdir
  - |
    # where would you like to install the libraries??
    # the default is your ruby site libs dir, which is
    # CONFIG['sitelibdir']

    + lib path [ENTER for default] +

- - bindir
  - |
    # where would you like to install the hobix
    # command-line tool?? the default is
    # CONFIG['bindir']

    + cmd path [ENTER for default] +

- - sharedir
  - |
    # where would you like to install the hobix
    # accessory data?? (this includes the default
    # blogging templates.)  the default is
    # CONFIG['sharedir']
    
    + share path [ENTER for default] +

- - sucmd
  - |-
    # will you be using su or sudo??  this way you can
    # install hobix without being logged in as root.
    # (windows users: skip this step!!)

    + su or sudo + [su/sudo/NONE] ?

- - installing
  - |-
    # here's your setup options

    CONF

    + all set + [Yn] ?

- - setup
  - |-
    # brilliant, it's all installed.  would you like to setup your hobix
    # configuration now??  (if not, you can use `hobix setup_blogs' at your
    # convenience.

    + setup your blogs + [Yn] ? 

- - complete 
  - |
    # your hobix installation is complete!! to get
    # started, type `hobix'.  if the command-line
    # tool is in your path, you should see a list of
    # hobix actions!!  (here are you configs again:)

    CONF

    # See hobix.com for a tutorial on using your new Hobix blogs!!  And
    # when you have your blog up, let everybody know at let.us.all.hobix.com,
    # okay?? great, thanks.

---
EOY

hobix_install_yaml += attached.to_yaml( :UseBlock => true, :UseFold => false )

File.open( 'go/hobix-install.yaml', 'w' ) do |hiy|
    hiy << hobix_install_yaml
end

win32_att = dir_to_base64( 'win32/lib/**/*' )
File.open( 'go/hobix-install-win32.yaml', 'w' ) do |hiw|
    hiw << win32_att.to_yaml( :UseBlock => true, :UseFold => false )
end
