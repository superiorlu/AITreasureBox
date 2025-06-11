#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'nokogiri'
require 'json'
require 'date'

def grab_github_trending(github_trending_url = 'https://github.com/trending')
  max_retries = 3
  retry_delay = 2

  (1..max_retries).each do |attempt|
    begin
      uri = URI(github_trending_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'

      request = Net::HTTP::Get.new(uri)
      request['Accept'] = 'text/html'
      request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36'


      response = http.request(request)

      unless response.code == '200'
        raise "Http Request Error: #{response.code}"
      end

      document = Nokogiri::HTML(response.body)
      repo_list = document.css('article.Box-row')
      if repo_list.empty?
        raise "Not Found, May Be Changed!"
      end

      github_repos = []
      repo_list.each do |repo|
        name = repo.css('h2 > a').text.strip
        language = repo.css('span[itemprop="programmingLanguage"]').text.strip
        description = repo.css('p.my-1').text.strip
        stars = repo.css('a[href$="/stargazers"]').text.strip
        stars_today = repo.css('span.d-inline-block.float-sm-right').text.strip
        link = 'https://github.com' + repo.css('h2 > a').first&.[]('href').to_s
        names = name.split("/")
        next if names.length < 2

        owner = names[0].strip
        repo_name = names[1].strip
        crawl_date = Date.today.strftime('%Y-%m-%d')

        github_repo = {
          owner: owner,
          name: repo_name,
          description: description,
          language: language,
          stars: parse_number(stars),
          starsToday: parse_stars_today(stars_today),
          link: link,
          crawlDate: crawl_date
        }

        github_repos << github_repo
      end
      report_repos(github_repos)
    rescue => e
      if attempt == max_retries
        raise "Failed，Retry #{max_retries} times: #{e.message}"
      end
      sleep(retry_delay)
      retry_delay *= 2
    end
  end
end

def parse_number(text)
  return 0 if text.nil? || text.empty?
  text.gsub(',', '').to_i
end

def parse_stars_today(text)
  return 0 if text.nil? || text.empty?
  text.gsub(' stars today', '').gsub(',', '').to_i
end

def report_repos(repos)
  repos_json = JSON.pretty_generate(repos)

  uri = URI.parse(ENV['REPORT_REPOS_URL'])
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == 'https'

  request = Net::HTTP::Post.new(uri.request_uri)
  request['Content-Type'] = 'application/json'
  request.body = repos_json

  response = http.request(request)
end

if __FILE__ == $0
  begin
    grab_github_trending
  rescue => e
    exit 1
  end
end