require 'hobix'
require 'base64'

attached = {}
['../redcloth/lib/**/*.rb', 'lib/**/*.rb', 'bin/**/*', 'run-tests.rb'].collect do |dirglob|
    Dir.glob(dirglob)
end.flatten.each do |item| 
    next if item.include?("CVS") or File.directory? item
    attached[item.gsub( /^\.\.\/\w+\//, '' )] = Base64::encode64( File.read( item ) )
end
hobix_install_yaml =<<EOY
version: #{ Hobix::VERSION.dump }
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

- - complete 
  - |
    # your hobix installation is complete!! to get
    # started, type `hobix'.  if the command-line
    # tool is in your path, you should see a list of
    # hobix actions!!  (here are you configs again:)

    CONF

EOY

hobix_install_yaml += attached.to_yaml( :UseBlock => true, :UseFold => false )

File.open( 'installer/hobix-install.yaml', 'w' ) do |hiy|
    hiy << hobix_install_yaml
end
