module DataMapper
  module Mongo
    class Adapter < DataMapper::Adapters::AbstractAdapter
      class ConnectionError < StandardError; end

      # Persists one or more new resources
      #
      # @example
      #   adapter.create(collection)  # => 1
      #
      # @param [Enumerable<Resource>] resources
      #   The list of resources (model instances) to create
      #
      # @return [Integer]
      #   The number of records that were actually saved into the data-store
      #
      # @api semipublic
      def create(resources)
        resources.map do |resource|
          with_collection(resource.model) do |collection|
            resource.model.key.set(resource, [collection.insert(attributes_as_fields(resource))])
          end
        end.size
      end

      # Reads one or many resources from a datastore
      #
      # @example
      #   adapter.read(query)  # => [ { 'name' => 'Dan Kubb' } ]
      #
      # @param [Query] query
      #   The query to match resources in the datastore
      #
      # @return [Enumerable<Hash>]
      #   An array of hashes to become resources
      #
      # @api semipublic
      def read(query)
        with_collection(query.model) do |collection|
          Query.new(collection, query).read
        end
      end

      # Updates one or many existing resources
      #
      # @example
      #   adapter.update(attributes, collection)  # => 1
      #
      # @param [Hash(Property => Object)] attributes
      #   Hash of attribute values to set, keyed by Property
      # @param [Collection] resources
      #   Collection of records to be updated
      #
      # @return [Integer]
      #   The number of records updated
      #
      # @api semipublic
      def update(attributes, resources)
        with_collection(resources.query.model) do |collection|
          resources.each do |resource|
            collection.update(key(resource),
              attributes_as_fields(resource).merge(attributes_as_fields(attributes)))
          end.size
        end
      end

      # Deletes one or many existing resources
      #
      # @example
      #   adapter.delete(collection)  # => 1
      #
      # @param [Collection] resources
      #   Collection of records to be deleted
      #
      # @return [Integer]
      #   The number of records deleted
      #
      # @api semipublic
      def delete(resources)
        with_collection(resources.query.model) do |collection|
          resources.each do |resource|
            collection.remove(key(resource))
          end.size
        end
      end

      def execute(resources, selector, document, options={})
        resources.map do |resource|
          with_collection(resource.model) do |collection|
            collection.update(selector, document, options)
          end
        end.size
      end

      private

      def initialize(name, options = {})
        # When giving a repository URI rather than a hash, the database name
        # is :path, with a leading slash.
        if options[:path] && options[:database].nil?
          options[:database] = options[:path].sub(/^\//, '')
        end

        super
      end

      # Retrieves the key for a given resource as a hash.
      #
      # @param [Resource] resource
      #   The resource whose key is to be retrieved
      #
      # @return [Hash{Symbol => Object}]
      #   Returns a hash where each hash key/value corresponds to a key name
      #   and value on the resource.
      #
      # @api private
      def key(resource)
        resource.model.key(name).map{ |key| [key.field, key.value(resource.__send__(key.name))] }.to_hash
      end

      # Retrieves all of a records attributes and returns them as a Hash.
      #
      # The resulting hash can then be used with the Mongo library for
      # inserting new -- and updating existing -- documents in the database.
      #
      # @param [Resource, Hash] record
      #   A DataMapper resource, or a hash containing fields and values.
      #
      # @return [Hash]
      #   Returns a hash containing the values for each of the fields in the
      #   given resource as raw (dumped) values suitable for use with the
      #   Mongo library.
      #
      # @api private
      def attributes_as_fields(record)
        attributes = case record
          when DataMapper::Resource
            attributes_from_resource(record)
          when Hash
            attributes_from_properties_hash(record)
          end

        attributes.except('_id') unless attributes.nil?
      end

      # TODO: document
      def attributes_from_resource(record)
        attributes = {}

        model = record.model

        model.properties.each do |property|
          name = property.name
          if model.public_method_defined?(name)
            attributes[property.field] = property.to_mongo(record.__send__(name))
          end
        end

        if model.respond_to?(:embedments)
          model.embedments.each do |name, embedment|
            if model.public_method_defined?(name)
              value = record.__send__(name)

              if embedment.kind_of?(Embedments::OneToMany::Relationship)
                attributes[name] = value.map{ |resource| attributes_as_fields(resource) }
              else
                attributes[name] = attributes_as_fields(value)
              end
            end
          end
        end

        attributes
      end

      # TODO: document
      def attributes_from_properties_hash(record)
        attributes = {}

        record.each do |key, value|
          case key
            when DataMapper::Property
              attributes[key.field] = key.to_mongo(value)
            when Embedments::Relationship
              attributes[key.name] = attributes_as_fields(value)
            end
        end

        attributes
      end

      # Runs the given block within the context of a Mongo collection.
      #
      # @param [Model] model
      #   The model whose collection is to be scoped.
      #
      # @yieldparam [Mongo::Collection]
      #   The Mongo::Collection instance for the given model
      #
      # @api private
      def with_collection(model)
        begin
          yield database.collection(model.storage_name(name))
        rescue Exception => exception
          DataMapper.logger.error(exception.to_s)
          raise exception
        end
      end

      # Returns the Mongo::DB instance for this process.
      #
      # @return [Mongo::DB]
      #
      # @raise [ConnectionError]
      #   If the database requires you to authenticate, and the given username
      #   or password was not correct, a ConnectionError exception will be
      #   raised.
      #
      # @api semipublic
      def database
        unless defined?(@database)
          @database = connection.db(@options[:database])

          if @options[:username] and not @database.authenticate(
              @options[:username], @options[:password])
            raise ConnectionError,
              'MongoDB did not recognize the given username and/or ' \
              'password; see the server logs for more information'
          end
        end

        @database
      end

      # Returns the Mongo::Connection instance for this process
      #
      # @todo Reconnect if the connection has timed out, or if the process has
      #       been forked.
      #
      # @return [Mongo::Connection]
      #
      # @api semipublic
      def connection
        @connection ||= ::Mongo::Connection.new(*@options.values_at(:host, :port))
      end
    end # Adapter
  end # Mongo

  Adapters::MongoAdapter = DataMapper::Mongo::Adapter
  Adapters.const_added(:MongoAdapter)
end # DataMapper
