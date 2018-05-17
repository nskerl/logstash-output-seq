# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
require "logstash/json"
require "logstash/plugin_mixins/http_client"
require "uri"
require "securerandom"

class LogStash::Outputs::Seq < LogStash::Outputs::Base
  include LogStash::PluginMixins::HttpClient

  concurrency :single

  config_name "seq"

  # URL of SEQ endpoint (http://localhost:5341)
  config :url, :validate => :string, :required => :true

  # API key to send with request
  config :api_key, :validate => :string, :optional => :true

  # Number of retries to attempt
  config :retry_count, :validate => :number, :default => 60

  @@remove_properties = {
      '@timestamp' => true,
      '@level' => true,
      '@version' => true,
      '@template' => true,
      'message' => true
  }

  RETRYABLE_MANTICORE_EXCEPTIONS = [
    ::Manticore::Timeout,
    ::Manticore::SocketException,
    ::Manticore::ClientProtocolException, 
    ::Manticore::ResolutionFailure, 
    ::Manticore::SocketTimeout
  ]

  public
  def register
    @url += "/" unless @url.end_with? "/"
    @url += "api/events/raw?clef"
    @url = URI.parse(@url)

    @default_headers = {
        "X-Seq-ApiKey" => @api_key,
        "Content-Type" => "application/json"
    }

    @logger.info("Registered SEQ output plugin", :pool_max => @pool_max, :url => @url)
  end

  public
  def multi_receive(events)
    batch_id = SecureRandom.uuid # for debugging logstash's pipeline
    @logger.debug("multi_receive() event count (#{events.count})", :batch_id => batch_id)

    payload = format_many(batch_id, events)
    post_to_seq(batch_id, payload)
  end

  public 
  def format_many(batch_id, events)
    batch = events.map {|event| format_one(batch_id, event)}
    @logger.debug("format_many() batch count (#{batch.count})", :batch_id => batch_id)

    batch.join("\n")
  end

  public
  def format_one(batch_id, event)

    level = case event.get("@level") 
      when "Verbose", "Debug", "Information", "Warning", "Error", "Fatal"; event.get("@level") 
      else "Information"
      end

    payload = {
        "@t" => event.get("@timestamp"), 
        "@l" => level,
        "@mt" => event.get("@template") ? event.get("@template") : "{Message}"
      }
    
    payload["@x"] = event.get("exception") if event.get("exception")
    payload["@i"] = event.get("eventId") if event.get("eventId")

    event.to_hash.each do | property, value |
      payload[property] = value unless @@remove_properties.has_key? property
    end

    LogStash::Json.dump(payload)
  end

  private
  def retry_sleep (attempts)
    # h/t: https://github.com/ooyala/retries
    base_sleep_seconds = 0.1
    max_sleep_seconds = 30

    sleep_seconds = [base_sleep_seconds * (2 ** (attempts)), max_sleep_seconds].min
    # Randomize to a random value in the range sleep_seconds/2 .. sleep_seconds
    sleep_seconds = sleep_seconds * (0.5 * (1 + rand()))
    # But never sleep less than base_sleep_seconds
    sleep_seconds = [base_sleep_seconds, sleep_seconds].max

    @logger.debug("Sleeping for #{sleep_seconds} seconds")

    sleep sleep_seconds
  end

  private 
  def post_to_seq(batch_id, body)

    @retry_count.times.each do |i|

      begin
        @logger.debug("Posting batch to SEQ (attempt #{i})", :batch_id => batch_id)
        request = client.send(:post, @url, :body => body, :headers => @default_headers)

        response = request.call

        case
        when response.code.between?(200, 299)
          @logger.debug("Received #{response.code}", :code => response.code, :batch_id => batch_id)
          break
        else
          @logger.warn("Received non-2xx HTTP code #{response.code} while posting to SEQ (will retry)", :code => response.code, :batch_id => batch_id)
          retry_sleep(i)
        end
      rescue *RETRYABLE_MANTICORE_EXCEPTIONS => e
        @logger.warn("Retryable exception while posting to SEQ (will retry)", :batch_id => batch_id, :exception => e, :message => e.message)
        retry_sleep(i)  
      rescue Exception => e
        @logger.warn("Unhandled exception while posting to SEQ (will exit)", :batch_id => batch_id, :exception => e, :message => e.message, :stacktrace => e.backtrace)
        break
      ensure
        if i == @retry_count
          @logger.warn("Unable to post batch to SEQ after #{i} retries (will discard)", :batch_id => batch_id)
          break
        end
      end
    end
  end  
end
