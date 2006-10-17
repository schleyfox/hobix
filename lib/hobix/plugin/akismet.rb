## akismet.rb -- Hobix akismet plugin
##
## Adds spam comment blocking to Hobix comments support.  It does this
## using David Czarnecki's Ruby API (included in the plugin) for Akismet
## (http://akismet.com/personal/).  When loaded comments that get submitted
## are fed to Akismet on-line and rejected if they are considered to be
## spam comments.
##
## Note that this plugin needs a network connection to verify the comments
## and it needs an Akismet API key to function.  For personal use, Akismet
## API keys are free and will be sent to you on signing up at WordPress.
## See also: http://wordpress.com/signup/.
##
## USAGE:
##
## 1) In hobix.yaml (e.g. by running 'hobix edit <blogname>'), simply
##    add 'hobix/plugin/akismet' to the 'required' block.
##
## required:
## [...]
## - hobix/plugin/akismet
##
## 2) Specify the API key you received/already had as parameter for the
##    plugin.
##
## required:
## [...]
## - hobix/plugin/akismet:
##     api-key: 123456789abc
##
##    And that's it!
##
## NOTES:
##
## 1) This plugin is not useful when the Hobix comments support is not loaded,
##    i.e. 'hobix/comments' is not required.

module Hobix
	
class AkismetKey < BasePlugin
	
  def initialize(weblog, params = {})
    raise %{The Akismet plugin is not configured, the API key is missing. See hobix/plugin/akismet.rb for details} unless params.member?("api-key")
    @@key = params["api-key"]
  end

  def self.key; @@key; end
  
end

end

# Akismet
#
# Author:: David Czarnecki
# Copyright:: Copyright (c) 2005 - David Czarnecki
# License:: BSD
# Modified by Dieter Komendera, Sparkling Studios:
#   append blog= to data string (Akismet said it is required)
#   changed require 'net/HTTP' to require 'net/http' (to work for me unter GNU/Linux)

class Akismet

  require 'net/http'
  require 'uri'
  
  STANDARD_HEADERS = {
    'User-Agent' => 'Akismet Ruby API/1.0',
    'Content-Type' => 'application/x-www-form-urlencoded'
  }
  
  # Instance variables
  @apiKey
  @blog
  @verifiedKey
  @proxyPort = nil
  @proxyHost = nil

  # Create a new instance of the Akismet class
  #
  # apiKey 
  #   Your Akismet API key
  # blog 
  #   The blog associated with your api key
  
  def initialize(blog, apiKey)
    @apiKey = apiKey
    @blog = blog
    @verifiedKey = false
  end
  
  # Set proxy information 
  #
  # proxyHost
  #   Hostname for the proxy to use
  # proxyPort
  #   Port for the proxy
  def setProxy(proxyHost, proxyPort) 
    @proxyPort = proxyPort
    @proxyHost = proxyHost
  end
    
  # Call to check and verify your API key. You may then call the #hasVerifiedKey method to see if your key has been validated.
  def verifyAPIKey()
    http = Net::HTTP.new('rest.akismet.com', 80, @proxyHost, @proxyPort)
    path = '/1.1/verify-key'
    
    data="key=#{@apiKey}&blog=#{@blog}"
    
    resp, data = http.post(path, data, STANDARD_HEADERS)
    @verifiedKey = (data == "valid")
  end
 
  # Returns <tt>true</tt> if the API key has been verified, <tt>false</tt> otherwise
  def hasVerifiedKey()
    return @verifiedKey
  end
  
  # Internal call to Akismet. Prepares the data for posting to the Akismet service.
  #
  # akismet_function
  #   The Akismet function that should be called
  # user_ip (required)
  #    IP address of the comment submitter.
  # user_agent (required)
  #    User agent information.
  # referrer (note spelling)
  #    The content of the HTTP_REFERER header should be sent here.
  # permalink
  #    The permanent location of the entry the comment was submitted to.
  # comment_type
  #    May be blank, comment, trackback, pingback, or a made up value like "registration".
  # comment_author
  #    Submitted name with the comment
  # comment_author_email
  #    Submitted email address
  # comment_author_url
  #    Commenter URL.
  # comment_content
  #    The content that was submitted.
  # Other server enviroment variables
  #    In PHP there is an array of enviroment variables called $_SERVER which contains information about the web server itself as well as a key/value for every HTTP header sent with the request. This data is highly useful to Akismet as how the submited content interacts with the server can be very telling, so please include as much information as possible.  
  def callAkismet(akismet_function, user_ip, user_agent, referrer, permalink, comment_type, comment_author, comment_author_email, comment_author_url, comment_content, other)
    http = Net::HTTP.new("#{@apiKey}.rest.akismet.com", 80, @proxyHost, @proxyPort)
    path = "/1.1/#{akismet_function}"        
    
    data = "blog=#{@blog}&user_ip=#{user_ip}&user_agent=#{user_agent}&referrer=#{referrer}&permalink=#{permalink}&comment_type=#{comment_type}&comment_author=#{comment_author}&comment_author_email=#{comment_author_email}&comment_author_url=#{comment_author_url}&comment_content=#{comment_content}"
    if (other != nil) 
      other.each_pair {|key, value| data.concat("&#{key}=#{value}")}
    end
            
    resp, data = http.post(path, data, STANDARD_HEADERS)

    return (data != "false")
  end
  
  protected :callAkismet

  # This is basically the core of everything. This call takes a number of arguments and characteristics about the submitted content and then returns a thumbs up or thumbs down. Almost everything is optional, but performance can drop dramatically if you exclude certain elements.
  #
  # user_ip (required)
  #    IP address of the comment submitter.
  # user_agent (required)
  #    User agent information.
  # referrer (note spelling)
  #    The content of the HTTP_REFERER header should be sent here.
  # permalink
  #    The permanent location of the entry the comment was submitted to.
  # comment_type
  #    May be blank, comment, trackback, pingback, or a made up value like "registration".
  # comment_author
  #    Submitted name with the comment
  # comment_author_email
  #    Submitted email address
  # comment_author_url
  #    Commenter URL.
  # comment_content
  #    The content that was submitted.
  # Other server enviroment variables
  #    In PHP there is an array of enviroment variables called $_SERVER which contains information about the web server itself as well as a key/value for every HTTP header sent with the request. This data is highly useful to Akismet as how the submited content interacts with the server can be very telling, so please include as much information as possible.
  def commentCheck(user_ip, user_agent, referrer, permalink, comment_type, comment_author, comment_author_email, comment_author_url, comment_content, other)
    return callAkismet('comment-check', user_ip, user_agent, referrer, permalink, comment_type, comment_author, comment_author_email, comment_author_url, comment_content, other)
  end
  
  # This call is for submitting comments that weren't marked as spam but should have been. It takes identical arguments as comment check.
  # The call parameters are the same as for the #commentCheck method.
  def submitSpam(user_ip, user_agent, referrer, permalink, comment_type, comment_author, comment_author_email, comment_author_url, comment_content, other)
    callAkismet('submit-spam', user_ip, user_agent, referrer, permalink, comment_type, comment_author, comment_author_email, comment_author_url, comment_content, other)
  end
  
  # This call is intended for the marking of false positives, things that were incorrectly marked as spam. It takes identical arguments as comment check and submit spam.
  # The call parameters are the same as for the #commentCheck method.
  def submitHam(user_ip, user_agent, referrer, permalink, comment_type, comment_author, comment_author_email, comment_author_url, comment_content, other)
    callAkismet('submit-ham', user_ip, user_agent, referrer, permalink, comment_type, comment_author, comment_author_email, comment_author_url, comment_content, other)
  end
end
