module JsonRpcClient
  module Request
    class RpcCall
      attr_reader :method, :params

      def initialize(method: nil, params: nil)
        fail ArgumentError, 'RpcCall must have method' unless method

        @method = method
        @params = params
      end

      def need_response?
        true
      end

      def rpc_body
        body = {
          method: @method
        }
        body[:params] = @params if @params
        body
      end
    end

    class RpcMethod < RpcCall
      attr_reader :id

      def initialize(id: nil, method: nil, params: nil)
        super(method: method, params: params)

        @id = id || SecureRandom.uuid
      end

      def rpc_body
        super.tap { |body| body[:id] = @id }
      end
    end

    class RpcNotify < RpcCall
      def initialize(method: nil, params: nil)
        super(method: method, params: params)
      end

      def need_response?
        false
      end
    end
  end
end
