module Redlics

  # Operators namespace
  module Operators

    # AND (&) operator.
    #
    # @param query [Redlics::Query] Redlics query object
    # @return [Redlics::Query::Operation] a Redlics query operation object
    def &(query)
      Query::Operation.new('AND', [self, query])
    end


    # OR (|) operator.
    #
    # @param query [Redlics::Query] Redlics query object
    # @return [Redlics::Query::Operation] a Redlics query operation object
    def |(query)
      Query::Operation.new('OR', [self, query])
    end
    alias_method :+, :|


    # XOR (^) operator.
    #
    # @param query [Redlics::Query] Redlics query object
    # @return [Redlics::Query::Operation] a Redlics query operation object
    def ^(query)
      Query::Operation.new('XOR', [self, query])
    end


    # NOT (-, ~) operator.
    # @return [Redlics::Query::Operation] a Redlics query operation object
    def -@()
      Query::Operation.new('NOT', [self])
    end
    alias_method :~@, :-@


    # MINUS (-) operator.
    #
    # @param query [Redlics::Query] Redlics query object
    # @return [Redlics::Query::Operation] a Redlics query operation object
    def -(query)
      Query::Operation.new('MINUS', [self, query])
    end

  end
end
