#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_term(termid)
  url = 'http://www.cnmileg.gov.mp/members.asp?secID=1&legsID=%s' % termid
  noko = noko_for(url)

  extract = lambda do |tr, txt|
    tr.xpath(".//p[contains(.,'#{txt}')]").text.lines.find { |l| l.include? txt }.split(':', 2).last.tidy
  end

  noko.css('#mbrtbl tr').each do |tr|
    party, district = tr.css('p.note').text.tidy.split(', ', 2)

    data = {
      id:      tr.css('a[href*="mbrID="]/@href').first.text[/ID=(\d+)/, 1],
      name:    tr.css('h4').text.tidy,
      role:    tr.css('h5').text.tidy,
      party:   party,
      area:    district,
      area_id: district[/(\d+)$/, 1],
      phone:   extract.call(tr, 'Phone'),
      fax:     extract.call(tr, 'Fax'),
      term:    termid,
      source:  url,
    }

    if termid >= 16
      data[:image] = tr.css('img[src*="/members/"]/@src').text.sub('/thumbs/', '/')
      data[:image] = URI.join(url, URI.escape(data[:image])).to_s unless data[:image].to_s.empty?

      data[:contact_form] = tr.css('a[href*="members_contact"]/@href').text
      data[:contact_form] = URI.join(url, URI.escape(data[:contact_form])).to_s unless data[:contact_form].to_s.empty?
    end

    # puts "%s - %s" % [data[:id], data[:name]]
    ScraperWiki.save_sqlite(%i(id term), data)
  end
end

# (1..19).reverse_each do |termid|
#   scrape_term(termid)
# end

scrape_term(19)
