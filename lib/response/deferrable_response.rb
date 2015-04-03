module JsonRpcClient
  module Response

    class RpcDefResponses
      include EM::Deferrable
      include Enumerable

      attr_reader :responses

      def initialize(responses)
        @responses = responses
      end

      def each(&block)
        @responses.each(&block)
      end
    end

    class RpcDefResponse
      include EM::Deferrable

      attr_reader :id, :method, :params

      def initialize(id: nil, method: nil, params: nil)
        raise(ArgumentError, 'missing id') unless id

        @id = id
        @method = method
        @params = params
      end
    end

  end
end
