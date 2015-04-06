require 'test/unit'
require 'json'

require 'webmock/test_unit'
require 'json_rpc_client_2'
require 'pp'

require 'timeout'

class ClientTest < Test::Unit::TestCase
  def setup
    # JsonRpcClient::RpcClient::logger = Logger.new(STDOUT)
  end

  def reset_stub
    WebMock.reset!
    yield
  end

  def test_one_shot_method
    reset_stub do
      stub_request(:post, 'http://localhost:4567/json_rpc').to_return do |http_request|
        json = JSON.parse(http_request.body)

        assert(json.find { |r| r['method'] == 'method1' && r['params'] == 'params'  }, 'Request must be sended')

        answer = json.map do |req|
          %({"id":"#{req['id']}","jsonrpc":2.0,"result":"ok"})
        end

        { status: 200, body: "[#{answer.join ','}]" }
      end
    end

    success = false

    eventmachine(10) do
      EM.add_timer(3, ->{ EM.stop })
      client = JsonRpcClient::RpcClient.new('http://localhost:4567/json_rpc')

      def_result = client.method(method: 'method1', params: 'params')

      def_result.callback { |result| success = (result.result == 'ok'); EM.stop }
    end

    assert(success, 'Test_one_shot_method: failed')
  end

  def test_one_bad_shot_method
    rpc_method = JsonRpcClient::Request::RpcMethod.new(method: 'test_one_bad_shot_method', params: 'q')
    error_code = JsonRpcClient::Response::RpcError::METHOD_NOT_FOUND
    response_body = %([{"id":"#{rpc_method.id}","jsonrpc":2.0,"error":{"code":#{error_code},"message":"nope"}}])

    reset_stub do
      stub_request(:post, 'http://localhost:4567/json_rpc').with { |http_request|
        json_requests = JSON.parse(http_request.body) # [{}]

        assert(json_requests.find { |r| r['id'] == rpc_method.id })
        true
      }.to_return(status: 200, body: response_body)
    end

    success = false

    eventmachine(10) do
      EM.add_timer(3, ->{ EM.stop })
      client = JsonRpcClient::RpcClient.new('http://localhost:4567/json_rpc')

      def_result = client.send(rpc_method)

      def_result.errback do |error|
        success = (error.error.code == JsonRpcClient::Response::RpcError::METHOD_NOT_FOUND)
        EM.stop
      end
    end

    assert(success, 'Test_one_bad_shot_method: failed')
  end

  def test_one_bad_shot_method_invalide_json
    rpc_method = JsonRpcClient::Request::RpcMethod.new(method: 'test_one_bad_shot_method_invalide_json', params: 'q')

    reset_stub do
      stub_request(:post, 'http://localhost:4567/json_rpc').with { |http_request|
        json_requests = JSON.parse(http_request.body) # [{}]

        assert(json_requests.find { |r| r['id'] == rpc_method.id })

        true
      }.to_return(status: 200, body: %([{"id"#{rpc_method.id} I DON'T CARE ABOUT JSON ":"nope"}}]))
    end

    success = false

    eventmachine(10) do
      EM.add_timer(3, ->{ EM.stop })
      client = JsonRpcClient::RpcClient.new('http://localhost:4567/json_rpc')

      def_result = client.send(rpc_method)

      def_result.errback do |error|
        success = (error.error.code == JsonRpcClient::Response::RpcError::REQUEST_PROCESSING_ERROR)
        EM.stop
      end
    end

    assert(success, 'Test_one_bad_shot_method: failed')
  end

  def test_one_shot_method_timeout
    rpc_method = JsonRpcClient::Request::RpcMethod.new(method: 'test_one_shot_method_timeout', params: 'q')

    reset_stub do
      stub_request(:post, 'http://localhost:4567/json_rpc').with { |http_request|
        json_requests = JSON.parse(http_request.body) # [{}]

        assert(json_requests.find { |r| r['id'] == rpc_method.id })

        true
      }.to_timeout
    end

    success = false

    eventmachine(10) do
      EM.add_timer(3, ->{ EM.stop })
      client = JsonRpcClient::RpcClient.new('http://localhost:4567/json_rpc')

      def_result = client.send(rpc_method)

      def_result.errback do |error|
        success = (error.error.code == JsonRpcClient::Response::RpcError::REQUEST_SEND_ERROR)
        EM.stop
      end
    end

    assert(success, 'Test_one_shot_method: failed')
  end

  def test_one_shot_method_without_answer
    rpc_method = JsonRpcClient::Request::RpcMethod.new(method: 'test_one_shot_method_without_answer', params: 'q')

    reset_stub do
      stub_request(:post, 'http://localhost:4567/json_rpc').with { |http_request|
        json_requests = JSON.parse(http_request.body) # [{}]

        assert(json_requests.find { |r| r['id'] == rpc_method.id })
        true
      }.to_return(status: 200, body: %([{"id":"#{rpc_method.id}-q","jsonrpc":2.0,"result":"ok"}]))
    end

    success = false

    eventmachine(10) do
      EM.add_timer(3, ->{ EM.stop })
      client = JsonRpcClient::RpcClient.new('http://localhost:4567/json_rpc')

      def_result = client.send(rpc_method)

      def_result.errback do |error|
        success = (error.error.code == JsonRpcClient::Response::RpcError::REQUEST_WITHOUT_ANSWER)
        EM.stop
      end
    end

    assert(success, 'Test_one_shot_method: failed')
  end

  def test_one_shot_notify
    rpc_method = JsonRpcClient::Request::RpcNotify.new(method: 'test_one_shot_notify', params: 'q')

    reset_stub do
      stub_request(:post, 'http://localhost:4567/json_rpc').with { |http_request|
        JSON.parse(http_request.body)
        true
      }.to_return(status: 200)
    end

    eventmachine(10) do
      EM.add_timer(3, ->{ EM.stop })
      client = JsonRpcClient::RpcClient.new('http://localhost:4567/json_rpc')

      def_result = client.send(rpc_method)

      assert def_result.nil?
      EM.stop
    end
  end

  def test_one_shot_another_style
    reset_stub do
      stub_request(:post, 'http://localhost:4567/json_rpc').with { |http_request|
        JSON.parse(http_request.body)
      }.to_return(status: 200)
    end

    eventmachine(10) do
      EM.add_timer(3, ->{ EM.stop })
      client = JsonRpcClient::RpcClient.new('http://localhost:4567/json_rpc')

      def_result = client.notify(method: 'test_one_shot_notify', params: 'q')

      assert def_result.nil?
      EM.stop
    end
  end

  def test_batch_shot
    rpc_methods = [
      JsonRpcClient::Request::RpcMethod.new(method: 'test_batch_shot_method'),
      JsonRpcClient::Request::RpcNotify.new(method: 'notify'),
      JsonRpcClient::Request::RpcMethod.new(method: 'test_batch_shot_method', params: 'q'),
      JsonRpcClient::Request::RpcMethod.new(method: 'give_me_fail', params: 'q'),
      JsonRpcClient::Request::RpcMethod.new(method: 'ignore_me', params: 'q')
    ]

    # methods + batch block
    answers_by_rpc = rpc_methods.count { |m| m.is_a? JsonRpcClient::Request::RpcMethod } + 1

    answers = rpc_methods.map do |method|
      if method.is_a?(JsonRpcClient::Request::RpcNotify) || method.method == 'ignore_me'
        nil # notify
      else
        if method.method == 'give_me_fail'
          %({"id":"#{method.id}","jsonrpc":2.0,"error":{"code":-32601,"message":"nope"}})
        else
          %({"id":"#{method.id}","jsonrpc":2.0,"result":"ok"})
        end
      end
    end

    reset_stub do
      stub_request(:post, 'http://localhost:4567/json_rpc').with { |http_request|
        json_requests = JSON.parse(http_request.body) # [{}]

        rpc_methods.each do |method|
          next if method.is_a?(JsonRpcClient::Request::RpcNotify)
          assert(json_requests.find { |r| r['id'] == method.id })
        end
        true
      }.to_return(status: 200, body: "[#{answers.compact.join ','}]")
    end

    success_hits = 0

    eventmachine(10) do
      EM.add_timer(3, ->{ EM.stop })
      client = JsonRpcClient::RpcClient.new('http://localhost:4567/json_rpc')

      def_results = client.send(rpc_methods)

      def_results.callback do |results|
        success_hits += 1 if results.count == answers.compact.count
        stop_if(success_hits == answers_by_rpc)
      end

      def_results.each do |def_result|
        # ok
        def_result.callback do |result|
          success_hits += 1 if result.result == 'ok'
          stop_if(success_hits == answers_by_rpc)
        end

        # 2 fail
        def_result.errback do |error|
          success_hits += 1 if [
            JsonRpcClient::Response::RpcError::REQUEST_WITHOUT_ANSWER,
            JsonRpcClient::Response::RpcError::METHOD_NOT_FOUND
          ].include?(error.error.code)

          stop_if(success_hits == answers_by_rpc)
        end
      end
    end

    assert_equal(answers_by_rpc, success_hits)
  end

  def test_batch_swallow_exception
    rpc_methods = [
      JsonRpcClient::Request::RpcMethod.new(method: 'test_batch_swallow_exception'),
      JsonRpcClient::Request::RpcNotify.new(method: 'notify'),
      JsonRpcClient::Request::RpcMethod.new(method: 'test_batch_shot_method', params: 'q'),
      JsonRpcClient::Request::RpcMethod.new(method: 'give_me_fail', params: 'q'),
      JsonRpcClient::Request::RpcMethod.new(method: 'ignore_me', params: 'q')
    ]

    # methods + batch block
    must_errors_hit = rpc_methods.count { |m| %w('ignore_me', 'give_me_fail').include?(m.method) }

    answers = rpc_methods.map do |method|
      if method.is_a?(JsonRpcClient::Request::RpcNotify) || method.method == 'ignore_me'
        nil # notify
      else
        if method.method == 'give_me_fail'
          %({"id":"#{method.id}","jsonrpc":2.0,"error":{"code":-32601,"message":"nope"}})
        else
          %({"id":"#{method.id}","jsonrpc":2.0,"result":"ok"})
        end
      end
    end

    reset_stub do
      stub_request(:post, 'http://localhost:4567/json_rpc').with { |http_request|
        json_requests = JSON.parse(http_request.body) # [{}]

        rpc_methods.each do |method|
          next if method.is_a?(JsonRpcClient::Request::RpcNotify)
          assert(json_requests.find { |r| r['id'] == method.id })
        end
        true
      }.to_return(status: 200, body: "[#{answers.compact.join ','}]")
    end

    errors_hit = 0

    begin
      eventmachine(10) do
        EM.add_timer(3, ->{ EM.stop })
        client = JsonRpcClient::RpcClient.new('http://localhost:4567/json_rpc')

        def_results = client.send(rpc_methods)

        def_results.callback do |_results|
          fail JSON::ParserError, 'Nope nope nope'
        end

        def_results.each do |def_result|
          # ok
          def_result.callback do |_result|
          end

          # 2 fail
          def_result.errback do |_error|
            errors_hit += 1
            stop_if(errors_hit == must_errors_hit)
          end
        end
      end
    rescue JSON::ParserError => _e
      assert true
    else
      assert false
    end
  end

  def test_batch_request_pre
    client = JsonRpcClient::RpcClient.new('http://localhost:4567/json_rpc')
    one_notify = false

    reset_stub do
      stub_request(:post, 'http://localhost:4567/json_rpc').to_return do |http_request|
        json_requests = JSON.parse(http_request.body)

        answers = json_requests.map do |json|
          one_notify = true unless json.key?('id')

          if json['method'] == 'give_me_error'
            format(
              %({"id":"#{json['id']}","jsonrpc":2.0,"error": {"code": %d, "message": "nope"}}),
              JsonRpcClient::Response::RpcError::METHOD_NOT_FOUND
            )
          elsif !json.key?('id')
            one_notify = true
            nil
          else
            %({"id":"#{json['id']}","jsonrpc":2.0,"result":"ok"})
          end
        end

        { status: 200, body: "[#{answers.compact.join(',')}]" }
      end
    end

    success_hit = 0
    success_hit_target = 3

    batch_request = client.batch_request

    eventmachine(10) do
      EM.add_timer(3, -> { EM.stop })
      assert batch_request.notify(method: 'smth_ready', params: [1, 2, 3]).nil?

      def_result1 = batch_request.method(method: 'method1')

      def_result1.callback do |_result|
        success_hit += 1
        stop_if(success_hit_target == success_hit)
      end

      def_result2 = batch_request.method(method: 'give_me_error', params: [1], id: 3)

      def_result2.errback do |_error|
        success_hit += 1
        stop_if(success_hit_target == success_hit)
      end

      def_results = batch_request.send

      def_results.callback do |results|
        assert_equal(2, results.count, 'in batch results must be 2 responses')
        success_hit += 1
      end
    end
    assert(one_notify, 'at least one notify must be')
    assert_equal(success_hit_target, success_hit)
  end

  def test_batch_request_after
    one_notify = false

    reset_stub do
      stub_request(:post, 'http://localhost:4567/json_rpc').to_return do |http_request|
        json_requests = JSON.parse(http_request.body)

        answers = json_requests.map do |json|
          one_notify = true unless json.key?('id')

          if json['method'] == 'give_me_error'
            format(
              %({"id":"#{json['id']}","jsonrpc":2.0,"error": {"code": %d, "message": "nope"}}),
              JsonRpcClient::Response::RpcError::METHOD_NOT_FOUND
            )
          elsif !json.key?('id')
            one_notify = true
            nil
          else
            %({"id":"#{json['id']}","jsonrpc":2.0,"result":"ok"})
          end
        end

        { status: 200, body: "[#{answers.compact.join(',')}]" }
      end
    end

    success_hit = 0
    success_hit_target = 3

    batch_request = JsonRpcClient::BatchRequest.new

    eventmachine(10) do
      EM.add_timer(3, -> { EM.stop })
      assert batch_request.notify(method: 'smth_ready', params: [1, 2, 3]).nil?

      def_result1 = batch_request.method(method: 'method1')

      def_result1.callback do |_result|
        success_hit += 1
        stop_if(success_hit_target == success_hit)
      end

      def_result2 = batch_request.method(method: 'give_me_error', params: [1], id: 3)

      def_result2.errback do |_error|
        success_hit += 1
        stop_if(success_hit_target == success_hit)
      end

      def_results = batch_request.send(
        json_rpc_client: JsonRpcClient::RpcClient.new('http://localhost:4567/json_rpc')
      )

      def_results.callback do |results|
        assert_equal(2, results.count, 'in batch results must be 2 responses')
        success_hit += 1
      end
    end

    assert(one_notify, 'at least one notify must be')
    assert_equal(success_hit_target, success_hit)
  end

  def test_notify_answers
    client = JsonRpcClient::RpcClient.new('http://localhost:4567/json_rpc')

    reset_stub do
      stub_request(:post, 'http://localhost:4567/json_rpc').to_return do |_http_request|
        { status: 200 }
      end
    end

    eventmachine(10) do
      assert client.notify(method: 'm', params: []).nil?

      batch_request = client.batch_request
      assert batch_request.notify(method: 'm', params: []).nil?
      assert batch_request.notify(method: 'm', params: []).nil?
      assert batch_request.send.nil?

      batch_request1 = JsonRpcClient::BatchRequest.new
      assert batch_request1.notify(method: 'm', params: []).nil?
      assert batch_request1.notify(method: 'm', params: []).nil?
      assert batch_request1.send(json_rpc_client: client).nil?

      assert client.send([
                    JsonRpcClient::Request::RpcNotify.new(method: 'm1'),
                    JsonRpcClient::Request::RpcNotify.new(method: 'm2')
                  ]).nil?

      EM.stop
    end
  end

  def stop_if(cond)
    EM.stop if cond
  end

  def eventmachine(timeout = 1)
    begin
      timeout(timeout) do
        EM.run do
          yield
        end
      end
    rescue Timeout::Error => _e
      flunk 'Eventmachine was not stopped before the timeout expired'
    end
  end
end
