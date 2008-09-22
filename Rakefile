require 'rake'
require 'rake/clean'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'fileutils'
include FileUtils

NAME = "hobix"
VERS = "0.6"
CLEAN.include ['**/.*.sw?', '*.gem', '.config']
RDOC_OPTS = ['--quiet', '--title', "The Book of Hobix",
    # "--template", "extras/flipbook_rdoc.rb",
    "--opname", "index.html",
    "--line-numbers", 
    "--main", "README",
    "--inline-source"]

desc "Packages up Hobix."
task :default => [:package]
task :package => [:clean]

task :doc => [:rdoc, :after_doc]

Rake::RDocTask.new do |rdoc|
    rdoc.rdoc_dir = 'doc/rdoc'
    rdoc.options += RDOC_OPTS
    # rdoc.template = "extras/flipbook_rdoc.rb"
    rdoc.main = "README"
    rdoc.title = "The Book of Hobix"
    rdoc.rdoc_files.add ['README', 'doc/CHANGELOG', 'COPYING', 'lib/hobix.rb', 'lib/hobix/*.rb']
end

task :after_doc do
    # cp "extras/Camping.gif", "doc/rdoc/"
    # cp "extras/permalink.gif", "doc/rdoc/"
    sh %{scp -r doc/rdoc/* #{ENV['USER']}@rubyforge.org:/var/www/gforge-projects/hobix/}
end

spec =
    Gem::Specification.new do |s|
        s.name = NAME
        s.version = VERS
        s.platform = Gem::Platform::RUBY
        s.has_rdoc = true
        s.extra_rdoc_files = ["README", "doc/CHANGELOG", "COPYING"]
        s.rdoc_options += RDOC_OPTS + ['--exclude', '^(contrib)\/']
        s.summary = "the white pantsuit of weblahhing"
        s.description = s.summary
        s.author = "why the lucky stiff"
        s.email = 'why@ruby-lang.org'
        s.homepage = 'http://hobix.com'
        s.executables = ['hobix']

        s.add_dependency('RedCloth')
        s.required_ruby_version = '>= 1.8.2'

        s.files = %w(COPYING README Rakefile git_hobix_update.php) +
          Dir.glob("{bin,doc,test,share,lib,contrib}/**/*") + 
          Dir.glob("ext/**/*.{h,c,rb}") +
          Dir.glob("examples/**/*.rb")
        
        s.require_path = "lib"
        # s.extensions = FileList["ext/**/extconf.rb"].to_a
        s.bindir = "bin"
    end

Rake::GemPackageTask.new(spec) do |p|
    p.need_tar = true
    p.need_zip = true
    p.gem_spec = spec
end

task :install do
  sh %{rake gem}
  sh %{gem install pkg/#{NAME}-#{VERS}}
end

task :uninstall => [:clean] do
  sh %{gem uninstall #{NAME}}
end
