# Extend string
class String
  def number?
    true if Float(self)
  rescue
    false
  end
end

# Check GitHub notifications
module New
  require 'colored'

  require 'frankenstein/constants'
  require 'frankenstein/core'
  require 'frankenstein/network'
  require 'frankenstein/github'
  require 'frankenstein/output'

  PRODUCT = 'new'
  RUN_ISSUES = '/Run/issues/'
  LIMIT = 5

  unless Frankenstein.github_creds
    puts Frankenstein::GITHUB_CREDS_ERROR
    exit(1)
  end

  puts '> Creating GitHub client'
  client = Frankenstein.github_client

  puts '> Getting notifications'
  begin
    n = client.notifications
  rescue StandardError => e
    puts "Error getting notifications #{e}".red
    exit
  end

  t = Time.new.strftime('%b %d at %I:%M%p')

  if n.count == 0
    puts "#{'No notifications'.green} #{t.white}"
    exit
  end

  m = n.map do |x|
    s = x[:subject]
    u = s[:url]
    u.sub('api.', '').sub('repos/', '').sub('/pulls', '/pull')
    # is it better to load `u` and retrieve html_url via json ?
  end

  puts "#{Frankenstein.pluralize2 m.count, 'issue'}".white

  m.each_with_index do |x, index|
    print "#{index + 1} "
    if x.include? RUN_ISSUES
      notif = n[index]
      subject = notif['subject']['title']
      print x.yellow + ' '
      puts subject
    else
      puts x.blue
    end

    sleep 0.5

    url = m[index]
    if url.include? RUN_ISSUES
      notif = n[index]

      r = notif['repository']['name']
      user = Frankenstein.github_netrc_username
      repo = "#{user}/#{r}"

      j = notif['subject']['url']

      links_to_check = links_to_check[0,LIMIT]

      links_to_check, json = Frankenstein.core_links_to_check repo, j

      number = json['number']
      links_to_check.each do |x2|
        Frankenstein.core_todo_add repo: x
        puts "Added #{x2.white} to #{'todo'.blue}"

        comment = "Run request for #{x2} received."
        client.add_comment repo, number, comment

        thread = notif['id']
        client.mark_thread_as_read thread
      end # end links_to_check..
    else
      Frankenstein.core_merge url

      # twitter doesn't like when you tweet too hard 🐦
      pause =  m.count > 2 ? Random.new.rand(50..70) : 0
      puts "Pausing for #{pause}s ..." if pause > 0
      sleep pause
    end # if url.include? RUN_ISSUES
  end # end m.each

  puts "\n#{PRODUCT.white} finished " if n.count > 0
end # module
