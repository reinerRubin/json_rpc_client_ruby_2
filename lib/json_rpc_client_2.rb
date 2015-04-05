require 'em-http-request'
require 'addressable/uri'
require 'json'
require 'securerandom'
require 'logger'
require 'null_logger'

require 'response/response'
require 'response/deferrable_response'
require 'request/request'

module JsonRpcClient
  class RpcClient
    include JsonRpcClient::Response

    class << self
      attr_accessor :logger
    end

    def initialize(service_uri, options = {})
      @service_uri = Addressable::URI.parse(service_uri)
      logger.debug("Initialization client #{@service_uri}")
    end

    def send(requests)
      is_batch = requests.is_a?(Array)
      a_requests = [*requests]

      fail(ArgumentError, 'Empty json-rpc request') if a_requests.empty?

      rpc_json_body, need_response, def_responses = processing_requests(a_requests)

      logger.debug("Sending request: #{rpc_json_body}")

      http_response = EM::HttpRequest.new(@service_uri.to_s).post(
        :body => rpc_json_body,
        'content-type' => 'application/json'
      )

      return unless need_response

      # at least one response
      processing_responses(http_response, def_responses)

      is_batch ? def_responses : def_responses.first
    end

    private

    def processing_requests(requests)
      any_need_response = false
      responses = []

      rpc_body = requests.map do |r|
        any_need_response ||= r.need_response?

        if r.need_response?
          responses << RpcDefResponse.new(id: r.id, method: r.method, params: r.params)
        end

        rpc_body = r.rpc_body
        add_rpc_version(rpc_body)
        rpc_body
      end

      rpc_json = rpc_body.to_json

      [rpc_json, any_need_response, RpcDefResponses.new(responses)]
    end

    def add_rpc_version(body)
      body.tap { |b| b[:jsonrpc] = 2.0 }
    end

    def processing_responses(http_response, def_responses)
      http_response.callback do |h_response|
        begin
          logger.debug("Geting response #{h_response.response}")

          begin
            json_response = JSON.parse(h_response.response)
          rescue JSON::ParserError => e
            raise JsonClientJsonParserError.new(e)
          end

          responses = {}

          a_responses = json_response.map do |r|
            response = create_response(r)
            responses[r['id']] = response
            response
          end

          # trigger main response from batch
          def_responses.set_deferred_status(:succeeded, a_responses)

          # trigger sub responses
          def_responses.each do |def_resp|
            response = responses[def_resp.id]

            if response
              def_resp.set_deferred_status(response.status, response)
            else
              logger.error('Deferrable response without actual response!')
              error = RpcError.new(
                code: RpcError::REQUEST_WITHOUT_ANSWER,
                message: 'Deferrable response without actual response'
              )
              def_resp.set_deferred_status(:failed, RpcErrorResponse.new(
                                             id: def_resp.id,
                                             error: error
                                           ))
            end
          end
        rescue JsonClientJsonParserError => e
          logger.error do
            ['HTTP response processing fail: ',
             e.message,
             e.backtrace].join "\n"
          end

          send_fail(def_responses, RpcError.new(
                      code: RpcError::REQUEST_PROCESSING_ERROR,
                      message: "Request proccesing error #{e.message}"
                    ))
        end
      end

      http_response.errback do |h_response|
        logger.error("Error in http request: #{h_response.error}")
        send_fail(def_responses, RpcError.new(
                    code: RpcError::REQUEST_SEND_ERROR,
                    message: "Error in http request: #{h_response.error}"
                  ))
      end
    end

    def create_response(response)
      if response.key?('error')
        error = response['error']
        RpcErrorResponse.new(
          id: response['id'],
          error: RpcError.new(
            code: error['code'],
            message: error['message'],
            data: error['data']
          )
        )
      else
        RpcSuccessResponse.new(id: response['id'], result: response['result'])
      end
    end

    def send_fail(def_responses, error)
      batch_error = RpcErrorBatchResponse.new(error: error)
      def_responses.set_deferred_status(batch_error.status, batch_error)
      def_responses.each do |d_r|
        d_error = RpcErrorResponse.new(id: d_r.id, error: error)
        d_r.set_deferred_status(d_error.status, d_error)
      end
    end

    def logger
      self.class.logger ||= NullLogger.instance
    end
  end

  class JsonClientJsonParserError < JSON::ParserError
  end
end
