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
attached = {}
['../redcloth/lib/**/*.rb', 'lib/**/*.rb', 'bin/**/*', 'share/**/*', 'run-tests.rb'].collect do |dirglob|
    Dir.glob(dirglob)
end.flatten.each do |item| 
    next if item.include?("CVS") or File.directory? item
    attached[item.gsub( /^\.\.\/\w+\//, '' )] = Base64::encode64( File.read( item ) )
end
hobix_install_yaml =<<EOY
version: #{ check_hobix_version( 'lib', 'hobix.rb' ) }
setup:
- - welcome
  - |-
    #

                                   () ()
                                    () ()
                   o --- (--=   _--_ /    \\
                 o( -- (---=  ~/     / ^ ^/
              o. (___ (_(__-=  //  ///\\/\\/

                  you speedy little goat!!
                    you got.. you got..
                      ahee!! hobix!!

    # halloo!! ready to install the very latest hobix??
    # DON'T BE 'FRAIDY!! nothing scary AT ALL!! (hobix is
    # whizzzy cool and /everyone/ is holding your hand.)

    + ready to go + [Y/n] ?

- - libpath
  - |
    # where would you like to install the libraries??
    # the default is your ruby site libs dir, which is
    # CONFIG['sitelibdir']

    + lib path [ENTER for default] +

- - binpath
  - |
    # where would you like to install the hobix
    # command-line tool?? the default is
    # CONFIG['bindir']

    + cmd path [ENTER for default] +

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

EOY

hobix_install_yaml += attached.to_yaml( :UseBlock => true, :UseFold => false )

File.open( 'go/hobix-install.yaml', 'w' ) do |hiy|
    hiy << hobix_install_yaml
end
