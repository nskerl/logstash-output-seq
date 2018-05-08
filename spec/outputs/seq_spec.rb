# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/seq"
require "logstash/codecs/plain"
require "logstash/event"
require "json"

describe LogStash::Outputs::Seq do

  let(:url) { "http://localhost:5341"}
  let(:api_key) { "YAK1234"}

  let(:output) { LogStash::Outputs::Seq.new({
    'url' => url,
    'api_key' => api_key
  }) }

  let(:sample_event) {
    LogStash::Event.new({
      '@timestamp' => '2018-01-01T11:11:00.00000+00:00',
      '@level' => 'Information',
      '@template' => 'My name is {FirstName}',
      'properties' => {"FirstName"=> "Yak", "LastName"=> "Aroni", "Age" => 99}
    })
  }

  let(:sample_events) {
    [
      LogStash::Event.new({
        '@timestamp' => '2018-01-01T11:11:00.00000+00:00',
        '@level' => 'Information',
        '@template' => 'My name is {FirstName}',
        'properties' => {"FirstName"=> "Yak", "LastName"=> "Alicious", "Age" => 99}
      }),
    LogStash::Event.new({
        '@timestamp' => '2018-01-01T11:11:00.00000+00:00',
        '@level' => 'Information',
        '@template' => 'My name is {FirstName}',
        'properties' => {"FirstName"=> "Yak", "LastName"=> "O'Matic", "Age" => 99}
      })
    ]
  }

  before do
    output.register
  end

  describe "handle single event" do
    it "should convert single event into clef formatted json line" do
      test = JSON.parse(output.format_one("test-batch", sample_event))

      expect(test['@t']).to eq("2018-01-01T11:11:00.000Z")
      expect(test['@mt']).to eq("My name is {FirstName}")
    end
  end

  describe "handle multiple events" do
    it "should convert many events into clef formatted json lines" do

      lines = output.format_many("test-batch", sample_events).split("\n").each{|line| 
        test = JSON.parse(line)
        expect(test['@mt']).to eq("My name is {FirstName}")
      }

      expect(lines.count).to eq(2)
      
    end
  end

  describe "handle thin events" do
    it "should accept thin events and return sane defaults" do

      thin_event = LogStash::Event.new({
        '@timestamp' => '2018-05-03T23:43:57.282Z',
        'message' => 'yaaaaak\r'
      })

      test = JSON.parse(output.format_one("test-batch", thin_event))

      expect(test['@t']).to eq("2018-05-03T23:43:57.282Z")
      expect(test['@mt']).to eq("{Message}")

    end
  end

  describe "send many" do
    it "should send many events to seq" do

      output.multi_receive(sample_events)

      # todo: intercept and test the actual post to SEQ
      expect(1).to eq(1)
    end
  end
end
