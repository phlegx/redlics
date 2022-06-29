# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

describe Redlics do
  subject { Redlics }

  it 'must respond positively' do
    subject.redis { |r| r.namespace }.must_equal Redlics.config.namespace
  end
end
