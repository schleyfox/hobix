## sections.rb -- Hobix section list plugin
##
## Displays a list of all the sections of your blog.
##
## USAGE:
##
## 1) In hobix.yaml (e.g. by running 'hobix edit <blogname>'), simply
##    add 'hobix/plugin/sections' to the 'required' list, as follows:
##
## required:
##   - hobix/plugin/sections
##
##    And that's it!
##
## NOTES:
##
## 1) If you redefine 'sidebar_list' in hobix.yaml, you'll need to
##    explicitly add a 'sidebar_section_list' item.
## 2) The default Hobix CSS doesn't indent lists, so the hierarchy is 
##    lost upon display. You can add something like this to your CSS file
##    to fix this:
##
## .sidebarBox ul {
##     margin:7px;
##     padding:0px;
## }

class Hobix::Out::Quick
  def section_list( entries, topname = "top level" )
    counts = {}
    entries.each do |entry|
      path = ( entry.id.split("/")[0 ... -1] || [] ) # nil in ruby 1.8.1 if path is ""
      counts[path] = 1 + ( counts[path] || 0 )
    end

    list = []; seen = {}
    counts[[]] ||= 0 # force the root
    counts.sort.each do |path, count|
      if path == []
        list.push [topname, "", 0, counts[path]]        
      else
        path.inject( "." ) do |s, x|
          prefix = s + "/" + x
          unless seen[prefix]
            length = prefix.count '/'
            list.push [x, prefix, length, ( length == path.length ? count : 0 ) ]
            seen[prefix] = true
          end
          prefix
        end
      end
    end
    list
  end

  def sidebar_section_list_erb
  %q{
    <div class="sidebarBox">
    <h2 class="sidebarTitle">Sections</h2>
    <% curlev = -1 %>
    <% section_list( weblog.storage.find ).each do |name, path, lev, num| %>
      <% if ( lev > curlev ) %>
        <% ( lev - curlev ).times do %> <ul> <% end %>
      <% else # less than or equal %>
        </li>
      <% end %>
      <% if ( curlev > lev ) %>
        <% ( curlev - lev ).times do %> </ul></li> <% end %>
      <% end %>

      <% curlev = lev %>
      <li>
        <a href="<%= weblog.expand_path path %>"><%= name %></a><% if num != 0 then %>: <%= num %> <% end %>
    <% end %>
    <% ( curlev + 1 ).times do %>
      </li></ul>
    <% end %>
    </div>
  }
  end

  alias sections_old_sidebar_list_erb sidebar_list_erb
  def sidebar_list_erb
    l = sections_old_sidebar_list_erb
    if l.last == "sidebar_hobix"
      l[0 ... (l.length - 1)] + ['sidebar_section_list', 'sidebar_hobix']
    else
      l + ['sidebar_section_list']
    end
  end
end
