## sections.rb -- Hobix sections plugin version 0.1, released 9/20/04
## (c) 2004 William Morgan. This file is released under the GNU Public
##     License.
##
## USAGE: place this file in your $HOBIXROOT/lib directory. Then, in
## your $HOBIXROOT/hobix.yaml file (or by running 'hobix edit'), add
## 'sections' to the 'required' block, like this:
## 
## [...]
## required:
## [...]
##   - sections
##
## Finally, add 'sidebar_section_list' to the 'sidebar_list' property
## of hobix/out/quick, like this:
##
## hobix/out/quick: 
##   sidebar_list: 
## [...]     
##      - sidebar_section_list
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
## Good luck. -- William <wmorgan-sidebar-hobix@masanjin.net>

class Hobix::Out::Quick
  def section_list(entries)
    counts = {}
    entries.each do |path, mtime|
      path = path.split("/")[0 ... -1]
      counts[path] ||= 0
      counts[path] += 1
    end

    list = []; seen = {}
    counts.sort.each do |path, count|
      path[0 ... -1].inject("") do |s, x|
        prefix = s + "/" + x
        unless seen[prefix]
          seen[prefix] = true
          list.push [x, prefix, prefix.count('/'), 0]
        end
        prefix
      end
      leafpath = "/" + path.join('/')
      seen[leafpath] = true
      list.push [path[-1], leafpath, path.length, count]
    end
    list
  end

  def sidebar_section_list_erb
    %q{
    <div class="sidebarBox">
    <h2 class="sidebarTitle">Sections</h2>
    <% curlev = 0 %>
    <% section_list(weblog.storage.find).each do |name, path, lev, num| %>
      <% if (lev > curlev) %>
        <% (lev - curlev).times do %> <ul> <% end %>
      <% elsif (curlev > lev) %>
        <% (curlev - lev).times do %> </ul> <% end %>
      <% end %>
      <% curlev = lev %>
      <li>
        <a href="<%= weblog.link %><%= path %>"><%= name %></a>
        <% if num != 0 then %> (<%= num %>) <% end %>
      </li>
    <% end %>
    <% curlev.times do %>
      </ul>
    <% end %>
    </div>
    }
  end
end
