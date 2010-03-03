#!/usr/bin/env ruby

require 'test/unit'

require 'rubygems'
require 'environment'

class BillTest < Test::Unit::TestCase
  
  def test_title_extraction
    cases = {
      'hr1-stimulus' => {
         :short => "American Recovery and Reinvestment Act of 2009",
         :official => "Making supplemental appropriations for job preservation and creation, infrastructure investment, energy efficiency and science, assistance to the unemployed, and State and local fiscal stabilization, for fiscal year ending September 30, 2009, and for other purposes."
      },
      'hr3590-health-care' => {
         :short => "Patient Protection and Affordable Care Act",
         :official => "An act entitled The Patient Protection and Affordable Care Act."
      },
      'hr4173-wall-street' => {
         :short => "Wall Street Reform and Consumer Protection Act of 2009",
         :official => "To provide for financial regulatory reform, to protect consumers and investors, to enhance Federal understanding of insurance issues, to regulate the over-the-counter derivatives markets, and for other purposes."
      }
    }
    
    cases.each do |filename, recents|
      doc = Hpricot.XML open("test/fixtures/titles/#{filename}.xml")
      titles = Bill.titles_for doc
      assert_equal recents[:short], Bill.most_recent_title_from(titles, :short)
      assert_equal recents[:official], Bill.most_recent_title_from(titles, :official)
    end
  end
  
end