require 'rubygems'
spec = Gem::Specification.new do |s|
  s.name = 'Hobix'
  s.version = "0.1"
  s.platform = Gem::Platform::RUBY
  s.summary = "Hobix"
#  s.requirements << 'um?'
  s.files = ['tests/**/*', 'lib/**/*', 'bin/**/*'].collect do |dirglob|
                Dir.glob(dirglob)
            end.flatten.delete_if {|item| item.include?("CVS")}
  s.require_path = 'lib'
  s.autorequire = 'hobix'
  s.author = "Why the Lucky Stiff"
  s.email = "why@ruby-lang.org"
# s.rubyforge_project = "redcloth"
  s.homepage = "http://hobix.com/"
end
if $0==__FILE__
p spec
  Gem::Builder.new(spec).build
end
