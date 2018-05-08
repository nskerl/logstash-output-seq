# testing
`PS C:\Code\logstash-output-seq> bundle exec rspec spec`

# building
`PS C:\Code\logstash-output-seq> gem build .\logstash-output-seq.gemspec`


# installing
copy the .gem to the logstash directory [F:\Elastic\logstash-6.0.1]
`PS F:\Elastic\logstash-6.0.1> bin\logstash-plugin install logstash-output-seq-0.1.1.gem`

# example config
```
input {
  stdin {
    id => "yak"
  }
}

output {
    stdout { codec => rubydebug }

    seq { url => "http://localhost:5341"}
}
```

# start logstash
`PS F:\Elastic\logstash-6.0.1> bin\logstash -f F:\Elastic\conf\logstash-conf.yml`