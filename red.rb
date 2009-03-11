VER = "0.1 (c) 2009 Dave Nolan textgoeshere.org.uk, github.com/textgoeshere/redcmd"
BANNER =<<-EOS
Red creates Redmine (http://www.redmine.org/) issues from the command line.

==Released under MIT license==
Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

==Example==
red -s "Twitter integration FTW!!" -t feature -p cashprinter -r high -a "Some poor sod"
# => "Created Feature #999 Twitter integration FTW!!!"

Command line arguments override settings in the configuration file, which override Redmine form defaults.

==An example configuration file==
username: dave
password: d4ve
url: http://www.myredmineinstance.com
project: redcmd
tracker: bug
priorty: normal   

I recommend creating a configuration file per-project, and sticking it in your path.

# TODO: due, start, done, est. hours
# TODO: custom fields
# TODO: subcommands (list, update, etc.)

#{VER}

==Options==

EOS


begin
  require 'trollop'
  require 'mechanize'
rescue LoadError
  require 'rubygems'
  require 'trollop'
  require 'mechanize'
end

module Textgoeshere
  class RedmineError < StandardError; end
  
  class Red
    SELECTS = %w{priority tracker category assigned_to status}
    
    def initialize(opts)
      @opts = opts
      @mech  = WWW::Mechanize.new
      login
      create_issue
    end
    
    private
    
    def login
      @mech.get login_url
      @mech.page.form_with(:action => login_action) do |f|
        f.field_with(:name => 'username').value = @opts[:username]
        f.field_with(:name => 'password').value = @opts[:password]
        f.click_button
      end
      catch_redmine_errors
    end
    
    def create_issue
      @mech.get new_issue_url
      @mech.page.form_with(:action => create_issue_action) do |f|
        SELECTS.each do |name|
          value = @opts[name.to_sym]
          unless value.nil?
            field = f.field_with(:name => "issue[#{name}_id]")
            field.value = field.options.detect { |o| o.text.downcase =~ Regexp.new(value) }
            raise RedmineError.new("Cannot find #{name} #{value}") if field.value.nil? || field.value.empty?
          end
        end
        f.field_with(:name => 'issue[subject]').value = @opts[:subject]
        f.field_with(:name => 'issue[description]').value = @opts[:subject]
        f.click_button
        catch_redmine_errors
        puts "Created #{@mech.page.search('h2').text}: #{@opts[:subject]}"
      end
    end
    
    def login_action; '/login'; end
    def login_url; "#{@opts[:url]}#{login_action}"; end 
    def create_issue_action; "/projects/#{@opts[:project]}/issues/new"; end
    def new_issue_url; "#{@opts[:url]}#{create_issue_action}"; end
      
    def catch_redmine_errors
      error_flash = @mech.page.search('.flash.error')[0]
      raise RedmineError.new(error_flash.text) if error_flash
    end
  end
end

# NOTE: Trollop's default default for boolean values is false, not nil, so if extending to include boolean options ensure you explicity set :default => nil   
opts = Trollop::options do
  banner BANNER
  opt :subject, "Issue subject (title). This must be wrapped in inverted commas like this: \"My new feature\".", 
          :type => String, :required => true
  opt :tracker,     "Tracker (bug, feature etc.)",  :type => String
  opt :project,     "Project identifier",           :type => String
  opt :assigned_to, "Assigned to",                  :type => String
  opt :priority,    "Priority",                     :type => String
  opt :status,      "Status",                       :type => String, :short => 'x'
  opt :category,    "Category",                     :type => String
  opt :username,    "Username",                     :type => String, :short => 'u'
  opt :password,    "Password",                     :type => String, :short => 'p'
  opt :url,         "Url to redmine",               :type => String
  opt :filename, "Configuration file, YAML format, specifying default options.", 
          :type => String, :default => ".red"
  version VER
end
YAML::load_file(opts[:filename]).each_pair { |name, default| opts[name.to_sym] ||= default } if File.exist?(opts[:filename])
Textgoeshere::Red.new(opts)
