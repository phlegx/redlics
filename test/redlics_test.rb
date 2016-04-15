# encoding: UTF-8
require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))


describe Redlics do
  subject { Redlics }


  it 'must respond positively' do
    subject.redis.namespace.must_equal Redlics.config.namespace
  end

end
