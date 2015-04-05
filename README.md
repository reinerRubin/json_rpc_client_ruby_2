# json_rpc_client_ruby_2
Asynchronous (EventMachine) JSON-RPC 2.0 over HTTP client based on json-rpc-client-ruby (https://github.com/Textalk/json-rpc-client-ruby)

This gem is a client implementation for JSON-RPC 2.0. It uses EventMachine to enable asynchronous communication with a JSON-RPC server. The main feature is
that client can into batch requests (http://www.jsonrpc.org/specification#batch)

Now (s.version = '0.1') all requests are batch requests.

## Usage

Gemfile:
```
gem 'json_rpc_client_2', git: 'https://github.com/reinerRubin/json_rpc_client_ruby_2'

```

example.rb:
```ruby
# set logger (by default null_logger)
JsonRpcClient::RpcClient::logger = Logger.new(STDOUT)
client = JsonRpcClient::RpcClient.new('http://rpc.server:port/json_rpc')

EM.run do
  def_result = client.send(JsonRpcClient::Request::RpcMethod.new(
    method: 'method',
    params: [param1: 'param1value']
  ))
  def_result.callback { |r| puts "Yay! Response: #{r.result}" }
  def_result.errback { |error| puts "Nope. Error code: #{error.error.code}" }

  # notifies without any responses
  client.send(JsonRpcClient::Request::RpcNotify.new(
    method: 'method',
    params: [param1: 'param1value']
  ))
  # => nil
  client.send([
  JsonRpcClient::Request::RpcNotify.new(
    method: 'method',
    params: [param1: 'param1value']
  ),
  JsonRpcClient::Request::RpcNotify.new(
    method: 'method',
    params: [param1: 'param1value']
  )
  ])
  # => nil

  # batch request
  methods = [
    JsonRpcClient::Request::RpcMethod.new(
      method: 'hello',
	  params: [param1: 'param1value']
	),
    JsonRpcClient::Request::RpcMethod.new(
	  method: 'giveMeError',
	  id: 90210,
	  params: [param1: 'whyNot']
	),
    JsonRpcClient::Request::RpcNotify.new(
	  method: 'helloNotify',
	  params: [param1: 'anotherParams']
	)
  ]

  def_results = client.send(methods)

  def_results.callback do |results|
    puts 'Yay! Responses:'
    results.each_with_index do |r, i|
      if r.is_a? JsonRpcClient::Response::RpcSuccessResponse
        puts "result #{i}: #{r.result}"
      else
        puts "result #{i}: #{r.error}"
      end
    end
  end

  def_results.each do |def_result|
    def_result.callback { |r| puts "single callback #{r.result}"  }
    def_result.errback  { |error| puts "single errback #{error.error.code}" }
  end

  def_results.errback { |error| puts "Nope. Error code: #{error.error.code}" }
end
```
You can find more cases in test/*.

## Main entities
### Requests | lib/request/request.rb
* JsonRpcClient::Request::RpcMethod(method:, params:, id:) # id, param - optional
* JsonRpcClient::Request::RpcNotify(method:, params:) # param - optional

### Responses | lib/response/*
#### Deferrable responses
* JsonRpcClient::Response::RpcDefResponses include EM::Deferrable and Enumerable
* JsonRpcClient::Response::RpcDefResponse include EM::Deferrable

#### Responses
* JsonRpcClient::Response::RpcSuccessResponse
* JsonRpcClient::Response::RpcErrorResponse
* JsonRpcClient::Response::RpcErrorBatchResponse | Object in def_results.errback { |error| ... }.


## Development
Clone, "bundle instal", do something, check tests (bundle exec rake test)


# Copyright
Copyright (C) 2012-2013, Textalk AB <http://textalk.se/>

JSON-RPC client is freely distributable under the terms of an MIT license. See [LICENCE](LICENSE).
