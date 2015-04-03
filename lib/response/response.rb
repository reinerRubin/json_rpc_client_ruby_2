module JsonRpcClient
  module Response

    class RpcResponse
      def initialize
      end

      def status
        :unknown
      end
    end

    class RpcEntityResponse < RpcResponse
      def initialize(id: nil)
        super()
        raise(ArgumentError, 'missing id') unless id
        @id = id
      end
    end

    class RpcSuccessResponse < RpcEntityResponse
      attr_reader :result, :id

      def initialize(id: nil, result: nil)
        super(id: id)
        @result = result
      end

      def status
        :succeeded
      end
    end

    class RpcError
      # Invalid JSON was received by the server.
      # An error occurred on the server while parsing the JSON text.
      INVALID_JSON     = -32700
      # The JSON sent is not a valid Request object.
      INVALID_REQUEST  = -32600
      # The method does not exist / is not available.
      METHOD_NOT_FOUND = -32601
      # Invalid method parameter(s).
      INVALID_PARAMS   = -32602
      # Internal JSON-RPC error.
      INTERNAL_ERROR   = -32603

      # Client side errors
      # Processing request error
      REQUEST_PROCESSING_ERROR = 12700
      # Request was not answered
      REQUEST_WITHOUT_ANSWER = 12701
      # HTTP send error
      REQUEST_SEND_ERROR = 12600

      attr_reader :code, :message, :data

      def initialize(code: nil, message: nil, data: nil)
        raise ArgumentError, "JsonRpcError lack code error" unless code
        raise ArgumentError, "JsonRpcError lack message" unless message

        @code = code
        @message = message
        @data = data
      end
    end

    class RpcErrorResponse < RpcEntityResponse
      attr_reader :error, :id

      def initialize(id: nil, error: nil)
        super(id: id)
        @error = error
      end

      def status
        :failed
      end
    end

    class RpcErrorBatchResponse < RpcResponse
      attr_reader :error

      def initialize(error: nil)
        super()
        @error = error
      end

      def status
        :failed
      end
    end

  end
end
