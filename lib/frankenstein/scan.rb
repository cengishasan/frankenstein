# Scan for GitHub repos
module Scan
  require 'colored'
  require 'github-trending'
  # require 'pp'

  require 'frankenstein/cli'
  require 'frankenstein/constants'
  require 'frankenstein/core'
  require 'frankenstein/github'
  require 'frankenstein/io'
  require 'frankenstein/output'

  PRODUCT = 'scan'
  PRODUCT_DESCRIPTION = 'Scan for GitHub repos'

  LEADING_SPACE = '      '

  OPTION_ALL = 'all'
  OPTION_POPULAR = 'p'
  OPTION_RANDOM = 'r'
  OPTION_TREND = 't'
  OPTION_TODO = 'todo'

  POPULAR_LANGUAGES = [
    'java',
    'python',
    'php',
    'csharp',
    'c++',
    'c',
    'javascript',
    'objective-c',
    'swift',
    'r',
    'ruby',
    'perl',
    'matlab',
    'lua',
    'scala',
    'dart',
    'go',
    'rust',
    'coffeescript',
    'julia',
    'elixir',
    'erlang',
    'haskell',
    'unknown'
  ]

  class << self
    def scan_content(content, allforce = false)
      epoch = Time.now.to_i
      filename = "#{Frankenstein::FILE_LOG_DIRECTORY}/todo-#{epoch}"

      File.write filename, content

      Frankenstein.core_scan filename, allforce

      File.delete filename
    end

    def scan_user(argv_1, all = false)
      user = argv_1.sub('@', '')
      c = Frankenstein.github_client
      c.auto_paginate = true

      begin
        u = c.user user
      rescue StandardError => e
        puts "#{argv_1} is not a valid user: #{e}".red
        exit 1
      end

      l = u['location']
      repos = u['public_repos']
      m = "Getting repos for #{argv_1.white} "
      m << "from #{l.blue}" unless l.nil?
      puts m

      puts "#{Frankenstein.pluralize2 repos, 'repo'}"

      r = c.repos(user).reject { |x| x['fork'] }
      puts "#{r.count} are not forked" unless r.count == repos

      if all
        combined = r
      else
        puts 'Getting top 5 most popular repos...'
        top5 = r.sort_by { |x| x['stargazers_count'] }.reverse.first(5)
               .each { |x| puts ' ' << x['full_name'] }

        puts 'Getting latest repos with updates'
        recent = r.reject { |x| x['pushed_at'].class == NilClass }
                 .sort_by { |x| x['pushed_at'] }
                 .reverse.first(5)
                 .each { |x| puts ' ' << x['full_name'] }

        combined = recent + top5
      end
      m = combined.uniq.map { |x| x['full_name'] }
          .each_with_index { |x, i| puts "#{i + 1} #{x}" }

      scan_content map_repos(m), all

      Frankenstein.io_record_scan user, m
    end

    def map_repos(repos)
      mapped = repos.map { |r| "https://github.com/#{r}" }

      m = ''
      mapped.each { |r| m << " #{r}" }

      m
    end

    def update_left(left, f)
      left.delete_at 0
      Frankenstein.io_json_write f, left
      puts "todo left: #{left.count}"
      sleep 1
    end
  end

  argv_1, argv_2 = ARGV
  if argv_1.nil?
    a_p = PRODUCT.blue
    a_l = 'language'.green
    a_t = OPTION_TREND.white
    a_f = 'file'.white
    a_todo = OPTION_TODO.white
    a_r = OPTION_RANDOM.white
    a_po = OPTION_POPULAR.white
    a_at = '@username'.green
    a_a = OPTION_ALL.white
    m = "#{a_p} #{PRODUCT_DESCRIPTION.white} \n"\
        "Usage: #{a_p} <#{a_f}> "\
        "\n#{LEADING_SPACE} #{a_p} #{a_t} — scan overall trending repos"\
        "\n#{LEADING_SPACE} #{a_p} #{a_t} [#{a_l}] — scan trending repos for a"\
        ' given language '\
        "\n#{LEADING_SPACE} #{a_p} #{a_r} — scan random trending repos "\
        "\n#{LEADING_SPACE} #{a_p} #{a_po} — scan trending repos for popular "\
        'languages'\
        "\n#{LEADING_SPACE} #{a_p} #{a_at} — scan top/recent repos for"\
        ' a GitHub user '\
        "\n#{LEADING_SPACE} #{a_p} #{a_at} #{a_a} — (force) scan all repos for"\
        ' a GitHub user '\
        "\n#{LEADING_SPACE} #{a_p} #{a_todo} - scan repos from #{'todo'.blue}"
    puts m
    puts "\n"
    exit
  end

  unless Frankenstein.github_creds
    puts Frankenstein::GITHUB_CREDS_ERROR
    exit(1)
  end

  Frankenstein.cli_create_log_dir

  if argv_1.include? '@'
    scan_user argv_1, argv_2 == OPTION_ALL
    exit
  end

  if argv_1 == OPTION_POPULAR
    all = []
    pop = POPULAR_LANGUAGES
    pop.each_with_index do |p, i|
      puts "#{i + 1}/#{pop.count} Getting trending repos for #{p}"
      repos = Github::Trending.get p
      all += repos
    end

    puts 'Getting overall trending repos'
    all += Github::Trending.get

    m = all.map(&:name)
    scan_content map_repos(m)
    exit
  end

  if argv_1 == OPTION_TODO
    f = Frankenstein::FILE_TODO
    todo = Frankenstein.io_json_read f

    left = todo.map(&:dup)
    todo.each_with_index do |x|
      m = x['repo']

      if m.include? '@'
        scan_user m
        update_left left, f
        next
      end

      m = "https://github.com/#{m}" unless m.include? '://github.com'
      puts "Scanning #{m.white}..."

      scan_content m
      update_left left, f
    end

    puts "Finished scanning #{todo.count} repos" unless todo.count == 0
    exit
  end

  if (argv_1 == OPTION_TREND) || (argv_1 == OPTION_RANDOM)
    puts 'Scanning Trending in GitHub'

    if argv_1 == OPTION_RANDOM
      random_language = POPULAR_LANGUAGES.sample
      puts "Random Language: #{random_language.white}"
      repos = Github::Trending.get random_language
    elsif argv_2.nil?
      repos = Github::Trending.get
    else
      puts "Language: #{argv_2.white}"
      repos = Github::Trending.get argv_2
    end

    scan_content map_repos(repos.map(&:name))

    exit
  end

  unless File.exist? argv_1
    puts "#{PRODUCT.red} File #{argv_1.white} does not exist"
    exit(1)
  end

  Frankenstein.core_scan(argv_1)
end
