module Hobix

 class Weblog 
    def skel_tags( path_storage ) 
      # Get a list of all known tags
      tags = path_storage.find( :all => true ).map { |e| e.tags }.flatten.uniq
      
      tags.each do |tag|
        entries = path_storage.find.find_all { |e| e.tags.member? tag }
        page = Page.new( File::join('tags',tag,'index' ) )
        page.updated = path_storage.last_modified( entries ) 
        yield :page => page, :entries => entries
      end
    end
 end 

end 

