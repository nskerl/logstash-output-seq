Gem::Specification.new do |s|
  s.name          = 'logstash-output-seq'
  s.version       = '0.1.24'
  s.licenses      = ['Apache-2.0']
  s.summary       = 'Send events from logstash to seq'
  s.description   = 'A LogStash output plugin that forwards events to SEQ using the clef format'
  s.homepage      = 'https://github.com/nskerl/logstash-output-seq'
  s.authors       = ['Nathan Skerl', 'Todd Bryan']
  s.email         = 'nskerl@gmail.com'
  s.require_paths = ['lib']

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", "~> 2.0"
  s.add_runtime_dependency "logstash-mixin-http_client", ">= 6.0.1", "< 7.0.0"
  s.add_runtime_dependency "logstash-codec-plain"
  s.add_development_dependency "logstash-devutils"
end
