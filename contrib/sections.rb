## sections.rb -- Hobix section map plugin
## (c) 2004, 2005 William Morgan. This file is released under the GNU
## Public License.
##
## Contributors: Frederick Ros, Eric Stewart, Jeremy Hinegardner
##
## USAGE: place this file in your $HOBIXROOT/lib directory. Then, in
## your $HOBIXROOT/hobix.yaml file (or by running 'hobix edit'), add
## 'sections' to the 'required' block, like this:
## 
## [...]
## required:
##   - sections
##
## Finally, add 'sidebar_section_list' to the 'sidebar_list' property
## of hobix/out/quick, like this:
##
## hobix/out/quick: 
##   sidebar_list: 
##      - sidebar_section_map
##
## Voila, your sidebar will display a section map when you next do a
## regen. Note that the default Hobix CSS doesn't indent lists, so the
## hierarchy is lost upon display. I'm not a CSS expert, but I changed
## the sidebarBox ul section in site.css to this and it was better:
##
## .sidebarBox ul {
##     margin:7px;
##     padding:0px;
## }
##
## Good luck. -- William <wmorgan-section_map-hobix@masanjin.net>

class Hobix::Out::Quick
  def section_list(entries, topname="top level")
    counts = {}
    entries.each do |entry|
      path = (entry.id.split("/")[0 ... -1] || []) # nil in ruby 1.8.1 if path is ""
      counts[path] = 1 + (counts[path] || 0)
    end

    list = []; seen = {}
    counts[[]] ||= 0 # force the root
    counts.sort.each do |path, count|
      if path == []
        list.push [topname, "", 0, counts[path]]        
      else
        path.inject(".") do |s, x|
          prefix = s + "/" + x
          unless seen[prefix]
            length = prefix.count '/'
            list.push [x, prefix, length, (length == path.length ? count : 0)]
            seen[prefix] = true
          end
          prefix
        end
      end
    end
    list
  end

  def sidebar_section_map_erb
  %q{
    <div class="sidebarBox">
    <h2 class="sidebarTitle">Sections</h2>
    <% curlev = -1 %>
    <% section_list(weblog.storage.find).each do |name, path, lev, num| %>
      <% if (lev > curlev) %>
        <% (lev - curlev).times do %> <ul> <% end %>
      <% else # less than or equal %>
        </li>
      <% end %>
      <% if (curlev > lev) %>
        <% (curlev - lev).times do %> </ul></li> <% end %>
      <% end %>

      <% curlev = lev %>
      <li>
        <a href="<%= weblog.expand_path path %>"><%= name %></a><% if num != 0 then %>: <%= num %> <% end %>
    <% end %>
    <% (curlev + 1).times do %>
      </li></ul>
    <% end %>
    </div>
  }
  end
end
